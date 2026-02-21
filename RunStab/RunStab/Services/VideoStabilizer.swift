//
//  VideoStabilizer.swift
//  RunStab
//
//  動画処理の核心。AVAssetReader でフレームを読み込み、
//  Trajectory に従ってクロップ・リサイズして AVAssetWriter で書き出す。

import AVFoundation
import CoreImage
import Photos

actor VideoStabilizer {

    /// 動画を安定化して outputURL に書き出す
    /// - Parameters:
    ///   - sourceURL: 元動画
    ///   - trajectory: 追跡軌道
    ///   - outputURL: 書き出し先（既存ファイルは事前に削除すること）
    ///   - onProgress: 進捗コールバック（0.0〜1.0）
    func stabilize(
        sourceURL: URL,
        trajectory: Trajectory,
        outputURL: URL,
        onProgress: @Sendable (Double) -> Void
    ) async throws {
        let asset = AVURLAsset(url: sourceURL)

        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw StabilizerError.noVideoTrack
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let transform   = try await videoTrack.load(.preferredTransform)
        let duration    = try await asset.load(.duration)
        let nominalFPS  = try await videoTrack.load(.nominalFrameRate)

        // transform適用後の実際のサイズ
        let transformedSize = naturalSize.applying(transform)
        let srcWidth  = abs(transformedSize.width)
        let srcHeight = abs(transformedSize.height)

        let outputWidth:  CGFloat = 1080
        let outputHeight: CGFloat = 1920
        let cropSize = trajectory.cropSize

        let totalFrames = max(1, Int(CMTimeGetSeconds(duration) * Double(nominalFPS)))

        // MARK: AVAssetReader
        let reader = try AVAssetReader(asset: asset)
        let readerOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        )
        readerOutput.alwaysCopiesSampleData = false
        reader.add(readerOutput)

        // MARK: AVAssetWriter
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let writerInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey:  AVVideoCodecType.h264,
                AVVideoWidthKey:  Int(outputWidth),
                AVVideoHeightKey: Int(outputHeight),
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 8_000_000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                ]
            ]
        )
        writerInput.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey  as String: Int(outputWidth),
                kCVPixelBufferHeightKey as String: Int(outputHeight)
            ]
        )
        writer.add(writerInput)

        reader.startReading()
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let ciContext = CIContext(options: [.useSoftwareRenderer: false])
        var frameIndex = 0

        while let sampleBuffer = readerOutput.copyNextSampleBuffer() {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                frameIndex += 1
                continue
            }

            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

            // 走者の中心座標
            let centerX = trajectory.x(at: frameIndex)
            let centerY = trajectory.y(at: frameIndex)

            // CIImage の座標系はY軸が下から上なので反転
            let ciY = srcHeight - centerY

            // クロップ矩形（フレームからはみ出さないようにクランプ）
            let cropOriginX = (centerX - cropSize.width  / 2)
                .clamped(to: 0...(srcWidth  - cropSize.width))
            let cropOriginY = (ciY      - cropSize.height / 2)
                .clamped(to: 0...(srcHeight - cropSize.height))
            let cropRect = CGRect(x: cropOriginX, y: cropOriginY,
                                  width: cropSize.width, height: cropSize.height)

            // Core Image でクロップ → 正規化 → スケール
            // preferredTransform 適用後の CIImage は X 軸が表示座標と逆向きになるため、
            // クロップ前に X 軸を反転して表示座標系に揃える
            let xFlip = CGAffineTransform(scaleX: -1, y: 1)
                .translatedBy(x: -srcWidth, y: 0)

            var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                .transformed(by: transform)
                .transformed(by: xFlip)
                .cropped(to: cropRect)
                .transformed(by: CGAffineTransform(translationX: -cropRect.origin.x,
                                                   y: -cropRect.origin.y))

            let scaleX = outputWidth  / cropSize.width
            let scaleY = outputHeight / cropSize.height
            ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

            // CIImage (左下原点) → CVPixelBuffer (左上原点) の座標系差分を補正（Y軸反転）
            let correction = CGAffineTransform(scaleX: 1, y: -1)
                .translatedBy(x: 0, y: -outputHeight)
            ciImage = ciImage.transformed(by: correction)

            // 出力バッファに描画
            var outputBuffer: CVPixelBuffer?
            let attrs: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey  as String: Int(outputWidth),
                kCVPixelBufferHeightKey as String: Int(outputHeight),
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]
            CVPixelBufferCreate(kCFAllocatorDefault,
                                Int(outputWidth), Int(outputHeight),
                                kCVPixelFormatType_32BGRA,
                                attrs as CFDictionary,
                                &outputBuffer)

            if let outputBuffer {
                ciContext.render(ciImage, to: outputBuffer)

                while !writerInput.isReadyForMoreMediaData {
                    await Task.yield()
                }
                adaptor.append(outputBuffer, withPresentationTime: presentationTime)
            }

            frameIndex += 1
            onProgress(Double(frameIndex) / Double(totalFrames))
        }

        writerInput.markAsFinished()
        await writer.finishWriting()

        if writer.status == .failed {
            throw writer.error ?? StabilizerError.writeFailed
        }
    }

    /// 処理済み動画をカメラロール（RunStabアルバム）に保存
    func saveToPhotoLibrary(url: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .video, fileURL: url, options: nil)
            } completionHandler: { success, error in
                if success {
                    continuation.resume(returning: url.lastPathComponent)
                } else {
                    continuation.resume(throwing: error ?? StabilizerError.saveFailed)
                }
            }
        }
    }
}

// MARK: - Errors

enum StabilizerError: LocalizedError {
    case noVideoTrack
    case writeFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .noVideoTrack: return "動画トラックが見つかりませんでした"
        case .writeFailed:  return "動画の書き出しに失敗しました"
        case .saveFailed:   return "カメラロールへの保存に失敗しました"
        }
    }
}

// MARK: - Helpers

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

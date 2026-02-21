//
//  FrameExtractor.swift
//  RunStab
//
//  指定フレームをCGImageとして取り出す。
//  TrackingSetupView のスクラバーUI用。

import AVFoundation
import CoreGraphics
import UIKit

actor FrameExtractor {
    private let generator: AVAssetImageGenerator
    private let fps: Double
    private let totalFrames: Int
    private let _videoSize: CGSize

    init(url: URL) async throws {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)

        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw FrameExtractorError.noVideoTrack
        }
        let nominalFPS = try await track.load(.nominalFrameRate)
        let naturalSize = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)

        self.fps = Double(nominalFPS)
        self.totalFrames = Int(CMTimeGetSeconds(duration) * Double(nominalFPS))

        // transform適用後のサイズ（縦撮影では width < height）
        let transformed = naturalSize.applying(transform)
        self._videoSize = CGSize(width: abs(transformed.width), height: abs(transformed.height))

        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 400, height: 400) // プレビュー用に縮小
        gen.requestedTimeToleranceBefore = CMTime(value: 1, timescale: CMTimeScale(nominalFPS))
        gen.requestedTimeToleranceAfter  = CMTime(value: 1, timescale: CMTimeScale(nominalFPS))
        self.generator = gen
    }

    var frameCount: Int { totalFrames }

    /// transform適用後の実動画サイズ
    var videoSize: CGSize { _videoSize }

    func image(at frameIndex: Int) async throws -> UIImage {
        let time = CMTime(value: CMTimeValue(frameIndex),
                          timescale: CMTimeScale(fps))
        let cgImage = try await generator.image(at: time).image
        return UIImage(cgImage: cgImage)
    }
}

enum FrameExtractorError: Error {
    case noVideoTrack
}

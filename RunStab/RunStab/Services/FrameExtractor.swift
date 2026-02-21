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

    init(url: URL) async throws {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)

        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw FrameExtractorError.noVideoTrack
        }
        let nominalFPS = try await track.load(.nominalFrameRate)

        self.fps = Double(nominalFPS)
        self.totalFrames = Int(CMTimeGetSeconds(duration) * Double(nominalFPS))

        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 400, height: 400) // プレビュー用に縮小
        gen.requestedTimeToleranceBefore = CMTime(value: 1, timescale: CMTimeScale(nominalFPS))
        gen.requestedTimeToleranceAfter  = CMTime(value: 1, timescale: CMTimeScale(nominalFPS))
        self.generator = gen
    }

    var frameCount: Int { totalFrames }

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

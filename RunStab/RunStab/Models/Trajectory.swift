//
//  Trajectory.swift
//  RunStab
//
//  走者の追跡軌道。始点・終点のフレーム番号と座標から
//  線形補間でX座標を計算する。Y座標は始点・終点の中央値で固定する。

import CoreGraphics

struct Trajectory {
    let startFrame: Int
    let startX: Double
    let startY: Double
    let endFrame: Int
    let endX: Double
    let endY: Double
    let sourceVideoHeight: Double

    init(
        startFrame: Int, startX: Double, startY: Double,
        endFrame: Int, endX: Double, endY: Double,
        sourceVideoHeight: Double
    ) {
        self.startFrame = startFrame
        self.startX = startX
        self.startY = startY
        self.endFrame = endFrame
        self.endX = endX
        self.endY = endY
        self.sourceVideoHeight = sourceVideoHeight
    }

    /// フレーム番号に対応するX座標（範囲外はクランプ）
    func x(at frame: Int) -> Double {
        interpolate(from: startX, to: endX, at: frame)
    }

    /// Y座標は始点・終点の中央値で固定する（prototypeに準拠）
    func y(at frame: Int) -> Double {
        (startY + endY) / 2
    }

    /// 実動画高さの35%を基準にした9:16のクロップサイズ（prototypeに準拠）
    var cropSize: CGSize {
        let height = sourceVideoHeight * 0.35
        let width = height * 9.0 / 16.0
        return CGSize(width: width, height: height)
    }

    // MARK: - Private

    private func interpolate(from start: Double, to end: Double, at frame: Int) -> Double {
        if frame <= startFrame { return start }
        if frame >= endFrame { return end }
        let progress = Double(frame - startFrame) / Double(endFrame - startFrame)
        return start + (end - start) * progress
    }
}

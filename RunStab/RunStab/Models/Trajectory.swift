//
//  Trajectory.swift
//  RunStab
//
//  走者の追跡軌道。始点・終点のフレーム番号と座標から
//  線形補間でX/Y座標を計算する。

import CoreGraphics

struct Trajectory {
    let startFrame: Int
    let startX: Double
    let startY: Double
    let endFrame: Int
    let endX: Double
    let endY: Double
    let runnerHeightPx: Double

    init(
        startFrame: Int, startX: Double, startY: Double,
        endFrame: Int, endX: Double, endY: Double,
        runnerHeightPx: Double = 300
    ) {
        self.startFrame = startFrame
        self.startX = startX
        self.startY = startY
        self.endFrame = endFrame
        self.endX = endX
        self.endY = endY
        self.runnerHeightPx = runnerHeightPx
    }

    /// フレーム番号に対応するX座標（範囲外はクランプ）
    func x(at frame: Int) -> Double {
        interpolate(from: startX, to: endX, at: frame)
    }

    /// フレーム番号に対応するY座標（範囲外はクランプ）
    func y(at frame: Int) -> Double {
        interpolate(from: startY, to: endY, at: frame)
    }

    /// 走者の高さをもとにした9:16のクロップサイズ
    var cropSize: CGSize {
        let height = runnerHeightPx * 1.5
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

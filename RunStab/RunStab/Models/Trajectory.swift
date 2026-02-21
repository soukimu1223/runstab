//
//  Trajectory.swift
//  RunStab
//
//  走者の追跡軌道を表すモデル。
//  始点・終点のフレームと座標から線形補間でX座標を計算する。

import CoreGraphics

struct Trajectory {
    let startFrame: Int
    let startX: Double
    let endFrame: Int
    let endX: Double
    let runnerHeightPx: Double

    init(startFrame: Int, startX: Double, endFrame: Int, endX: Double,
         runnerHeightPx: Double = 300) {
        self.startFrame = startFrame
        self.startX = startX
        self.endFrame = endFrame
        self.endX = endX
        self.runnerHeightPx = runnerHeightPx
    }

    /// フレーム番号に対応するX座標を返す（範囲外はクランプ）
    func x(at frame: Int) -> Double {
        if frame <= startFrame { return startX }
        if frame >= endFrame { return endX }
        let progress = Double(frame - startFrame) / Double(endFrame - startFrame)
        return startX + (endX - startX) * progress
    }

    /// 走者の高さをもとにした9:16のクロップサイズ
    var cropSize: CGSize {
        let height = runnerHeightPx * 1.5
        let width = height * 9.0 / 16.0
        return CGSize(width: width, height: height)
    }
}

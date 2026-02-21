//
//  RunStabTests.swift
//  RunStabTests
//

import Testing
@testable import RunStab

struct TrajectoryTests {

    // MARK: - x座標の補間

    @Test func startFrameReturnsStartX() {
        let t = Trajectory(startFrame: 10, startX: 900, endFrame: 50, endX: 100)
        #expect(t.x(at: 10) == 900)
    }

    @Test func endFrameReturnsEndX() {
        let t = Trajectory(startFrame: 10, startX: 900, endFrame: 50, endX: 100)
        #expect(t.x(at: 50) == 100)
    }

    @Test func midpointIsLinearlyInterpolated() {
        let t = Trajectory(startFrame: 0, startX: 0, endFrame: 100, endX: 100)
        #expect(t.x(at: 50) == 50)
    }

    @Test func beforeStartFrameIsClampedToStartX() {
        let t = Trajectory(startFrame: 10, startX: 900, endFrame: 50, endX: 100)
        #expect(t.x(at: 0) == 900)
        #expect(t.x(at: 9) == 900)
    }

    @Test func afterEndFrameIsClampedToEndX() {
        let t = Trajectory(startFrame: 10, startX: 900, endFrame: 50, endX: 100)
        #expect(t.x(at: 51) == 100)
        #expect(t.x(at: 100) == 100)
    }

    @Test func runnerMovingRightToLeft() {
        // Python prototypeで確認済みのケース: frame8(x=988) → frame53(x=78)
        let t = Trajectory(startFrame: 8, startX: 988, endFrame: 53, endX: 78)
        let speed = (988.0 - 78.0) / (53.0 - 8.0)  // 約20.2 px/frame
        let expectedAt30 = 988.0 - speed * (30.0 - 8.0)
        #expect(abs(t.x(at: 30) - expectedAt30) < 0.001)
    }

    // MARK: - cropSize（走者サイズからクロップ幅を計算）

    @Test func cropWidthIs9to16AspectRatio() {
        let t = Trajectory(startFrame: 0, startX: 500, endFrame: 60, endX: 100,
                           runnerHeightPx: 400)
        // crop_h = runnerHeightPx * 1.5, crop_w = crop_h * 9/16
        let expectedH = 400.0 * 1.5
        let expectedW = expectedH * 9.0 / 16.0
        #expect(abs(t.cropSize.height - expectedH) < 0.001)
        #expect(abs(t.cropSize.width - expectedW) < 0.001)
    }
}

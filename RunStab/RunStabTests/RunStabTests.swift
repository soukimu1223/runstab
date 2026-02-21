//
//  RunStabTests.swift
//  RunStabTests
//

import Testing
@testable import RunStab

struct TrajectoryTests {

    // MARK: - X座標の補間

    @Test func startFrameReturnsStartX() {
        let t = makeTrajectory(startFrame: 10, startX: 900, endFrame: 50, endX: 100)
        #expect(t.x(at: 10) == 900)
    }

    @Test func endFrameReturnsEndX() {
        let t = makeTrajectory(startFrame: 10, startX: 900, endFrame: 50, endX: 100)
        #expect(t.x(at: 50) == 100)
    }

    @Test func midpointIsLinearlyInterpolated() {
        let t = makeTrajectory(startFrame: 0, startX: 0, endFrame: 100, endX: 100)
        #expect(t.x(at: 50) == 50)
    }

    @Test func beforeStartFrameIsClampedToStartX() {
        let t = makeTrajectory(startFrame: 10, startX: 900, endFrame: 50, endX: 100)
        #expect(t.x(at: 0) == 900)
        #expect(t.x(at: 9) == 900)
    }

    @Test func afterEndFrameIsClampedToEndX() {
        let t = makeTrajectory(startFrame: 10, startX: 900, endFrame: 50, endX: 100)
        #expect(t.x(at: 51) == 100)
        #expect(t.x(at: 100) == 100)
    }

    @Test func runnerMovingRightToLeft() {
        // Python prototypeで確認済みのケース: frame8(x=988) → frame53(x=78)
        let t = makeTrajectory(startFrame: 8, startX: 988, endFrame: 53, endX: 78)
        let speed = (988.0 - 78.0) / (53.0 - 8.0)
        let expected = 988.0 - speed * (30.0 - 8.0)
        #expect(abs(t.x(at: 30) - expected) < 0.001)
    }

    // MARK: - Y座標（始点・終点の中央値で固定）

    @Test func yFixedAtMidpoint() {
        let t = Trajectory(startFrame: 0, startX: 0, startY: 200,
                           endFrame: 100, endX: 0, endY: 400,
                           sourceVideoHeight: 1080)
        // どのフレームでも (200+400)/2 = 300 を返す
        #expect(t.y(at: 0) == 300)
        #expect(t.y(at: 50) == 300)
        #expect(t.y(at: 100) == 300)
    }

    @Test func yAlwaysMidpointBeyondRange() {
        let t = Trajectory(startFrame: 10, startX: 0, startY: 800,
                           endFrame: 50, endX: 0, endY: 900,
                           sourceVideoHeight: 1080)
        let mid = (800.0 + 900.0) / 2
        #expect(t.y(at: 0) == mid)
        #expect(t.y(at: 99) == mid)
    }

    // MARK: - cropSize

    @Test func cropWidthIs9to16AspectRatio() {
        let t = Trajectory(startFrame: 0, startX: 500, startY: 800,
                           endFrame: 60, endX: 100, endY: 800,
                           sourceVideoHeight: 1080)
        let expectedH = 1080.0 * 0.35
        let expectedW = expectedH * 9.0 / 16.0
        #expect(abs(t.cropSize.height - expectedH) < 0.001)
        #expect(abs(t.cropSize.width - expectedW) < 0.001)
    }

    // MARK: - Helper

    private func makeTrajectory(startFrame: Int, startX: Double,
                                 endFrame: Int, endX: Double) -> Trajectory {
        Trajectory(startFrame: startFrame, startX: startX, startY: 800,
                   endFrame: endFrame, endX: endX, endY: 800,
                   sourceVideoHeight: 1080)
    }
}

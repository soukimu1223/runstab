//
//  TrackingSetupView.swift
//  RunStab
//
//  フレームスクラバー + タップで始点・終点を指定する画面。
//  走者が最初に映るフレームで「始点を設定」、最後のフレームで「終点を設定」をタップする。

import SwiftUI
import AVFoundation

struct TrackingSetupView: View {
    let videoURL: URL
    @Binding var step: AppStep

    @State private var extractor: FrameExtractor?
    @State private var totalFrames: Int = 1
    @State private var currentFrame: Int = 0
    @State private var currentImage: UIImage?
    @State private var isLoadingFrame = false

    @State private var startPoint: FramePoint?
    @State private var endPoint: FramePoint?
    @State private var videoSize: CGSize = .zero

    @State private var phase: SetupPhase = .setStart
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // フレームプレビュー + タップ
            framePreview
                .frame(maxWidth: .infinity)
                .frame(height: 420)
                .background(Color.black)
                .overlay(alignment: .topLeading) { phaseLabel }

            // スクラバー
            scrubber
                .padding(.horizontal)
                .padding(.vertical, 12)

            // ステータス
            statusPanel
                .padding(.horizontal)

            Spacer()

            // 次へボタン
            actionButton
                .padding(.horizontal)
                .padding(.bottom, 24)
        }
        .navigationTitle("追跡ポイントを設定")
        .navigationBarTitleDisplayMode(.inline)
        .task { await setupExtractor() }
        .onChange(of: currentFrame) { _, _ in
            Task { await loadCurrentFrame() }
        }
    }

    // MARK: - Subviews

    private var framePreview: some View {
        ZStack {
            if let image = currentImage {
                GeometryReader { geo in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    handleTap(at: value.location, in: geo.size, imageSize: image.size)
                                }
                        )
                        .overlay { pointOverlay(imageSize: image.size, viewSize: geo.size) }
                }
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
    }

    private var phaseLabel: some View {
        Text(phase == .setStart ? "走者が最初に映るフレームで始点をタップ"
                                : "走者が最後に映るフレームで終点をタップ")
            .font(.caption.bold())
            .padding(6)
            .background(.black.opacity(0.6))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(8)
    }

    private var scrubber: some View {
        VStack(spacing: 4) {
            Slider(value: Binding(
                get: { Double(currentFrame) },
                set: { currentFrame = Int($0) }
            ), in: 0...Double(max(totalFrames - 1, 1)), step: 1)

            HStack {
                Text("0")
                Spacer()
                Text("frame \(currentFrame)")
                    .font(.caption.monospacedDigit())
                Spacer()
                Text("\(totalFrames - 1)")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            statusRow(label: "始点",
                      value: startPoint.map { "frame\($0.frame) (\(Int($0.x)), \(Int($0.y)))" },
                      color: .green)
            statusRow(label: "終点",
                      value: endPoint.map { "frame\($0.frame) (\(Int($0.x)), \(Int($0.y)))" },
                      color: .orange)
        }
        .padding(12)
        .background(.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func statusRow(label: String, value: String?, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label + ":")
                .font(.caption.bold())
            Text(value ?? "未設定")
                .font(.caption.monospacedDigit())
                .foregroundStyle(value == nil ? .secondary : .primary)
            Spacer()
        }
    }

    private var actionButton: some View {
        VStack(spacing: 12) {
            if phase == .setStart, startPoint != nil {
                Button("終点を設定する →") {
                    phase = .setEnd
                }
                .buttonStyle(.bordered)
            }

            Button(action: startProcessing) {
                Label("処理開始", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canProceed ? Color.blue : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canProceed)

            if let error = errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private func pointOverlay(imageSize: CGSize, viewSize: CGSize) -> some View {
        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let scaledW = imageSize.width * scale
        let scaledH = imageSize.height * scale
        let offsetX = (viewSize.width - scaledW) / 2
        let offsetY = (viewSize.height - scaledH) / 2

        // 実動画座標 → プレビュー画像座標 → ビュー座標
        let videoToPreview = videoSize.width > 0 ? imageSize.width / videoSize.width : 1.0
        func toView(_ p: FramePoint) -> CGPoint {
            CGPoint(
                x: p.x * videoToPreview * scale + offsetX,
                y: p.y * videoToPreview * scale + offsetY
            )
        }

        return ZStack {
            if let s = startPoint {
                pinView(at: toView(s), color: .green, label: "S")
            }
            if let e = endPoint {
                pinView(at: toView(e), color: .orange, label: "E")
            }
        }
    }

    private func pinView(at point: CGPoint, color: Color, label: String) -> some View {
        ZStack {
            Circle().fill(color.opacity(0.3)).frame(width: 44, height: 44)
            Circle().stroke(color, lineWidth: 2).frame(width: 44, height: 44)
            Text(label).font(.caption.bold()).foregroundStyle(color)
        }
        .position(point)
    }

    // MARK: - Logic

    private var canProceed: Bool {
        startPoint != nil && endPoint != nil
    }

    private func setupExtractor() async {
        do {
            let e = try await FrameExtractor(url: videoURL)
            let count = await e.frameCount
            let vSize = await e.videoSize
            await MainActor.run {
                self.extractor = e
                self.totalFrames = max(count, 1)
                self.videoSize = vSize
            }
            await loadCurrentFrame()
        } catch {
            await MainActor.run {
                errorMessage = "動画を開けませんでした: \(error.localizedDescription)"
            }
        }
    }

    private func loadCurrentFrame() async {
        guard let extractor else { return }
        isLoadingFrame = true
        do {
            let img = try await extractor.image(at: currentFrame)
            await MainActor.run {
                currentImage = img
                isLoadingFrame = false
            }
        } catch {
            await MainActor.run { isLoadingFrame = false }
        }
    }

    private func handleTap(at viewPoint: CGPoint, in viewSize: CGSize, imageSize: CGSize) {
        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let scaledW = imageSize.width * scale
        let scaledH = imageSize.height * scale
        let offsetX = (viewSize.width - scaledW) / 2
        let offsetY = (viewSize.height - scaledH) / 2

        let imgX = (viewPoint.x - offsetX) / scale
        let imgY = (viewPoint.y - offsetY) / scale

        guard imgX >= 0, imgX <= imageSize.width,
              imgY >= 0, imgY <= imageSize.height else { return }

        // プレビュー縮小画像座標 → 実動画座標にスケール変換
        let scaleX = videoSize.width > 0 ? videoSize.width / imageSize.width : 1.0
        let scaleY = videoSize.height > 0 ? videoSize.height / imageSize.height : 1.0
        let point = FramePoint(frame: currentFrame, x: imgX * scaleX, y: imgY * scaleY)

        switch phase {
        case .setStart:
            startPoint = point
        case .setEnd:
            endPoint = point
        }
    }

    private func startProcessing() {
        guard let s = startPoint, let e = endPoint else { return }

        let traj = Trajectory(
            startFrame: s.frame, startX: s.x, startY: s.y,
            endFrame:   e.frame, endX:   e.x, endY:   e.y,
            sourceVideoHeight: videoSize.height
        )
        step = .processing(videoURL, traj)
    }
}

// MARK: - Supporting types

struct FramePoint {
    let frame: Int
    let x: Double
    let y: Double
}

enum SetupPhase {
    case setStart
    case setEnd
}

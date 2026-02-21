//
//  ProcessingView.swift
//  RunStab
//
//  動画処理中の進捗表示画面。

import SwiftUI

struct ProcessingView: View {
    let sourceURL: URL
    let trajectory: Trajectory
    @Binding var step: AppStep

    @State private var progress: Double = 0
    @State private var errorMessage: String?

    private let stabilizer = VideoStabilizer()

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
                .symbolEffect(.rotate, isActive: progress < 1.0)

            VStack(spacing: 12) {
                Text("処理中...")
                    .font(.title2.bold())

                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 280)

                Text("\(Int(progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let error = errorMessage {
                VStack(spacing: 12) {
                    Text(error)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    Button("最初からやり直す") {
                        step = .pickVideo
                    }
                    .buttonStyle(.bordered)
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("処理中")
        .navigationBarBackButtonHidden(true)
        .task { await process() }
    }

    private func process() async {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        do {
            try await stabilizer.stabilize(
                sourceURL: sourceURL,
                trajectory: trajectory,
                outputURL: outputURL
            ) { p in
                Task { @MainActor in
                    self.progress = p
                }
            }
            await MainActor.run {
                step = .result(outputURL)
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}

//
//  ResultView.swift
//  RunStab
//
//  処理済み動画のプレビュー・保存・共有画面。

import SwiftUI
import AVKit
import Photos

struct ResultView: View {
    let outputURL: URL
    @Binding var step: AppStep

    @State private var player: AVPlayer?
    @State private var isSaving = false
    @State private var saveResult: SaveResult?

    var body: some View {
        VStack(spacing: 0) {
            // 動画プレビュー
            if let player {
                VideoPlayer(player: player)
                    .frame(maxWidth: .infinity)
                    .frame(height: 480)
                    .onAppear { player.play() }
            } else {
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 480)
                    .overlay { ProgressView().tint(.white) }
            }

            // アクションボタン群
            VStack(spacing: 16) {
                // カメラロールに保存
                Button(action: saveToPhotoLibrary) {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Label("カメラロールに保存", systemImage: "square.and.arrow.down")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .disabled(isSaving)

                // 共有
                ShareLink(item: outputURL) {
                    Label("共有する", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.secondary.opacity(0.15))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // 最初からやり直す
                Button("別の動画を処理する") {
                    player?.pause()
                    step = .pickVideo
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding()

            if let result = saveResult {
                Text(result.message)
                    .font(.caption)
                    .foregroundStyle(result.isSuccess ? .green : .red)
                    .padding(.bottom, 8)
            }
        }
        .navigationTitle("完成")
        .navigationBarBackButtonHidden(true)
        .onAppear {
            player = AVPlayer(url: outputURL)
        }
    }

    private func saveToPhotoLibrary() {
        isSaving = true
        let stabilizer = VideoStabilizer()
        Task {
            do {
                _ = try await stabilizer.saveToPhotoLibrary(url: outputURL)
                await MainActor.run {
                    isSaving = false
                    saveResult = SaveResult(isSuccess: true, message: "カメラロールに保存しました ✓")
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveResult = SaveResult(isSuccess: false,
                                            message: "保存に失敗しました: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct SaveResult {
    let isSuccess: Bool
    let message: String
}

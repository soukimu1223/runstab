//
//  VideoPickerView.swift
//  RunStab
//
//  カメラロールから動画を選択する画面。

import SwiftUI
import PhotosUI

struct VideoPickerView: View {
    @Binding var step: AppStep
    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Image(systemName: "figure.run.circle")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("RunStab")
                    .font(.largeTitle.bold())
                Text("定点カメラ動画からランナーを追跡")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isLoading {
                ProgressView("動画を読み込み中...")
            } else {
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .videos
                ) {
                    Label("動画を選択", systemImage: "photo.on.rectangle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Spacer().frame(height: 40)
        }
        .navigationTitle("")
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            loadVideo(from: item)
        }
    }

    private func loadVideo(from item: PhotosPickerItem) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw VideoPickerError.loadFailed
                }
                // 一時ファイルに書き出し
                let tmpURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mov")
                try data.write(to: tmpURL)

                await MainActor.run {
                    isLoading = false
                    step = .setupTracking(tmpURL)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "動画の読み込みに失敗しました: \(error.localizedDescription)"
                }
            }
        }
    }
}

enum VideoPickerError: Error {
    case loadFailed
}

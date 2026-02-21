//
//  ContentView.swift
//  RunStab
//
//  アプリのナビゲーション起点。
//  動画選択 → 追跡設定 → 処理 → 結果 のフローを管理する。

import SwiftUI

struct ContentView: View {
    @State private var step: AppStep = .pickVideo

    var body: some View {
        NavigationStack {
            switch step {
            case .pickVideo:
                VideoPickerView(step: $step)

            case .setupTracking(let url):
                TrackingSetupView(videoURL: url, step: $step)

            case .processing(let url, let traj):
                ProcessingView(sourceURL: url, trajectory: traj, step: $step)

            case .result(let url):
                ResultView(outputURL: url, step: $step)
            }
        }
    }
}

enum AppStep {
    case pickVideo
    case setupTracking(URL)
    case processing(URL, Trajectory)
    case result(URL)
}

#Preview {
    ContentView()
}

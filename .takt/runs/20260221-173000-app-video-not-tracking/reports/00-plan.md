# タスク計画

## 元の要求
アプリのボタンとかの挙動はいい感じ。だけど、肝心な処理した後の動画が全然追えてない。prototypeとの差分が出てるのかな

## 分析結果

### 目的
iOS アプリで生成される動画がランナーを追跡できていない原因を特定し、Python プロトタイプと同等の追跡精度を実現する。

### スコープ
影響範囲は `VideoStabilizer.swift` のクロップ計算ロジックと、`Trajectory.swift` / `TrackingSetupView.swift` の座標系。

---

## prototype vs iOS アプリ 差分分析

### 差分 1（最重要）: タップ座標がプレビュー縮小解像度のまま

ユーザーがタップする座標はFrameExtractorが縮小したプレビュー（最大400×400）上の座標だが、
VideoStabilizerは実動画（例: 1920×1080）のピクセルバッファでその座標をそのままクロップ計算に使っている。
→ クロップ位置が大きくずれる。これが「追えていない」主な原因。

### 差分 2: Y座標固定 vs 補間

prototype は Y を始点・終点の中央値で固定するが、iOS は Y も線形補間で動かす。
わずかなタップ位置のずれで Y 方向にもカメラが揺れる。

### 差分 3: cropSize の計算基準

prototype: `crop_h = src_height * 0.15`（実動画高さの固定比率）
iOS: `runnerHeightPx * 1.5`（ユーザー入力依存、未入力時は固定値300）

---

### スコープ（修正が必要なファイル）

| ファイル | 問題 | 修正内容 |
|---------|------|---------|
| `FrameExtractor.swift` | 実動画サイズを公開していない | `videoSize: CGSize` を追加 |
| `TrackingSetupView.swift` | タップ座標がプレビュー解像度のまま | 実動画サイズへスケール変換を追加 |
| `Trajectory.swift` | cropSize がプレビュー依存 | 実動画サイズ渡しで計算 |
| `VideoStabilizer.swift` | Y補間（prototypeはY固定） | Y は始終点の平均値を使う |

### 実装アプローチ

1. `FrameExtractor` に `videoSize: CGSize`（transform適用後）を公開
2. `TrackingSetupView.handleTap` でタップ座標を実動画座標にスケール変換
3. `Trajectory` の `cropSize` を実動画サイズ基準（高さの30〜40%）に変更
4. `VideoStabilizer` でY座標を始終点平均に固定

## 実装ガイドライン

- `FrameExtractor` の `videoSize` は transform 適用後のサイズ（縦撮影では width < height）
- タップ座標変換順序: ビュー座標 → プレビュー画像座標 → 実動画座標
- cropSize は `srcHeight * 0.35` 程度を基準にする（prototypeの0.15より大きめで品質確保）
- `runnerHeightPx` 関連のState（`isMeasuringHeight`, `heightTopY`）は削除可

# App Store リリースまでのロードマップ

## 全体像

```
① 環境準備  →  ② アプリ開発  →  ③ テスト  →  ④ App Store申請  →  ⑤ リリース
```

---

## ① 環境準備

### Apple Developer Program 登録
- [ ] Apple IDを用意（既存のもので可）
- [ ] [Apple Developer Program](https://developer.apple.com/programs/) に登録（年額 **$99 / 約15,000円**）
- [ ] 支払い完了後、48時間以内にアクティベートされる

### 開発環境
- [ ] Xcode 最新版をインストール（Mac App Storeから無料）
- [ ] Xcode に Apple ID を紐付け（Xcode > Settings > Accounts）
- [ ] 実機（iPhone）をXcodeに接続して動作確認

---

## ② アプリ開発

### プロジェクト設定（Xcodeで設定が必要なもの）
- [ ] Bundle Identifier を決める（例: `com.yourname.runstab`）← 全世界でユニークである必要がある
- [ ] Deployment Target を iOS 16.0 に設定
- [ ] Capabilities の追加
  - [ ] Photo Library（読み込み用）
  - [ ] Photo Library Additions（カメラロール保存用）
- [ ] `Info.plist` にプライバシー説明文を追加
  - `NSPhotoLibraryUsageDescription`（動画を読み込むために使います）
  - `NSPhotoLibraryAddUsageDescription`（処理済み動画を保存するために使います）

### 実装（MVPスコープ）
- [ ] 動画選択画面（PhotosUI / PHPickerViewController）
- [ ] フレームスクラブUI（AVPlayer + シークバー）
- [ ] タップで始点・終点指定UI
- [ ] 動画処理エンジン（AVAssetReader → クロップ → AVAssetWriter）
- [ ] 進捗表示
- [ ] カメラロール保存（PHPhotoLibrary）
- [ ] 共有シート（ShareLink / UIActivityViewController）

---

## ③ テスト

### 実機テスト
- [ ] iPhone実機で動作確認（シミュレーターでは動画処理の検証が不十分）
- [ ] 複数の動画ファイル形式で動作確認（.mov / .mp4）
- [ ] メモリ・処理時間の確認（長い動画でクラッシュしないか）
- [ ] バックグラウンド処理の確認

### TestFlight（ベータテスト）
- [ ] App Store Connect でアプリを登録
- [ ] ビルドをアップロード（Xcode > Product > Archive → Distribute）
- [ ] 内部テスター（自分・チーム）に配布して確認
- [ ] 問題がなければ外部テスター招待も可能（最大10,000人）

---

## ④ App Store 申請準備

### App Store Connect での設定
- [ ] アプリ名を決める（RunStab など）
- [ ] サブタイトル（30文字以内）
- [ ] 説明文（4,000文字以内）
- [ ] キーワード（100文字以内、検索最適化）
- [ ] サポートURL（GitHubのREADMEでも可）
- [ ] プライバシーポリシーURL（**必須**。無料でホスティングできる）
- [ ] カテゴリ選択（例: スポーツ / 写真・ビデオ）
- [ ] 年齢制限設定（コンテンツに応じて回答）
- [ ] 価格設定（無料 or 有料）

### 必要な画像素材
- [ ] **アプリアイコン** 1024×1024px（透過なし・角丸なし）
- [ ] **スクリーンショット**（最低1枚、最大10枚）
  - iPhone 6.9インチ用（1320×2868px） ← 必須
  - iPhone 6.5インチ用（1284×2778px） ← 推奨
  - ※ シミュレーターまたは実機でスクショを撮ってサイズ調整

### プライバシーポリシー
- [ ] 簡単なプライバシーポリシーページを作成・公開
  - GitHub Pages で無料公開が一番手軽
  - 記載内容：収集するデータ（このアプリは個人データを収集しません等）

---

## ⑤ 審査・リリース

### 審査提出
- [ ] App Store Connect で「審査に提出」
- [ ] 審査期間：通常 **24〜48時間**（初回は1週間程度かかることも）
- [ ] 審査中に Apple から質問が来ることがある（メールで回答）

### よくある審査リジェクト原因（事前チェック）
- [ ] プライバシーポリシーURLが機能しているか
- [ ] カメラロール権限の説明文が具体的か（「アプリのために必要」はNG）
- [ ] クラッシュしないか（Xcodeの Instruments でメモリ確認）
- [ ] UIが壊れているフレームがないか

### リリース
- [ ] 審査通過後、手動リリース or 自動リリースを選択
- [ ] リリース後、App Store の検索に反映されるまで数時間〜1日かかる

---

## コスト・時間の目安

| 項目 | コスト | 備考 |
|------|--------|------|
| Apple Developer Program | $99/年（約15,000円） | 必須 |
| Xcode | 無料 | Mac App Store |
| プライバシーポリシーホスティング | 無料 | GitHub Pages等 |
| **合計** | **約15,000円/年** | |

| フェーズ | 目安期間 |
|----------|---------|
| 環境準備 | 1〜2日 |
| MVP実装 | 2〜4週間 |
| テスト | 1週間 |
| 申請準備（素材・文章） | 2〜3日 |
| 審査 | 1〜7日 |
| **合計** | **約1〜2ヶ月** |

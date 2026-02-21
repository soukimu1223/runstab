# 動画逆さま修正 計画

## 根本原因
`CIImage`（左下原点）を `CVPixelBuffer`（左上原点）に `ciContext.render` で書き込む際に Y 軸反転が発生する。

## 修正方針
`ciContext.render` 直前に Y 軸反転 transform を 1 回適用する（最小変更・1ファイル）。

## 変更ファイル
- `RunStab/RunStab/Services/VideoStabilizer.swift` — 3行追加

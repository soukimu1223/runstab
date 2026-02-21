"""
動画から指定フレームを画像として書き出すスクリプト。
走者が最初に映るフレームと最後に映るフレームを特定するために使う。

Usage:
  python3 pick_points.py <video.mov>          # 全フレームを等間隔10枚書き出し
  python3 pick_points.py <video.mov> <n>      # n枚書き出し
  python3 pick_points.py <video.mov> 5 20 35  # フレーム番号を直接指定して書き出し
"""
import sys
import os
import cv2


def main():
    if len(sys.argv) < 2:
        print(f"Usage: python3 {sys.argv[0]} <video.mov> [n or frame1 frame2 ...]")
        sys.exit(1)

    path = sys.argv[1]
    cap = cv2.VideoCapture(path)
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = cap.get(cv2.CAP_PROP_FPS)

    print(f"動画: {path}")
    print(f"解像度: {w}x{h}, FPS: {fps:.0f}, 総フレーム数: {total}")
    print()

    # 書き出すフレームを決定
    args = sys.argv[2:]
    if not args:
        # デフォルト: 等間隔10枚
        n = 10
        frame_indices = [int(i * (total - 1) / (n - 1)) for i in range(n)]
    elif len(args) == 1:
        # n枚
        n = int(args[0])
        frame_indices = [int(i * (total - 1) / (n - 1)) for i in range(n)]
    else:
        # フレーム番号直接指定
        frame_indices = [int(a) for a in args]

    base = path.rsplit(".", 1)[0]
    out_dir = f"{base}_frames"
    os.makedirs(out_dir, exist_ok=True)

    saved = []
    for idx in frame_indices:
        idx = max(0, min(idx, total - 1))
        cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
        ret, frame = cap.read()
        if not ret:
            continue
        out_path = os.path.join(out_dir, f"frame_{idx:04d}.jpg")
        cv2.imwrite(out_path, frame)
        saved.append((idx, out_path))

    cap.release()

    print(f"書き出し先: {out_dir}/")
    for idx, p in saved:
        print(f"  frame {idx:4d} → {os.path.basename(p)}")

    print()
    print("▼ 走者が映っている最初と最後のフレーム番号を確認したら:")
    print(f"  1. プレビュー.appで画像を開き、⌘I でインスペクタ表示")
    print(f"  2. 走者の上にカーソルを置いてX,Y座標を読む")
    print(f"  3. 実行:")
    print(f"     python3 stabilize.py {path} out.mp4 <start_frame> <sx> <sy> <end_frame> <ex> <ey>")


if __name__ == "__main__":
    main()

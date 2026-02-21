"""
ランニング動画 → トレッドミル風動画 変換スクリプト

トラックを走る人物を定点カメラで撮影した動画を、
人物を画面中央に水平固定し「トレッドミルで走っているように見える」縦動画(9:16)に変換する。

手法: MOG2背景差分で動体検出 → 外れ値除去 → 線形回帰フィット → 走者中心クロップ

Usage:
    python3 stabilize.py run_sample.mov [output.mp4]
"""

import sys
from datetime import datetime

import cv2
import numpy as np


def detect_runner_positions(video_path: str, max_frames: int = -1) -> tuple[dict[int, tuple[int, int]], int, int, int, int]:
    """HOG全フレーム検出 + RANSAC軌道フィットで走者を追跡する。"""
    import random

    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print(f"Error: cannot open {video_path}", file=sys.stderr)
        sys.exit(1)

    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = int(cap.get(cv2.CAP_PROP_FPS))
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    if max_frames > 0:
        total = min(total, max_frames)

    hog = cv2.HOGDescriptor()
    hog.setSVMDetector(cv2.HOGDescriptor_getDefaultPeopleDetector())

    scale = 0.5
    # Y方向の検出範囲を広め（25〜80%）に設定
    y_top = int(height * 0.25)
    y_bot = int(height * 0.80)

    # 全フレームで HOG 検出（複数人含む）
    all_dets: list[list[tuple[int, int, float]]] = []  # [(cx, cy, weight), ...]
    color_frames: list[np.ndarray] = []
    print(f"  Running HOG on all {total} frames...")
    for _ in range(total):
        ret, frame = cap.read()
        if not ret:
            break
        color_frames.append(frame)
        roi = frame[y_top:y_bot, :]
        small = cv2.resize(roi, None, fx=scale, fy=scale)
        boxes, weights = hog.detectMultiScale(small, winStride=(8, 8), padding=(4, 4), scale=1.05)
        frame_dets: list[tuple[int, int, float]] = []
        for j, (x, y, w, h) in enumerate(boxes):
            cx = int((x + w / 2) / scale)
            cy = int((y + h / 2) / scale) + y_top
            frame_dets.append((cx, cy, float(weights[j])))
        all_dets.append(frame_dets)
    cap.release()

    actual_total = len(color_frames)
    print(f"Frames: {actual_total}, Resolution: {width}x{height}, FPS: {fps}")

    # HOG検出を (frame_idx, cx, cy) のフラットリストに
    det_list: list[tuple[int, int, int]] = []
    for i, dets in enumerate(all_dets):
        for cx, cy, w in dets:
            det_list.append((i, cx, cy))

    if len(det_list) < 4:
        print("Warning: very few HOG detections. Falling back to center.", file=sys.stderr)
        detections = {i: (width // 2, height // 2) for i in range(actual_total)}
        return detections, width, height, fps, actual_total

    # RANSAC: 最も一貫した線形軌道を探す
    print(f"  Total HOG detections: {len(det_list)}. Running RANSAC...")
    best_inliers: list[tuple[int, int, int]] = []
    inlier_threshold = 80  # px
    random.seed(42)
    for _ in range(500):
        i1, i2 = random.sample(range(len(det_list)), 2)
        f1, x1, _ = det_list[i1]
        f2, x2, _ = det_list[i2]
        if f1 == f2:
            continue
        a = (x2 - x1) / (f2 - f1)
        b = x1 - a * f1
        inliers = [(f, cx, cy) for f, cx, cy in det_list if abs(cx - (a * f + b)) < inlier_threshold]
        if len(inliers) > len(best_inliers):
            best_inliers = inliers

    print(f"  RANSAC inliers: {len(best_inliers)}/{len(det_list)}")

    # インライアで線形回帰
    frames_in = np.array([d[0] for d in best_inliers], dtype=float)
    xs_in = np.array([d[1] for d in best_inliers], dtype=float)
    ys_in = np.array([d[2] for d in best_inliers], dtype=float)
    a_fit, b_fit = np.polyfit(frames_in, xs_in, 1)
    y_center = float(np.median(ys_in))

    all_frames = np.arange(actual_total, dtype=float)
    xs_linear = a_fit * all_frames + b_fit

    detections = {i: (int(np.clip(xs_linear[i], 0, width - 1)), int(y_center))
                  for i in range(actual_total)}

    detected_count = len(best_inliers)
    print(f"Runner tracked: {detected_count} HOG inliers → x = {a_fit:.2f}*frame + {b_fit:.0f}")
    return detections, width, height, fps, actual_total


def fit_linear_trajectory(
    detections: dict[int, tuple[int, int]], total_frames: int
) -> tuple[np.ndarray, float]:
    """検出結果の外れ値を除去してから線形回帰をフィット。Yは固定値（中央値）。"""
    indices = np.array(sorted(detections.keys()), dtype=float)
    xs_detected = np.array([detections[int(i)][0] for i in indices], dtype=float)
    ys_detected = np.array([detections[int(i)][1] for i in indices], dtype=float)

    # 外れ値除去: 仮フィット後に残差が大きいものを除く
    a_tmp, b_tmp = np.polyfit(indices, xs_detected, 1)
    residuals = np.abs(xs_detected - (a_tmp * indices + b_tmp))
    threshold = np.median(residuals) * 3 + 10
    mask = residuals < threshold
    print(f"Outlier rejection: {mask.sum()}/{len(mask)} detections kept (threshold={threshold:.0f}px)")

    indices_clean = indices[mask]
    xs_clean = xs_detected[mask]
    ys_clean = ys_detected[mask]

    # X座標に線形回帰: x = a * frame + b
    a, b = np.polyfit(indices_clean, xs_clean, 1)
    all_frames = np.arange(total_frames, dtype=float)
    xs_linear = a * all_frames + b

    # Y座標は中央値（外れ値に強い）
    y_center = float(np.median(ys_clean))

    print(f"Linear fit: x = {a:.2f} * frame + {b:.0f} (speed: {a:.2f} px/frame)")

    return xs_linear, y_center


def generate_output(
    video_path: str,
    output_path: str,
    smoothed_xs: np.ndarray,
    y_center: float,
    src_width: int,
    src_height: int,
    fps: int,
    total_frames: int,
) -> None:
    """平滑化された X 座標を中心にクロップして縦動画を書き出す。"""
    # クロップサイズ: 走者をフレーム高さの約50-60%に表示する 9:16 領域
    # 走者の高さは約300px、出力高さの55%程度にしたい → crop_h = 300/0.55 ≈ 545
    crop_h = int(src_height * 0.15)
    crop_w = int(crop_h * 9 / 16)

    if crop_w > src_width:
        crop_w = src_width
        crop_h = int(crop_w * 16 / 9)

    # Y方向は走者中心に固定
    y_top = int(y_center) - crop_h // 2
    y_top = max(0, min(y_top, src_height - crop_h))

    # 出力解像度
    out_w, out_h = 1080, 1920

    print(f"Crop region: {crop_w}x{crop_h} from {src_width}x{src_height}")
    print(f"Y center: {int(y_center)}px (top: {y_top}px)")
    print(f"Output: {out_w}x{out_h}")

    cap = cv2.VideoCapture(video_path)
    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    out = cv2.VideoWriter(output_path, fourcc, fps, (out_w, out_h))

    for frame_idx in range(total_frames):
        ret, frame = cap.read()
        if not ret:
            break

        x_center = int(smoothed_xs[frame_idx])
        x_left = x_center - crop_w // 2
        x_left = max(0, min(x_left, src_width - crop_w))

        cropped = frame[y_top : y_top + crop_h, x_left : x_left + crop_w]
        resized = cv2.resize(cropped, (out_w, out_h))
        out.write(resized)

    cap.release()
    out.release()
    print(f"Output saved: {output_path} ({frame_idx + 1} frames)")


def main() -> None:
    usage = (
        f"Usage:\n"
        f"  自動検出:      python3 {sys.argv[0]} <input.mov> [output.mp4]\n"
        f"  位置指定:      python3 {sys.argv[0]} <input.mov> [output.mp4] <sf> <sx> <sy> <ef> <ex> <ey>\n"
        f"    sf/ef = 走者が映っている最初/最後のフレーム番号\n"
        f"    sx,sy / ex,ey = そのフレームでの走者の中心座標(px)"
    )
    if len(sys.argv) < 2:
        print(usage)
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = None
    # manual_points: (start_frame, sx, sy, end_frame, ex, ey)
    manual_points: tuple[int, int, int, int, int, int] | None = None

    args = sys.argv[2:]
    if len(args) == 0:
        pass
    elif len(args) == 1:
        output_path = args[0]
    elif len(args) == 6:
        try:
            sf, sx, sy, ef, ex, ey = (int(a) for a in args)
            manual_points = (sf, sx, sy, ef, ex, ey)
        except ValueError:
            pass
    elif len(args) == 7:
        output_path = args[0]
        try:
            sf, sx, sy, ef, ex, ey = (int(a) for a in args[1:])
            manual_points = (sf, sx, sy, ef, ex, ey)
        except ValueError:
            pass

    if output_path is None:
        timestamp = datetime.now().strftime("%y%m%d%H%M")
        base = input_path.rsplit(".", 1)[0]
        output_path = f"{base}_{timestamp}.mp4"

    cap = cv2.VideoCapture(input_path)
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = int(cap.get(cv2.CAP_PROP_FPS))
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    cap.release()

    if manual_points is not None:
        sf, sx, sy, ef, ex, ey = manual_points
        print(f"Manual tracking: frame{sf}({sx},{sy}) → frame{ef}({ex},{ey}), total={total}frames")

        # sf〜ef 間を線形補間、範囲外はクランプ
        speed_x = (ex - sx) / max(ef - sf, 1)
        speed_y = (ey - sy) / max(ef - sf, 1)
        smoothed_xs = np.array([
            np.clip(sx + speed_x * (i - sf), 0, width - 1) for i in range(total)
        ])
        ys = np.array([
            np.clip(sy + speed_y * (i - sf), 0, height - 1) for i in range(total)
        ])
        y_center = float(np.mean(ys[sf:ef + 1]))
    else:
        print("Step 1/3: Detecting runner in each frame (HOG + RANSAC)...")
        detections, width, height, fps, total = detect_runner_positions(input_path)

        if len(detections) < 2:
            print("Error: Not enough detections to track.", file=sys.stderr)
            sys.exit(1)

        print("Step 2/3: Fitting linear trajectory...")
        smoothed_xs, y_center = fit_linear_trajectory(detections, total)

    print(f"X range: {smoothed_xs.min():.0f} - {smoothed_xs.max():.0f}px")
    print(f"Y center (fixed): {y_center:.0f}px")

    print("Step 3/3: Generating output video...")
    generate_output(input_path, output_path, smoothed_xs, y_center, width, height, fps, total)

    print("Done!")


if __name__ == "__main__":
    main()

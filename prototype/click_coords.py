"""
画像をクリックしてピクセル座標を取得するツール。

Usage: python3 click_coords.py <image.jpg>
  - 画像ウィンドウが開く
  - クリックした位置の座標がターミナルに表示される
  - 'q' または ESC で終了
"""
import sys
import cv2

def main():
    if len(sys.argv) < 2:
        print(f"Usage: python3 {sys.argv[0]} <image.jpg>")
        sys.exit(1)

    img_path = sys.argv[1]
    img = cv2.imread(img_path)
    if img is None:
        print(f"Error: cannot open {img_path}")
        sys.exit(1)

    h, w = img.shape[:2]
    # 画面に収まるようにリサイズ（表示用）
    scale = min(1.0, 960 / h, 540 / w)
    disp = cv2.resize(img, None, fx=scale, fy=scale)

    clicks = []

    def on_click(event, x, y, flags, param):
        if event == cv2.EVENT_LBUTTONDOWN:
            # 実際のピクセル座標に変換
            rx, ry = int(x / scale), int(y / scale)
            clicks.append((rx, ry))
            print(f"  クリック: x={rx}, y={ry}")
            # クリック位置に印をつける
            cv2.circle(disp, (x, y), 8, (0, 255, 0), 2)
            cv2.putText(disp, f"({rx},{ry})", (x+10, y-10),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
            cv2.imshow("Click to get coords  [q=quit]", disp)

    cv2.imshow("Click to get coords  [q=quit]", disp)
    cv2.setMouseCallback("Click to get coords  [q=quit]", on_click)

    print(f"画像: {img_path} ({w}x{h})")
    print("走者の中心をクリックしてください。[q] で終了。")
    print()

    while True:
        key = cv2.waitKey(20) & 0xFF
        if key in (ord('q'), 27):
            break

    cv2.destroyAllWindows()

    if clicks:
        print()
        print("=== 取得した座標 ===")
        for i, (x, y) in enumerate(clicks):
            print(f"  クリック {i+1}: x={x}, y={y}")

if __name__ == "__main__":
    main()

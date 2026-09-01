#!/usr/bin/env python3
"""에뮬레이터 화면과 build/expected.png 를 비교한다.

에뮬레이터가 내놓는 색은 팔레트 값을 8비트로 늘린 것이라 파이썬이 계산한
값과 한두 단계 어긋날 수 있다. 그래서 양쪽을 팔레트 16색으로 되돌린 뒤
색 번호끼리 비교한다.
"""
import sys
from PIL import Image
import numpy as np

sys.path.insert(0, __file__.rsplit('/', 1)[0])
from mkdata import MSX2_PALETTE   # 팔레트 하나만 쓴다 (mkdata 의 SCREENS 정의까지 딸려 온다)

PAL = np.array([[v * 255 // 7 for v in c] for c in MSX2_PALETTE], dtype=np.int32)

def to_index(im, w, h):
    """어떤 크기로 찍혔든 화면 알맹이 wxh 만 잘라내고 색 번호 판으로 바꾼다.

    openMSX 의 raw 화면은 테두리까지 담은 320x240 이다. SCREEN 5 의
    256x212 는 그 한가운데에 있다 (x+32, y+14)."""
    im = im.convert('RGB')
    sw, sh = im.size
    if sw > 320 and sw % 320 == 0 and sh % 240 == 0:      # 확대해서 찍혔으면
        f = sw // 320
        im = im.resize((sw // f, sh // f), Image.NEAREST)
        sw, sh = im.size
    if (sw, sh) != (w, h):
        if sw < w or sh < h:
            sys.exit("화면이 %s 라 %dx%d 를 잘라낼 수 없다." % (im.size, w, h))
        ox, oy = (sw - w) // 2, (sh - h) // 2             # 테두리를 벗긴다
        im = im.crop((ox, oy, ox + w, oy + h))
    a = np.asarray(im, dtype=np.int32)   # 제곱하면 int16 을 넘는다
    d = ((a[:, :, None, :] - PAL[None, None, :, :]) ** 2).sum(-1)
    return d.argmin(-1)

def main(shot_path, want_path):
    want = Image.open(want_path)
    w, h = want.size
    a, b = to_index(Image.open(shot_path), w, h), to_index(want, w, h)
    bad = a != b
    n = int(bad.sum())
    if n == 0:
        print("일치: %dx%d 픽셀 전부 같다." % (w, h))
        return 0
    ys, xs = np.nonzero(bad)
    print("다른 픽셀 %d개 / %d개 (%.2f%%)" % (n, w * h, 100.0 * n / (w * h)))
    print("  범위 x %d~%d, y %d~%d" % (xs.min(), xs.max(), ys.min(), ys.max()))
    for row in sorted(set(ys.tolist()))[:8]:
        print("  y=%-3d 다른 픽셀 %d개" % (row, int(bad[row].sum())))
    Image.fromarray((bad * 255).astype('uint8')).save(want_path.replace('.png', '_diff.png'))
    print("  차이 그림: %s" % want_path.replace('.png', '_diff.png'))
    return 1

if __name__ == '__main__':
    sys.exit(main(sys.argv[1], sys.argv[2]))

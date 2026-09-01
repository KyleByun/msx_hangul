#!/usr/bin/env python3
"""화면에 찍을 것을 어셈블리 자료로 굽고, 같은 것을 그림으로도 그려 둔다.

판이 둘이다. --mode 16 은 16x16 조합형(벌 8/4/4), --mode 8 은 개미체
8x8 조합형(벌 1/1/1)이다. 화면 정의가 아래 SCREENS 한 곳에만 있으므로,
롬과 기대 그림이 어긋날 수가 없다.

  build/hanfont*.bin   조합형 폰트 (src/hangul*.asm 이 INCBIN 한다)
  src/hantext*.asm     띠와 글줄 목록
  build/expected*.png  이 롬이 내야 하는 화면. verify.sh 가 이것과 비교한다.
"""
import argparse, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import johab

SCR_W, SCR_H = 256, 212

# --- 색 (SCREEN 5 기본 팔레트 번호) -------------------------------------------
BLACK, BLUE, CYAN, GREEN, YELLOW, WHITE, GRAY = 1, 4, 7, 3, 11, 15, 14

# --- 조합형이 아닌 낱개 그림 --------------------------------------------------
# 조합형 코드는 언제나 비트 15 가 1이다. 0 이면 이 표의 번호로 본다.
def _sym(size, spec):
    """{행: 열범위 목록} -> size x size 비트맵. 한 행이 size/8 바이트."""
    wide = size == 16
    b = bytearray(size * (2 if wide else 1))
    for r, bars in spec.items():
        v = 0
        for lo, hi in bars:
            v |= sum(1 << (size - 1 - c) for c in range(lo, hi + 1))
        if wide:
            b[r*2], b[r*2+1] = v >> 8, v & 0xFF
        else:
            b[r] = v
    return bytes(b)

SYMBOLS16 = {
    'blank': bytes(32),
    '+': _sym(16, {**{r: [(7, 8)]  for r in (4, 5, 6, 9, 10, 11)},
                   **{r: [(4, 11)] for r in (7, 8)}}),
    '=': _sym(16, {r: [(3, 12)] for r in (5, 6, 9, 10)}),
}
SYMBOLS8 = {
    'blank': bytes(8),
    '+': _sym(8, {**{r: [(3, 3)] for r in (1, 2, 4, 5)}, 3: [(1, 5)]}),
    '=': _sym(8, {r: [(1, 5)] for r in (2, 4)}),
}

# =============================================================================
# 화면 정의
# =============================================================================
# 띠: (y, 라인수, 색). 나머지 바탕은 BLUE 로 지운다.
# 글줄: (x, y, 글자색, 바탕색, 내용). x 에 None 을 주면 가운데로 맞춘다.
# 내용의 문자열은 한글 음절과 공백만 쓴다. 튜플은 낱자, 그 밖은 기호 이름.
JAMO_PANEL = [('cho', 18), '+', ('jung', 0), '+', ('jong', 4), '=', ' ', "한"]

SCREENS = {
    16: dict(
        font='assets/hangul16.fnt', adv=16, symbols=SYMBOLS16,
        bands=[(0, 28, BLACK), (144, 52, BLACK)],
        lines=[
            (None,   6, YELLOW, BLACK, "조합형 한글 출력"),

            (  24,  40, WHITE,  BLUE,  "두 바이트에 다섯 비트씩"),
            (  24,  60, WHITE,  BLUE,  "초성 중성 종성을 담는다"),

            (  24,  92, CYAN,   BLUE,  "초성 여덟 벌"),
            (None, 112, WHITE,  BLUE,  "가고구과궈각곡곽"),

            (None, 150, CYAN,   BLACK, "낱자 셋을 합친다"),
            (None, 172, GREEN,  BLACK, JAMO_PANEL),
        ],
    ),
    8: dict(
        font='assets/gaemi7x8.fnt', adv=8, symbols=SYMBOLS8,
        bands=[(0, 14, BLACK), (88, 62, BLACK), (156, 44, BLACK)],
        lines=[
            (None,   3, YELLOW, BLACK, "개미체 조합형 한글"),

            (   8,  22, WHITE,  BLUE,  "한 글자가 여덟 바이트다"),
            (   8,  32, WHITE,  BLUE,  "폰트를 다 합쳐도 오백육십"),

            (   8,  50, CYAN,   BLUE,  "초성 여덟 벌이 필요 없다"),
            (   8,  60, CYAN,   BLUE,  "개미체는 한 벌뿐이라서"),
            (   8,  72, WHITE,  BLUE,  "가고구과궈각곡곽"),

            (   8,  94, CYAN,   BLACK, "게임 대사라면 이만큼 들어간다"),
            (   8, 108, WHITE,  BLACK, "북쪽 동굴에서 마물이 나왔다고"),
            (   8, 118, WHITE,  BLACK, "촌장이 걱정스레 말했다"),
            (   8, 128, WHITE,  BLACK, "조심해서 다녀오게나"),
            (   8, 138, WHITE,  BLACK, "가는 길에 약초도 좀 캐 오고"),

            (None, 164, CYAN,   BLACK, "낱자 셋을 겹친다"),
            (None, 182, GREEN,  BLACK, JAMO_PANEL),
        ],
    ),
}

def cells(scr, content):
    """글줄 내용 -> 셀 목록. 각 셀은 ('han', 코드) 또는 ('sym', 번호)."""
    names = list(scr['symbols'])
    out = []
    for item in ([content] if isinstance(content, str) else content):
        if isinstance(item, tuple):
            kind, n = item
            out.append(('han', johab.johab_jamo(**{kind: n})))
        elif item in names:
            out.append(('sym', names.index(item)))
        else:
            for ch in item:
                out.append(('sym', names.index('blank')) if ch == ' '
                           else ('han', johab.johab(ch)))
    return out

def placed(scr):
    """글줄마다 (x, y, 글자색, 바탕색, 셀목록, 이름). x 가 None 이면 가운데로."""
    out = []
    for x, y, fg, bg, content in scr['lines']:
        cs = cells(scr, content)
        w = len(cs) * scr['adv']
        if x is None:
            x = (SCR_W - w) // 2 & ~1          # x 는 짝수로 남아야 한다
        if x + w > SCR_W:
            sys.exit("글줄이 화면을 넘는다 (x=%d, %d칸): %r" % (x, len(cs), content))
        out.append((x, y, fg, bg, cs,
                    content if isinstance(content, str) else "낱자 합성"))
    return out

# --- 어셈블리로 굽기 ----------------------------------------------------------
def emit_asm(path, scr, font_name):
    w = ["; tools/mkdata.py 가 만든 파일이다. 손으로 고치지 말고 build.sh 를 다시 돌려라.",
         "; 폰트: %s   한 칸 %dx%d" % (font_name, scr['adv'], scr['adv']), "",
         "; 띠 목록:  db y, 라인수, 색  ...  db 0xFF", "BandList:"]
    for y, h, c in scr['bands']:
        w.append("    db %3d, %3d, %2d" % (y, h, c))
    w += ["    db 0xFF", "",
          "; 글줄 목록:  db y, x, 글자색, 바탕색, 셀수  /  dw 코드 x 셀수  ...  db 0xFF",
          "; 코드의 비트 15 가 1이면 조합형 한글, 0이면 SymbolGlyphs 의 번호다.",
          "TextList:"]
    for x, y, fg, bg, cs, label in placed(scr):
        w.append("    db %3d, %3d, %2d, %2d, %2d      ; %s" % (y, x, fg, bg, len(cs), label))
        for i in range(0, len(cs), 8):
            w.append("    dw " + ", ".join("0x%04X" % c for _, c in cs[i:i+8]))
    w += ["    db 0xFF", "",
          "; 조합형이 아닌 낱개 그림 (%dx%d, %d바이트씩)"
          % (scr['adv'], scr['adv'], len(next(iter(scr['symbols'].values())))),
          "SymbolGlyphs:"]
    for i, (name, g) in enumerate(scr['symbols'].items()):
        w.append("    ; %d: %s" % (i, name))
        for r in range(0, len(g), 8):
            w.append("    db " + ", ".join("0x%02X" % b for b in g[r:r+8]))
    open(path, 'w').write("\n".join(w) + "\n")

# --- 같은 정의로 기대 화면 그리기 ---------------------------------------------
MSX2_PALETTE = [(0,0,0),(0,0,0),(1,6,1),(3,7,3),(1,1,7),(2,3,7),(5,1,1),(2,6,7),
                (7,1,1),(7,3,3),(6,6,1),(6,6,4),(1,4,1),(6,2,5),(5,5,5),(7,7,7)]

def emit_png(path, scr, fnt):
    from PIL import Image
    n = scr['adv']
    syms = list(scr['symbols'].values())
    idx = [[BLUE] * SCR_W for _ in range(SCR_H)]
    for y, h, c in scr['bands']:
        for r in range(y, min(y + h, SCR_H)):
            idx[r] = [c] * SCR_W
    for x, y, fg, bg, cs, _ in placed(scr):
        for i, (kind, code) in enumerate(cs):
            if kind == 'han':
                g = johab.compose(fnt, code) if n == 16 else johab.compose8(fnt, code)
            else:
                g = syms[code]
            rows = johab.art(g) if n == 16 else johab.art8(g)
            for r, bits in enumerate(rows):
                for c, on in enumerate(bits):
                    px, py = x + i*n + c, y + r
                    if 0 <= px < SCR_W and 0 <= py < SCR_H:
                        idx[py][px] = fg if on == '#' else bg
    im = Image.new('RGB', (SCR_W, SCR_H))
    im.putdata([tuple(v * 255 // 7 for v in MSX2_PALETTE[i]) for row in idx for i in row])
    im.save(path)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--mode', type=int, choices=(8, 16), default=16)
    ap.add_argument('--font', default=None, help="기본은 판마다 정해진 폰트")
    a = ap.parse_args()

    scr = SCREENS[a.mode]
    font = a.font or scr['font']
    tag = '' if a.mode == 16 else '8'

    if a.mode == 16:
        fnt = open(font, 'rb').read()
        if len(fnt) != johab.FONT_SIZE:
            sys.exit("폰트가 %d바이트여야 하는데 %d 다: %s" % (johab.FONT_SIZE, len(fnt), font))
    else:
        fnt = johab.build_font8(font)        # 개미체 그릇에서 8x8 만 뽑아 온다

    os.makedirs('build', exist_ok=True)
    open('build/hanfont%s.bin' % tag, 'wb').write(fnt)
    emit_asm('src/hantext%s.asm' % tag, scr, os.path.basename(font))
    emit_png('build/expected%s.png' % tag, scr, fnt)
    print("%dx%d  폰트 %s -> %d바이트, 글줄 %d개 %d칸"
          % (a.mode, a.mode, font, len(fnt), len(scr['lines']),
             sum(len(c) for *_, c, _ in placed(scr))))

if __name__ == '__main__':
    main()

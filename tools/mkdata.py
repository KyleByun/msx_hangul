#!/usr/bin/env python3
"""화면에 찍을 것을 어셈블리 자료로 굽고, 같은 것을 그림으로도 그려 둔다.

판이 셋이다.

  --mode 16   16x16 조합형 (벌 8/4/4). 자모를 겹쳐 11,172자를 다 낸다.
  --mode 8    8x8 개미체 조합형 (벌 1/1/1). 제일 작지만 읽기 힘들다.
  --mode 12   12x12 완성형 부분집합. 겹치지 않고 쓰는 글자만 통째로 갖는다.

화면 정의가 아래 SCREENS 한 곳에만 있으므로, 롬과 기대 그림이 어긋날 수 없다.

  build/hanfont*.bin   폰트 (src/hangul*.asm 이 INCBIN 한다)
  src/hantext*.asm     띠와 글줄 목록
  build/expected*.png  이 롬이 내야 하는 화면. verify.sh 가 이것과 비교한다.
"""
import argparse, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import johab, wanseong

SCR_W, SCR_H = 256, 212

# --- 색 (SCREEN 5 기본 팔레트 번호) -------------------------------------------
BLACK, BLUE, CYAN, GREEN, YELLOW, WHITE, GRAY = 1, 4, 7, 3, 11, 15, 14

# --- 한글이 아닌 낱개 그림 ----------------------------------------------------
def _sym(size, rowbytes, spec):
    """{행: [(왼쪽열, 오른쪽열), ...]} -> 비트맵. 한 줄이 rowbytes 바이트."""
    b = bytearray(size * rowbytes)
    bits = rowbytes * 8
    for r, bars in spec.items():
        v = 0
        for lo, hi in bars:
            v |= sum(1 << (bits - 1 - c) for c in range(lo, hi + 1))
        for k in range(rowbytes):
            b[r*rowbytes + k] = (v >> (8 * (rowbytes - 1 - k))) & 0xFF
    return bytes(b)

SYMBOLS16 = {
    'blank': bytes(32),
    '+': _sym(16, 2, {**{r: [(7, 8)]  for r in (4, 5, 6, 9, 10, 11)},
                      **{r: [(4, 11)] for r in (7, 8)}}),
    '=': _sym(16, 2, {r: [(3, 12)] for r in (5, 6, 9, 10)}),
}
SYMBOLS8 = {
    'blank': bytes(8),
    '+': _sym(8, 1, {**{r: [(3, 3)] for r in (1, 2, 4, 5)}, 3: [(1, 5)]}),
    '=': _sym(8, 1, {r: [(1, 5)] for r in (2, 4)}),
}
# 12x12 도 한 줄이 2바이트고, 아래 4비트는 늘 0이다 (wanseong.pack 과 같은 규칙).
SYMBOLS12 = {
    'blank': bytes(24),
    '+': _sym(12, 2, {**{r: [(5, 6)] for r in (2, 3, 6, 7)},
                      **{r: [(2, 9)] for r in (4, 5)}}),
    '=': _sym(12, 2, {r: [(2, 9)] for r in (3, 4, 7, 8)}),
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
        kind='johab', font='assets/hangul16.fnt', adv=16, symbols=SYMBOLS16,
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
        kind='johab', font='assets/gaemi7x8.fnt', adv=8, symbols=SYMBOLS8,
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
    12: dict(
        kind='wanseong', font='assets/saemmul12', adv=12, symbols=SYMBOLS12,
        bands=[(0, 20, BLACK), (96, 78, BLACK)],
        lines=[
            (None,   4, YELLOW, BLACK, "완성형 부분집합 한글"),

            (   8,  28, WHITE,  BLUE,  "자모를 겹치지 않는다"),
            (   8,  44, WHITE,  BLUE,  "쓰는 글자만 통째로 담는다"),
            (   8,  60, CYAN,   BLUE,  "한 자에 스물네 바이트"),
            (   8,  76, CYAN,   BLUE,  "한 줄에 스물한 자가 들어간다"),

            (   8, 102, CYAN,   BLACK, "게임 대사라면 이렇게 보인다"),
            (   8, 120, WHITE,  BLACK, "북쪽 동굴에서 마물이 나왔다고"),
            (   8, 136, WHITE,  BLACK, "촌장이 걱정스레 말했다"),
            (   8, 152, WHITE,  BLACK, "조심해서 다녀오게나"),

            (None, 184, GREEN,  BLUE,  "여덟 점보다 잘 읽힌다"),
        ],
    ),
}

def cells(scr, content):
    """글줄 내용 -> 셀 목록.
    조합형은 ('han', 코드) / ('sym', 번호), 완성형은 ('chr', 글자) / ('sym', 번호)."""
    names = list(scr['symbols'])
    out = []
    for item in ([content] if isinstance(content, str) else content):
        if isinstance(item, tuple):
            if scr['kind'] != 'johab':
                sys.exit("완성형 판에는 낱자를 넣을 수 없다 (조합하지 않으므로)")
            kind, n = item
            out.append(('han', johab.johab_jamo(**{kind: n})))
        elif item in names:
            out.append(('sym', names.index(item)))
        else:
            for ch in item:
                if ch == ' ':
                    out.append(('sym', names.index('blank')))
                elif scr['kind'] == 'johab':
                    out.append(('han', johab.johab(ch)))
                else:
                    out.append(('chr', ch))
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

def used_chars(scr):
    """완성형 판이 폰트에 담아야 하는 글자들."""
    return ''.join(c for *_, cs, _ in placed(scr) for k, c in cs if k == 'chr')

def numbers(scr, index, base):
    """셀 -> 롬에 적을 값. 조합형이면 조합형 코드, 완성형이면 글리프 번호."""
    def one(kind, v):
        if kind == 'han':
            return v
        if kind == 'sym':
            return v if scr['kind'] == 'johab' else base + v
        return index[v]
    return [[one(*c) for c in cs] for *_, cs, _ in placed(scr)]

# --- 어셈블리로 굽기 ----------------------------------------------------------
def emit_asm(path, scr, font_name, index, base):
    n = scr['adv']
    w = ["; tools/mkdata.py 가 만든 파일이다. 손으로 고치지 말고 build.sh 를 다시 돌려라.",
         "; 폰트: %s   한 칸 %dx%d   방식: %s" % (font_name, n, n, scr['kind']), "",
         "; 띠 목록:  db y, 라인수, 색  ...  db 0xFF", "BandList:"]
    for y, h, c in scr['bands']:
        w.append("    db %3d, %3d, %2d" % (y, h, c))
    w += ["    db 0xFF", "",
          "; 글줄 목록:  db y, x, 글자색, 바탕색, 셀수  /  dw 값 x 셀수  ...  db 0xFF"]
    w.append("; 값은 조합형 코드다. 비트 15 가 0이면 SymbolGlyphs 안의 번호다."
             if scr['kind'] == 'johab' else
             "; 값은 폰트 안의 글리프 번호다. 조합하지 않으므로 그대로 주소가 된다.")
    w.append("TextList:")
    for (x, y, fg, bg, cs, label), vals in zip(placed(scr), numbers(scr, index, base)):
        w.append("    db %3d, %3d, %2d, %2d, %2d      ; %s" % (y, x, fg, bg, len(cs), label))
        for i in range(0, len(vals), 8):
            w.append("    dw " + ", ".join("0x%04X" % v for v in vals[i:i+8]))
    w += ["    db 0xFF", ""]
    if scr['kind'] == 'johab':
        g0 = next(iter(scr['symbols'].values()))
        w += ["; 조합형이 아닌 낱개 그림 (%dx%d, %d바이트씩)" % (n, n, len(g0)),
              "SymbolGlyphs:"]
        for i, (name, g) in enumerate(scr['symbols'].items()):
            w.append("    ; %d: %s" % (i, name))
            for r in range(0, len(g), 8):
                w.append("    db " + ", ".join("0x%02X" % b for b in g[r:r+8]))
    else:
        w += ["; 낱개 그림은 폰트 뒤에 이어 붙어 있다. 글자 %d개 다음부터다." % base,
              "GLYPH_COUNT equ %d" % (base + len(scr['symbols']))]
    open(path, 'w').write("\n".join(w) + "\n")

# --- 같은 정의로 기대 화면 그리기 ---------------------------------------------
MSX2_PALETTE = [(0,0,0),(0,0,0),(1,6,1),(3,7,3),(1,1,7),(2,3,7),(5,1,1),(2,6,7),
                (7,1,1),(7,3,3),(6,6,1),(6,6,4),(1,4,1),(6,2,5),(5,5,5),(7,7,7)]

def emit_png(path, scr, fnt, index, base):
    from PIL import Image
    n = scr['adv']
    syms = list(scr['symbols'].values())
    idx = [[BLUE] * SCR_W for _ in range(SCR_H)]
    for y, h, c in scr['bands']:
        for r in range(y, min(y + h, SCR_H)):
            idx[r] = [c] * SCR_W
    for (x, y, fg, bg, cs, _), vals in zip(placed(scr), numbers(scr, index, base)):
        for i, ((kind, _), v) in enumerate(zip(cs, vals)):
            if scr['kind'] == 'wanseong':
                rows = wanseong.art(fnt[v*24:(v+1)*24])
            elif kind == 'sym':
                g = syms[v]
                rows = johab.art(g) if n == 16 else johab.art8(g)
            else:
                g = johab.compose(fnt, v) if n == 16 else johab.compose8(fnt, v)
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
    ap.add_argument('--mode', type=int, choices=(8, 12, 16), default=16)
    ap.add_argument('--font', default=None, help="기본은 판마다 정해진 폰트")
    a = ap.parse_args()

    scr = SCREENS[a.mode]
    font = a.font or scr['font']
    tag = {16: '', 8: '8', 12: '12'}[a.mode]
    index, base, note = {}, 0, ''

    if scr['kind'] == 'johab':
        if a.mode == 16:
            fnt = open(font, 'rb').read()
            if len(fnt) != johab.FONT_SIZE:
                sys.exit("폰트가 %d바이트여야 하는데 %d 다: %s" % (johab.FONT_SIZE, len(fnt), font))
        else:
            fnt = johab.build_font8(font)     # 개미체 그릇에서 8x8 만 뽑아 온다
    else:
        # 미리 뽑아 둔 부분집합을 읽는다. 글을 바꿨으면 tools/mkfont12.py 를 돌린다.
        sub, index = wanseong.load_subset(font)
        need = sorted(set(used_chars(scr)))
        missing = [c for c in need if c not in index]
        if missing:
            sys.exit("%s.fnt 에 없는 글자: %s\n"
                     "  글을 바꿨으면 tools/mkfont12.py 를 다시 돌리세요."
                     % (font, ''.join(missing)))
        base = len(index)
        fnt = sub + b''.join(scr['symbols'].values())
        note = "  글자 %d자 + 낱개 그림 %d개" % (base, len(scr['symbols']))

    os.makedirs('build', exist_ok=True)
    open('build/hanfont%s.bin' % tag, 'wb').write(fnt)
    emit_asm('src/hantext%s.asm' % tag, scr, os.path.basename(font), index, base)
    emit_png('build/expected%s.png' % tag, scr, fnt, index, base)
    print("%dx%d  %-8s 폰트 %s -> %d바이트, 글줄 %d개 %d칸%s"
          % (a.mode, a.mode, scr['kind'], font, len(fnt), len(scr['lines']),
             sum(len(c) for *_, c, _ in placed(scr)), note))

if __name__ == '__main__':
    main()

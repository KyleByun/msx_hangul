#!/usr/bin/env python3
"""조합형 표가 맞는지 스스로 확인한다. 어셈블리를 짜기 전에 이것부터 돌렸다.

  1. 자모 셋을 통째로 OR 해도 되는가?
     PUTHAN.PAS 는 받침이 있을 때 행 범위를 나눠 덮어쓴다. 한글 11172자를
     두 방식으로 합성해 한 바이트라도 다른 글자가 있는지 센다.

  2. 유니코드 -> 조합형 -> 폰트 번호 왕복이 어긋나지 않는가?
     정방향 표(FWD_*)와 역방향 표(TB_*)를 서로 대 본다. 종성 코드값 18
     자리가 비어 있어서 여기가 어긋나기 딱 좋다.

  3. 어셈블리에 손으로 옮겨 적은 표가 파이썬 표와 같은가?
     src/hangul.asm 과 src/hangul8.asm 의 db 줄을 그대로 읽어 한 칸씩 대 본다.
     화면에 나오는 글자는 초성 19개 중 일부, 종성 27개 중 일부밖에 건드리지
     않는다. ㅋ 처럼 FTbJung 이 따로 취급하는 자모는 화면만 봐서는 검사되지 않는다.

  4. 8x8 개미체를 그릇에서 제대로 뽑아냈는가?
     개미체 FNT 는 16x16 그릇에 8x8 을 왼쪽 위로 몰아 그린 2x1x2벌 파일이다.
     정말 1x1x1벌인지(두 벌이 같은지), 글자가 행 1~8 안에만 있는지 확인한다.

  5. 12x12 완성형 부분집합이 성립하는가?
     담긴 글자들끼리 서로 구별되는지, 한 줄의 아래 4비트가 비어 있는지 본다.
     (원본 BDF 전체를 재는 것은 tools/fontscan.py 다. 4MB 원본이 있어야 한다.)
"""
import glob, os, re, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import johab as J

def compose_puthan(fnt, code):
    """PUTHAN.PAS 가 하는 대로. 받침이 있으면 행을 나눠 덮어쓴다."""
    cho, jung, jong = J.decompose(code)
    g = bytearray(32)
    if jong == 0:
        a = J._glyph(fnt, J.OFF_CHO,  J.N_CHO,  J.MTB[1][jung], cho)
        b = J._glyph(fnt, J.OFF_JUNG, J.N_JUNG, J.FTB[0][cho],  jung)
        for i in range(32):
            g[i] = a[i] | b[i]
    else:
        a = J._glyph(fnt, J.OFF_CHO,  J.N_CHO,  J.MTB[2][jung], cho)
        b = J._glyph(fnt, J.OFF_JUNG, J.N_JUNG, J.FTB[1][cho],  jung)
        c = J._glyph(fnt, J.OFF_JONG, J.N_JONG, J.MTB[0][jung], jong)
        for k in range(0, 11):
            g[k*2], g[k*2+1] = a[k*2] | b[k*2], a[k*2+1] | b[k*2+1]
        for k in range(8, 11):
            g[k*2] |= c[k*2]; g[k*2+1] |= c[k*2+1]
        for k in range(11, 16):
            g[k*2], g[k*2+1] = c[k*2], c[k*2+1]
    return bytes(g)

# 어셈블리 표의 이름 -> 파이썬 쪽 짝
CODE_TABLES = [('TbCho', J.TB_CHO), ('TbJung', J.TB_JUNG), ('TbJong', J.TB_JONG)]
BUL_TABLES  = [('FTbJung0', J.FTB[0]), ('FTbJung1', J.FTB[1]),
               ('MTbJong',  J.MTB[0]), ('MTbCho0',  J.MTB[1]), ('MTbCho1', J.MTB[2])]

# 8x8 판은 벌이 하나씩이라 벌 표가 아예 없다. 코드값 표만 16x16 판과 같다.
# 12x12 는 완성형이라 조합 자체를 안 한다. 표가 하나도 없어야 한다.
ASM_FILES = [('hangul.asm',   CODE_TABLES + BUL_TABLES),
             ('hangul8.asm',  CODE_TABLES),
             ('hangul12.asm', [])]

def read_asm_tables(path):
    """src/hangul.asm 에서 라벨 뒤에 이어지는 db 줄의 숫자를 긁어 온다."""
    out, label = {}, None
    for line in open(path, encoding='utf-8'):
        line = line.split(';')[0].rstrip()
        if not line:
            continue
        m = re.match(r'^(\w+):', line)
        if m:
            label = m.group(1)
            out.setdefault(label, [])
            continue
        m = re.match(r'^\s+db\s+(.*)$', line)
        if m and label is not None:
            out[label] += [int(v, 0) for v in m.group(1).split(',')]
        elif line[:1] not in (' ', '\t'):
            label = None
        elif label is not None and not re.match(r'^\s+d[bw]\s', line):
            label = None
    return out

def check_asm_tables(srcdir):
    bad, ntab, ncell = 0, 0, 0
    for fname, tables in ASM_FILES:
        asm = read_asm_tables(os.path.join(srcdir, fname))
        for name, want in tables:
            ntab, ncell = ntab + 1, ncell + len(want)
            got = asm.get(name)
            if got != list(want):
                print("%s 의 %s 가 파이썬 표와 다르다:" % (fname, name))
                print("   asm    %s" % got)
                print("   python %s" % list(want))
                bad += 1
        # 쓰지 않는 표가 남아 있으면 지우다 만 것이다
        for name, _ in CODE_TABLES + BUL_TABLES:
            if name in asm and not any(name == n for n, _ in tables):
                print("%s 에 쓰이지 않는 표 %s 가 남아 있다" % (fname, name)); bad += 1
    print("어셈블리 표    : %s (파일 %d개, 표 %d개, %d칸)"
          % ("통과" if bad == 0 else "실패 %d곳" % bad, len(ASM_FILES), ntab, ncell))
    return bad

def check_roundtrip():
    bad = 0
    for i, c in enumerate(J.FWD_CHO):
        if J.TB_CHO[c] != i + 1:
            print("초성 %d 번이 어긋난다 (코드 %d -> %d)" % (i, c, J.TB_CHO[c])); bad += 1
    for i, c in enumerate(J.FWD_JUNG):
        if J.TB_JUNG[c] != i + 1:
            print("중성 %d 번이 어긋난다 (코드 %d -> %d)" % (i, c, J.TB_JUNG[c])); bad += 1
    for i, c in enumerate(J.FWD_JONG):
        if J.TB_JONG[c] != i:
            print("종성 %d 번이 어긋난다 (코드 %d -> %d)" % (i, c, J.TB_JONG[c])); bad += 1
    assert (len(J.FWD_CHO), len(J.FWD_JUNG), len(J.FWD_JONG)) == (19, 21, 28)
    assert (max(J.TB_CHO), max(J.TB_JUNG), max(J.TB_JONG)) == (J.N_CHO-1, J.N_JUNG-1, J.N_JONG-1)
    print("왕복 검사      : %s" % ("통과" if bad == 0 else "실패 %d 곳" % bad))
    return bad

def check_gaemi(assetdir):
    """개미체 FNT 가 정말 1x1x1벌이고, 8x8 이 행 1~8 안에 들어 있는가."""
    bad = 0
    for path in sorted(glob.glob(os.path.join(assetdir, 'gaemi*.fnt'))):
        raw = open(path, 'rb').read()
        G = [raw[i*32:(i+1)*32] for i in range(J.GAEMI_GLYPHS)]
        for kind in ('cho', 'jong'):          # 2벌짜리 무리는 두 벌이 같아야 한다
            n, at = J.GAEMI_N[kind], J.GAEMI_AT[kind]
            if any(G[at+i] != G[at+n+i] for i in range(n)):
                print("%s: %s 의 두 벌이 다르다 (1x1x1벌이 아니다)"
                      % (os.path.basename(path), kind)); bad += 1
        used = [i for i in range(J.GAEMI_GLYPHS)
                for r in range(16)
                if ((G[i][r*2] << 8) | G[i][r*2+1]) and not (1 <= r <= 8)]
        if used:
            print("%s: 행 1~8 밖에 잉크가 있다 (글리프 %s)"
                  % (os.path.basename(path), used[:5])); bad += 1
        if any(G[i][r*2+1] for i in range(J.GAEMI_GLYPHS) for r in range(16)):
            print("%s: 열 8~15 에 잉크가 있다" % os.path.basename(path)); bad += 1
        f8 = J.build_font8(path)
        print("%-14s : 1x1x1벌 맞고, 뽑아낸 8x8 폰트 %d바이트"
              % (os.path.basename(path), len(f8)))
    return bad

def check_subset12(base):
    """12x12 완성형 부분집합이 쓸 만한 상태인가."""
    import wanseong
    try:
        font, index = wanseong.load_subset(base)     # 크기와 아래 4비트를 여기서 본다
    except (OSError, ValueError) as e:
        print("12x12 부분집합  : 실패 - %s" % e)
        return 1
    seen, bad = {}, 0
    for ch, i in index.items():
        key = font[i*24:(i+1)*24]
        if key in seen:
            print("12x12 에서 '%s' 와 '%s' 가 같은 그림이다" % (seen[key], ch)); bad += 1
        seen[key] = ch
    print("12x12 부분집합 : %s (글자 %d자, %d바이트, 서로 다 구별됨)"
          % ("통과" if bad == 0 else "실패 %d곳" % bad, len(index), len(font)))
    return bad

def main():
    here = os.path.dirname(__file__)
    bad = check_asm_tables(os.path.join(here, '..', 'src'))
    bad += check_roundtrip()

    bad += check_gaemi(os.path.join(here, '..', 'assets'))
    bad += check_subset12(os.path.join(here, '..', 'assets', 'saemmul12'))

    codes = [J.johab(chr(u)) for u in range(0xAC00, 0xD7A4)]
    for path in sorted(glob.glob(os.path.join(here, '..', 'assets', '*.fnt'))):
        fnt = open(path, 'rb').read()
        if len(fnt) != J.FONT_SIZE:      # 16x16 조합형 폰트에만 해당하는 검사다
            continue
        n = sum(1 for c in codes if J.compose(fnt, c) != compose_puthan(fnt, c))
        print("%-14s : 11172자 중 통째 OR 과 PUTHAN 방식이 다른 글자 %d개" % (os.path.basename(path), n))
        bad += n

    return 1 if bad else 0

if __name__ == '__main__':
    sys.exit(main())

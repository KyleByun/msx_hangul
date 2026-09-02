"""완성형(完成形) 부분집합 폰트 만들기 - 12x12.

조합형은 자모를 겹쳐서 글자를 만든다. 자모 몇십 벌로 11,172자를 다 내는 대신,
글자 크기가 작아지면 겹칠 자리가 모자라 뭉개진다. 8x8 에서 한계가 온다.

여기서는 반대로 간다. 글자를 통째로 갖되, **쓰는 글자만** 갖는다.
게임 대사는 빌드할 때 이미 정해져 있으므로 이게 가능하다.
글자 하나가 24바이트니까, 서로 다른 글자 200자를 써도 4,800바이트다.

폰트는 잘 만들어진 16x16 완성형 BDF 에서 12x12 로 줄여 온다. 줄이면 획이
붙어서 서로 구별 안 되는 글자가 생기는데(예: 괮과 괯), 부분집합에서는
'실제로 쓰는 글자들끼리' 부딪히는지만 보면 되고 그건 빌드할 때 확인한다.

  DOSSaemmul  16x16 -> 12x12 로 줄였을 때 11,172자 중 구별 안 되는 글자 94자 (0.8%)
  DOSGothic   같은 조건에서 2,635자 (23.6%) - 그래서 샘물체를 쓴다
"""
import os, sys

CELL = 12
GLYPH_BYTES = CELL * 2          # 한 줄이 12비트지만 2바이트에 담는다 (아래 4비트는 0)

# --- BDF 읽기 -----------------------------------------------------------------
def load_bdf(path, chars):
    """필요한 글자만 뽑아 {코드포인트: (BBX, 16진수 줄들)} 로."""
    want = set(ord(c) for c in chars)
    out, enc, bbx, bits, inbmp, ascent = {}, None, None, None, False, None
    for raw in open(path, 'rb'):
        line = raw.strip()
        if line.startswith(b'FONTBOUNDINGBOX'):
            w, h, xo, yo = (int(x) for x in line.split()[1:5])
            ascent = h + yo                     # 글자 윗변이 기준선에서 얼마나 위인가
        elif line.startswith(b'ENCODING'):
            enc = int(line.split()[1])
        elif line.startswith(b'BBX'):
            bbx = tuple(int(x) for x in line.split()[1:5])
        elif line == b'BITMAP':
            inbmp, bits = True, []
        elif line == b'ENDCHAR':
            if inbmp and enc in want:
                out[enc] = (bbx, bits)
            inbmp = False
        elif inbmp:
            bits.append(line.decode())
    if ascent is None:
        raise ValueError("FONTBOUNDINGBOX 가 없다: %s" % path)
    return out, ascent

def to_grid(entry, ascent, cell=16):
    """BDF 글리프 -> cell x cell 불리언 격자 (왼쪽 위 기준)."""
    (w, h, xoff, yoff), rows = entry
    g = [[False] * cell for _ in range(cell)]
    for i, hexrow in enumerate(rows):
        v, pad = int(hexrow, 16), len(hexrow) * 4
        for x in range(w):
            if v & (1 << (pad - 1 - x)):
                gx, gy = x + xoff, (ascent - yoff - h) + i
                if 0 <= gx < cell and 0 <= gy < cell:
                    g[gy][gx] = True
    return g

# --- 줄이기 -------------------------------------------------------------------
def shrink(g, n=CELL, src=16):
    """src x src -> n x n. 한 칸이 덮는 영역의 절반 이상이 켜져 있으면 켠다.

    'half' 로 고른 이유는 tools/proof.py 의 충돌 검사 결과다. 아무 픽셀이나
    켜져 있으면 켜는 방식('any')은 샘물체에서 2,408자가 뭉치는데, 절반 기준은
    94자로 떨어진다."""
    out = []
    for y in range(n):
        y0, y1 = y * src // n, max(y * src // n + 1, (y + 1) * src // n)
        row = []
        for x in range(n):
            x0, x1 = x * src // n, max(x * src // n + 1, (x + 1) * src // n)
            tot = (y1 - y0) * (x1 - x0)
            on = sum(g[j][i] for j in range(y0, y1) for i in range(x0, x1))
            row.append(on * 2 >= tot)
        out.append(row)
    return out

def pack(grid):
    """nxn 격자 -> 한 줄 2바이트씩. 왼쪽 정렬이라 남는 아래 비트는 0이다.

    12x12 면 한 줄이 12비트라 아래 4비트가 늘 비고, 롬의 blit 루틴이 그걸
    전제한다 (남은 4픽셀을 위쪽 니블에서 꺼낸다)."""
    n = len(grid[0])
    spare = (1 << (16 - n)) - 1
    b = bytearray()
    for row in grid:
        v = sum(1 << (15 - i) for i, on in enumerate(row) if on)
        assert v & spare == 0, "글자 폭보다 아래 비트가 켜져 있다"
        b += bytes((v >> 8, v & 0xFF))
    return bytes(b)

# --- 부분집합 만들기 ----------------------------------------------------------
def build_subset(bdf_path, chars, extra_glyphs=()):
    """쓰는 글자만 담은 12x12 폰트와 글자->번호 표를 만든다.

    extra_glyphs 는 한글이 아닌 낱개 그림(빈칸, '+', '=')이고 뒤에 붙는다.
    반환: (폰트 바이트열, {글자: 번호}, 낱개 그림 시작 번호)"""
    syl = sorted(set(c for c in chars if 0xAC00 <= ord(c) <= 0xD7A3))
    ent, ascent = load_bdf(bdf_path, syl)
    missing = [c for c in syl if ord(c) not in ent]
    if missing:
        raise ValueError("폰트에 없는 글자: %s" % ''.join(missing))

    grids = {c: shrink(to_grid(ent[ord(c)], ascent)) for c in syl}

    # 부분집합 안에서 서로 구별 안 되는 글자가 있으면 여기서 멈춘다.
    seen = {}
    for c in syl:
        key = pack(grids[c])
        if key in seen:
            raise ValueError(
                "12x12 로 줄이면 '%s' 와 '%s' 가 똑같아진다. 글을 바꾸거나 14x14 로 키워라."
                % (seen[key], c))
        seen[key] = c

    font = bytearray()
    index = {}
    for i, c in enumerate(syl):
        index[c] = i
        font += pack(grids[c])
    base = len(syl)
    for g in extra_glyphs:
        assert len(g) == GLYPH_BYTES, "낱개 그림은 %d바이트여야 한다" % GLYPH_BYTES
        font += g
    return bytes(font), index, base

def art(g24):
    """24바이트 -> 12줄짜리 글자그림."""
    return [''.join('#' if ((g24[r*2] << 8) | g24[r*2+1]) & (0x8000 >> c) else '.'
                    for c in range(CELL)) for r in range(CELL)]

# --- 부분집합 파일 주고받기 ---------------------------------------------------
# 원본 BDF 는 4MB 짜리라 저장소에 넣지 않는다. 대신 화면에 쓰는 글자만 뽑아
# 둘로 나눠 둔다. 글을 바꿀 때만 원본이 필요하다 (tools/mkfont12.py).
#
#   assets/saemmul12.txt   글자들. 한 줄, 폰트에 담긴 차례 그대로
#   assets/saemmul12.fnt   글자 수 x 24바이트, 같은 차례

def save_subset(base, font, syls):
    open(base + '.txt', 'w', encoding='utf-8').write(''.join(syls) + '\n')
    open(base + '.fnt', 'wb').write(font)

def load_subset(base):
    syls = open(base + '.txt', encoding='utf-8').read().strip()
    font = open(base + '.fnt', 'rb').read()
    if len(font) != len(syls) * GLYPH_BYTES:
        raise ValueError("%s.fnt 가 %d바이트여야 하는데 %d 다"
                         % (base, len(syls) * GLYPH_BYTES, len(font)))
    if any(font[i] & 0x0F for i in range(1, len(font), 2)):
        raise ValueError("%s.fnt 의 아래 4비트가 비어 있지 않다" % base)
    return font, {c: i for i, c in enumerate(syls)}

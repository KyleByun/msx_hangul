"""조합형(組合型) 한글 코드와 16x16 조합형 폰트를 다루는 표.

두 바이트 안에 다섯 비트씩 세 벌이 들어간다.

    비트 15  14 13 12 11 10   9  8  7  6  5   4  3  2  1  0
         1   [   초성 5    ]  [   중성 5   ]  [   종성 5   ]

폰트 파일(11520바이트)은 자모를 모양이 다른 '벌'별로 여러 벌 담고 있다.

    초성 8벌 x 20자 x 32바이트 = 5120     0x0000~
    중성 4벌 x 22자 x 32바이트 = 2816     0x1400~
    종성 4벌 x 28자 x 32바이트 = 3584     0x1F00~

표의 출처는 hangul11/PUTHAN.PAS (1992, 현실환) 이다. 같은 폴더의 hangle.c
쪽은 벌 결정 규칙과 예제 코드값이 모두 틀려서 쓰지 않았다.
"""

# 코드값(0~31) -> 폰트 안에서의 자모 번호. 표에 없는 자리는 0(채움)이다.
TB_CHO = [0,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,0,0,0,0,0,0,0,0,0,0,0]
TB_JUNG= [0,0,0,1,2,3,4,5,0,0,6,7,8,9,10,11,0,0,12,13,14,15,16,17,0,0,18,19,20,21,0,0]
TB_JONG= [0,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,0,17,18,19,20,21,22,23,24,25,26,27,0,0]

# 벌은 서로 엇갈려서 정해진다. 이 교차가 조합형 출력의 핵심이다.
#   초성의 벌은 '중성'이 정하고, 중성의 벌은 '초성'이 정하며,
#   종성의 벌은 다시 '중성'이 정한다.
FTB = [  # [받침유무][초성 자모번호] -> 중성 벌(0~3)
    [0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1],
    [0,2,3,3,3,3,3,3,3,3,3,3,3,3,3,3,2,3,3,3],
]
MTB = [  # [무엇][중성 자모번호]
    [0,0,2,0,2,1,2,1,2,3,0,2,1,3,3,1,2,1,3,3,1,1],   # 0: 종성 벌(0~3)
    [0,0,0,0,0,0,0,0,0,1,3,3,3,1,2,4,4,4,2,1,3,0],   # 1: 받침 없을 때 초성 벌
    [0,5,5,5,5,5,5,5,5,6,7,7,7,6,6,7,7,7,6,6,7,5],   # 2: 받침 있을 때 초성 벌
]

N_CHO, N_JUNG, N_JONG = 20, 22, 28
SZ = 32                                   # 16x16 한 자모 = 32바이트
OFF_CHO  = 0
OFF_JUNG = 8 * N_CHO * SZ                 # 5120
OFF_JONG = OFF_JUNG + 4 * N_JUNG * SZ     # 7936
FONT_SIZE = OFF_JONG + 4 * N_JONG * SZ    # 11520

# 유니코드 자모 차례 -> 조합형 코드값. 초성만 빈틈이 없고 나머지는 건너뛴다.
FWD_CHO  = [i + 2 for i in range(19)]
FWD_JUNG = [3,4,5,6,7, 10,11,12,13,14,15, 18,19,20,21,22,23, 26,27,28,29]
FWD_JONG = [1] + [i + 2 if i < 16 else i + 3 for i in range(27)]

FILL_CHO, FILL_JUNG, FILL_JONG = 1, 2, 1  # 자모 하나만 보일 때 쓰는 '채움'

def johab(ch):
    """완성형 한글 글자 하나를 조합형 두 바이트 값으로."""
    n = ord(ch) - 0xAC00
    if not 0 <= n < 11172:
        raise ValueError("한글 음절이 아니다: %r" % ch)
    return 0x8000 | (FWD_CHO[n // 588] << 10) | (FWD_JUNG[(n // 28) % 21] << 5) | FWD_JONG[n % 28]

def johab_jamo(cho=None, jung=None, jong=None):
    """자모 하나짜리 조합형 코드. 나머지 자리는 채움으로 메운다.

    낱자를 따로 보여줄 때 쓴다. 채움 자리의 폰트는 비어 있으므로,
    합성 결과에는 지정한 자모 하나만 남는다."""
    return (0x8000
            | ((FWD_CHO[cho]   if cho  is not None else FILL_CHO ) << 10)
            | ((FWD_JUNG[jung] if jung is not None else FILL_JUNG) <<  5)
            | ( FWD_JONG[jong] if jong is not None else FILL_JONG))

def decompose(code):
    """조합형 코드 -> (초성, 중성, 종성) 자모 번호."""
    return (TB_CHO [(code >> 10) & 31],
            TB_JUNG[(code >>  5) & 31],
            TB_JONG[ code        & 31])

def _glyph(fnt, off, per_bul, bul, idx):
    p = off + (bul * per_bul + idx) * SZ
    return fnt[p:p + SZ]

def compose(fnt, code):
    """조합형 코드 -> 16x16 비트맵 32바이트.

    세 자모를 통째로 OR 한다. PUTHAN.PAS 는 행 범위를 나눠 덮어쓰지만,
    한글 11172자 전부를 두 방식으로 합성해 비교해 보면 결과가 같다
    (tools/proof.py). 받침이 있는 벌의 초성/중성이 아래쪽을 이미
    비워 두기 때문이다."""
    cho, jung, jong = decompose(code)
    has = 1 if jong else 0
    a = _glyph(fnt, OFF_CHO,  N_CHO,  MTB[2][jung] if has else MTB[1][jung], cho)
    b = _glyph(fnt, OFF_JUNG, N_JUNG, FTB[has][cho],                         jung)
    g = bytearray(a[i] | b[i] for i in range(SZ))
    if has:
        c = _glyph(fnt, OFF_JONG, N_JONG, MTB[0][jung], jong)
        for i in range(SZ):
            g[i] |= c[i]
    return bytes(g)

def art(g, on='#', off='.'):
    """32바이트 비트맵을 16줄짜리 글자그림으로."""
    return [''.join(on if ((g[r*2] << 8) | g[r*2+1]) & (0x8000 >> c) else off
                    for c in range(16)) for r in range(16)]


# =============================================================================
# 8x8 조합형 (개미체)
#
# 개미체는 도스 한글 라이브러리 한라프로3 의 FNT 그릇(16x16 을 담는 2x1x2벌)
# 에 8x8 을 왼쪽 위로 몰아 그린 글꼴이다. 그릇은 2x1x2벌이지만 내용은
# 1x1x1벌이라 - 같은 그림을 두 번 그려 넣었다 - 벌을 고를 일이 없다.
# 위의 FTB, MTB 가 통째로 필요 없어진다.
#
#   그릇 안의 글리프 차례 : 초성 2벌 x 19자, 중성 1벌 x 21자, 종성 2벌 x 27자
#   글자는 16x16 칸의 행 1~8, 열 0~7 에 들어 있다 (행 0 은 비어 있다)
# =============================================================================
GAEMI_GLYPHS = 113                        # (2*19 + 1*21 + 2*27)
GAEMI_AT = {'cho': 0, 'jung': 38, 'jong': 59}   # 벌 0 의 첫 글리프 위치
GAEMI_N  = {'cho': 19, 'jung': 21, 'jong': 27}

SZ8 = 8                                   # 8x8 한 자모 = 8바이트
OFF8_CHO  = 0
OFF8_JUNG = N_CHO * SZ8                   # 160
OFF8_JONG = OFF8_JUNG + N_JUNG * SZ8      # 336
FONT8_SIZE = OFF8_JONG + N_JONG * SZ8     # 560

def build_font8(path):
    """개미체 FNT -> 8x8 조합형 폰트 560바이트.

    자모 번호 0 자리에 빈 글리프를 하나씩 끼워 넣는다. 개미체에는 '채움'
    글리프가 없지만, 위의 TB_* 표가 채움을 0번으로 보내기 때문이다.
    덕분에 16x16 판과 표를 그대로 함께 쓴다."""
    raw = open(path, 'rb').read()
    if len(raw) != GAEMI_GLYPHS * 32:
        raise ValueError("개미체 FNT 는 %d바이트여야 한다 (%d): %s"
                         % (GAEMI_GLYPHS * 32, len(raw), path))
    out = bytearray()
    for kind, n in (('cho', N_CHO), ('jung', N_JUNG), ('jong', N_JONG)):
        out += bytes(SZ8)                                  # 0번 = 채움/없음
        for i in range(GAEMI_N[kind]):
            g = raw[(GAEMI_AT[kind] + i) * 32:][:32]
            out += bytes(g[r * 2] for r in range(1, 9))    # 행 1~8 의 왼쪽 바이트
        assert len(out) % SZ8 == 0
    assert len(out) == FONT8_SIZE
    return bytes(out)

def compose8(fnt, code):
    """조합형 코드 -> 8x8 비트맵 8바이트. 벌을 고르지 않으므로 그냥 겹친다."""
    cho, jung, jong = decompose(code)
    a = fnt[OFF8_CHO  + cho  * SZ8:][:SZ8]
    b = fnt[OFF8_JUNG + jung * SZ8:][:SZ8]
    c = fnt[OFF8_JONG + jong * SZ8:][:SZ8]
    return bytes(a[i] | b[i] | c[i] for i in range(SZ8))

def art8(g, on='#', off='.'):
    return [''.join(on if g[r] & (0x80 >> c) else off for c in range(8)) for r in range(8)]

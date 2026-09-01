**한국어** · [English](#msx2-johab-hangul-on-a-cartridge)

# MSX2 조합형 한글 출력 예제

MSX2 카트리지 롬 두 개입니다. 두 바이트짜리 **조합형** 한글 코드에서 초성·중성·종성을
다섯 비트씩 뽑아, 자모 폰트 셋을 **실행 중에 겹쳐서** 화면에 찍습니다.
글자를 통째로 갖고 있지 않으므로, 자모 몇십 벌로 한글 11,172자를 전부 냅니다.

| | `hangul.rom` | `hangul8.rom` |
|---|---|---|
| 글자 크기 | **16x16** | **8x8** (글자는 7x8) |
| 폰트 | 벌 8/4/4, **11,520바이트** | 벌 1/1/1, **560바이트** |
| 한 화면 | 16칸 x 13줄 | **32칸 x 26줄** |
| 벌 고르는 표 | 필요 (138바이트) | **없음** |
| 롬에 쓴 것 | 12,676바이트 | **1,628바이트** |
| 진입 | `src/hangul.asm` | `src/hangul8.asm` |

<p align="center">
  <img src="doc/img/hangul.png" width="47%" alt="16x16 조합형 한글">
  <img src="doc/img/hangul8.png" width="47%" alt="8x8 조합형 한글">
</p>

화면 모드는 SCREEN 5 (GRAPHIC 4), 256x212, 16색입니다. sjasmplus 로 빌드하고 openMSX 로 확인합니다.

## 빌드하고 확인하기

```bash
./build.sh          # 둘 다 만든다 (16 또는 8 을 붙이면 한쪽만)
./verify.sh         # 창 없이 부팅해 화면을 찍고, 기대 화면과 픽셀 단위로 비교
./run.sh            # 16x16 판을 창으로 실행
./run.sh 8          # 8x8 판을 창으로 실행
```

윈도우에서는 `build.ps1` / `verify.ps1` 을 쓰세요. 도구 경로는 `tools.sh` (리눅스),
`tools.ps1` (윈도우) 한 곳에만 적혀 있습니다.

`verify.sh` 는 "sjasmplus 가 성공했다" 로 끝내지 않습니다.
`tools/mkdata.py` 가 화면 정의 하나에서 **롬 자료**와 **기대 화면 그림**을 함께 굽고,
에뮬레이터가 찍은 화면을 팔레트 16색으로 되돌려 색 번호끼리 비교합니다.
두 롬 모두 **54,272픽셀이 전부 일치**합니다.

Z80 쪽과 파이썬 쪽은 조합형 표를 따로 한 벌씩 갖고 있고, 서로를 두 가지 방식으로 검산합니다.

| 무엇을 | 어떻게 | 얼마나 |
|---|---|---|
| 표 | `tools/proof.py` 가 `src/hangul*.asm` 의 `db` 줄을 읽어 파이썬 표와 한 칸씩 비교 | 파일 2개, 표 11개 298칸 **전부** |
| 합성 + 출력 | `tools/compare.py` 가 에뮬레이터 화면과 기대 화면을 픽셀 단위로 비교 | 화면에 나온 글자 |

표 검사가 따로 있는 이유는, 화면에 나오는 글자가 초성 19개·종성 27개를 다 덮지 못하기 때문입니다.
예를 들어 ㅋ 은 `FTbJung` 이 따로 취급하는 자모인데 화면에 나오지 않습니다.
그 자리를 한 칸 틀리게 고쳐 보면 픽셀 비교는 그대로 통과하고 `proof.py` 만 잡아냅니다.

## 조합형이 무엇인가

한 글자가 두 바이트고, 그 안에 다섯 비트씩 셋이 들어갑니다.

```
비트  15   14 13 12 11 10    9  8  7  6  5    4  3  2  1  0
      1    [    초성 5   ]   [   중성 5   ]   [   종성 5   ]
```

`한` 은 초성 ㅎ(20), 중성 ㅏ(3), 종성 ㄴ(5) 이므로 `0xD065` 입니다.
자모 자리에는 **채움** 값이 따로 있어서, 낱자 하나만 보여 줄 수도 있습니다.
두 화면 아래쪽의 `ㅎ + ㅏ + ㄴ = 한` 이 그것으로, 왼쪽 셋은 나머지 자리를 채움으로 메운 진짜 조합형 코드입니다.

**두 롬이 이 대목까지는 완전히 같습니다.** 코드를 자르는 방법도, 코드값을 폰트 번호로 바꾸는
표(`TbCho`/`TbJung`/`TbJong`)도 한 칸도 다르지 않습니다. 갈리는 것은 다음 한 가지뿐입니다.

## 갈리는 곳은 '벌' 하나뿐

자모는 이웃에 따라 모양이 달라집니다. `가` 의 ㄱ 과 `구` 의 ㄱ 은 다른 그림입니다.
그래서 16x16 폰트는 같은 자모를 **벌**별로 여러 벌 담고 있고, 어느 벌을 쓸지는 **서로 엇갈려서** 정해집니다.

| 무엇의 벌 | 누가 정하나 | 몇 벌 |
|---|---|---|
| 초성 | **중성**이 정한다 (받침 유무도 본다) | 8벌 |
| 중성 | **초성**이 정한다 (받침 유무도 본다) | 4벌 |
| 종성 | **중성**이 정한다 | 4벌 |

16x16 화면 가운데 줄 `가 고 구 과 궈 각 곡 곽` 이 초성 ㄱ 의 여덟 벌 전부입니다. 여덟 개가 다 다른 그림입니다.
표는 `PUTHAN.PAS` (1992, 현실환) 에서 옮겼습니다 — `src/hangul.asm` 의
`FTbJung0/1`, `MTbCho0/1`, `MTbJong` 입니다.

**8x8 개미체는 벌이 하나씩입니다.** 8x8 에서는 자모 모양을 바꿀 여유가 없기 때문입니다.
그래서 `hangul8.asm` 에는 저 표들이 아예 없습니다. 자모 번호만 알면 바로 주소가 나옵니다.
같은 화면의 `가고구과궈각곡곽` 을 보면 ㄱ 이 여덟 번 다 같은 그림입니다.

> 인터넷에 도는 조합형 예제 코드 중에는 벌 결정 규칙이 틀린 것이 많습니다. 이 저장소를 만들 때
> 참고한 `hangle.c` 도 그랬습니다 — 예제 코드값까지 틀려서, 주석에 "한"이라고 적힌 `0xB463` 을
> 풀면 ㅇ+ㅏ+ㄲ, 즉 `앆` 입니다. 숫자는 전부 `PUTHAN.PAS` 쪽을 따랐고, 아래 `proof.py` 로 검산했습니다.

## 폰트 파일

### 16x16 (11,520바이트)

```
초성 8벌 x 20자 x 32바이트 = 5,120      0x0000~
중성 4벌 x 22자 x 32바이트 = 2,816      0x1400~
종성 4벌 x 28자 x 32바이트 = 3,584      0x1F00~
```

### 8x8 (560바이트)

```
초성 1벌 x 20자 x 8바이트 = 160         0x000~
중성 1벌 x 22자 x 8바이트 = 176         0x0A0~
종성 1벌 x 28자 x 8바이트 = 224         0x150~
```

두 경우 다 벌 안에서 자모가 **폰트 번호** 순서로 늘어서는데, 이 번호는 조합형 코드값과 다릅니다.
코드값에 빈 자리가 있기 때문입니다 (중성은 8, 9, 16, 17… 자리가 비고, 종성은 18 자리가 빕니다).
`TbCho` / `TbJung` / `TbJong` 이 그 변환표이고, 두 롬이 이것을 똑같이 씁니다.

개미체 원본은 도스 한글 라이브러리 한라프로3 의 FNT 그릇(16x16 을 담는 2x1x2벌, 3,616바이트)에
8x8 을 왼쪽 위로 몰아 그린 파일입니다. `tools/johab.py` 의 `build_font8()` 이
**16x16 칸의 행 1~8, 왼쪽 바이트만** 뽑아내고, 개미체에 없는 채움 자리에 빈 8바이트를 끼워 넣어
560바이트 폰트를 만듭니다. (그릇은 2벌이지만 두 벌이 똑같이 그려져 있습니다 — `proof.py` 가 확인합니다.)

### 넣어 둔 것

| 파일 | 크기 | 출처와 라이선스 |
|---|---|---|
| `gaemi7x8.fnt` | 7x8 **(8x8 판 기본)** | 개미체 1.0, 2012, 홍기정. **AGPL v3** |
| `gaemi8x8.fnt` | 8x8 | 개미체 1.0, 2012, 홍기정. **AGPL v3** |
| `hangul16.fnt` | 16x16 **(16x16 판 기본)** | SDLHan 0.5 의 `h_soft.han`. 패키지는 GPL v2, 폰트 원저작자 불명 |
| `gothic16.fnt` | 16x16 | `hangul11` 의 `HANG.FNT` (1990). 라이선스 불명 |

바꾸려면 `HANGUL_FONT=assets/gothic16.fnt ./build.sh 16`,
`GAEMI_FONT=assets/gaemi8x8.fnt ./build.sh 8` 처럼 부르면 됩니다.

`gaemi8x8` 은 글자가 8칸을 꽉 채워서 옆 글자와 붙습니다. `gaemi7x8` 은 7칸만 써서
8픽셀 간격 안에 1픽셀 틈이 남으므로 이쪽을 기본으로 했습니다.

> **저장소 코드는 MIT 지만 폰트는 아닙니다.** 특히 개미체는 **AGPL v3** 이고 글꼴 예외 조항이
> 없습니다. 16x16 두 벌은 권리 관계가 확인되지 않았습니다. 재배포하시기 전에
> [`NOTICE.md`](NOTICE.md) 를 읽어 주세요.

## 롬 안의 배치

| | `hangul.rom` | `hangul8.rom` |
|---|---:|---:|
| 카트리지 헤더 | 16 | 16 |
| 코드 | 633 | 540 |
| 코드값 표 (`Tb*`) | 96 | 96 |
| 벌 표 + 벌별 주소 | 138 | **0** |
| 화면 자료 + 낱개 그림 | 273 | 416 |
| 폰트 | 11,520 | 560 |
| **합계 (16,384 중)** | **12,676** | **1,628** |

한 글자를 찍는 데 드는 것은 표를 서너 번 보고, 자모를 겹치고, 1bpp 를 4bpp 로 펼쳐
VRAM 에 넣는 정도입니다.

## 파일

```
src/hangul.asm      16x16 판 본체
src/hangul8.asm     8x8 판 본체. 위와 나란히 놓고 보면 벌 대목만 빠져 있다
src/hantext*.asm    화면 자료 (mkdata.py 가 만든다. 손대지 말 것)
tools/johab.py      조합형 표, 파이썬 합성 루틴, 개미체 뽑아내기
tools/mkdata.py     화면 정의 -> 롬 자료 + 기대 화면 그림
tools/compare.py    에뮬레이터 화면 vs 기대 화면
tools/proof.py      표와 폰트가 맞는지 스스로 확인한다 (아래)
assets/*.fnt        조합형 폰트
```

화면에 나올 글은 `tools/mkdata.py` 의 `SCREENS` 를 고치면 됩니다. 유니코드 한글을 그대로 쓰면
조합형 코드로 바꿔서 구워 줍니다. `x` 에 `None` 을 주면 가운데로 맞춰 주고, 줄이 화면을 넘으면
빌드가 멈춥니다.

## 어셈블리를 짜기 전에 확인한 것

```bash
python3 tools/proof.py
```

```
어셈블리 표    : 통과 (파일 2개, 표 11개, 298칸)
왕복 검사      : 통과
gaemi7x8.fnt   : 1x1x1벌 맞고, 뽑아낸 8x8 폰트 560바이트
gaemi8x8.fnt   : 1x1x1벌 맞고, 뽑아낸 8x8 폰트 560바이트
gothic16.fnt   : 11172자 중 통째 OR 과 PUTHAN 방식이 다른 글자 0개
hangul16.fnt   : 11172자 중 통째 OR 과 PUTHAN 방식이 다른 글자 0개
```

네 가지를 확인합니다.

1. **자모 셋을 통째로 OR 해도 되는가.** `PUTHAN.PAS` 는 받침이 있을 때 0~10행, 8~10행, 11~15행으로
   나눠 덮어쓰는데, 한글 11,172자를 두 방식으로 합성해 비교해 보면 결과가 **한 바이트도 다르지 않습니다**.
   받침 있는 벌의 초성/중성이 아래쪽을 이미 비워 두기 때문입니다. 그래서 Z80 쪽은 단순한 통째 OR 로 짰습니다.
2. **유니코드 -> 조합형 -> 폰트 번호 왕복.** 정방향 표와 역방향 표를 서로 대 봅니다.
   종성 코드값 18 자리가 비어 있어서 여기가 어긋나기 쉽습니다.
3. **어셈블리에 손으로 옮겨 적은 표가 파이썬 표와 같은가.** 두 `.asm` 의 `db` 줄을 그대로 읽어
   한 칸씩 비교합니다. 화면에 안 나오는 자모까지 전부 덮습니다. 8x8 판에 벌 표가 남아 있으면 그것도 잡습니다.
4. **개미체를 그릇에서 제대로 뽑아냈는가.** 2벌짜리 무리의 두 벌이 정말 같은지(1x1x1벌인지),
   글자가 16x16 칸의 행 1~8 · 열 0~7 안에만 있는지 확인합니다.

## Z80 쪽에서 조심한 것

* **그리는 동안 화면을 꺼 둡니다.** 켜 놓고 쓰면 VRAM 쓰기 간격을 29 T-state 이상 벌려야 합니다.
  한 번 그리고 마는 화면에서 그럴 이유가 없습니다. 그래도 `otir`(바이트당 21 T-state)로 내보내
  화면이 꺼진 상태의 간격을 지킵니다.
* **R#14.** SCREEN 5 페이지 0 은 27,136바이트라 y 가 128 을 넘으면 주소가 `0x4000` 을 지납니다.
  위쪽 두 비트를 R#14 에 넣지 않으면 화면 아래쪽이 엉뚱한 데로 갑니다.
* **x 는 늘 짝수.** 4bpp 라 한 바이트가 두 픽셀입니다. 16픽셀(또는 8픽셀) 간격으로만 나아가므로
  x 가 짝수로 남고, 덕분에 바이트 경계에 딱 맞아 시프트가 한 번도 필요 없습니다.
* **`ExpandTbl` 은 페이지 시작에.** `ExpandByte` 가 상위 바이트만 넣고 E 로 색인합니다.
  주석으로 두면 RAM 배치를 옮길 때 조용히 깨지므로 `assert (ExpandTbl & 0xFF) == 0` 로 못박아 두었습니다.
* **한 벌의 자모 수가 20, 22, 28.** 2의 거듭제곱이 아니라 곱셈이 어중간합니다. 16x16 판은
  벌마다 시작 주소를 표로 적어 두고 자모 번호에 32만 곱해 더합니다. 8x8 판은 벌이 없어서
  무리 시작 주소에 번호 x 8 만 더하면 끝입니다.

## 필요한 것

**sjasmplus 1.23.1**, **openMSX** (C-BIOS_MSX2 포함), **python3** (Pillow, numpy).
앞의 둘은 저장소 밖에 두고 `tools.sh` / `tools.ps1` 에서 경로를 잡습니다.
기본값은 `../tools/` 이고, `MSX_TOOLS_ROOT` 로 바꿀 수 있습니다.

## 라이선스

소스 코드는 MIT ([LICENSE](LICENSE)). 폰트는 각자의 라이선스를 따릅니다 — [NOTICE.md](NOTICE.md).

---

**English** · [한국어](#msx2-조합형-한글-출력-예제)

# MSX2 Johab Hangul on a Cartridge

Two MSX2 cartridge ROMs. They take a two-byte **johab** (조합형) Hangul code, pull the initial,
medial and final jamo out of it five bits at a time, and **compose the glyph at runtime** by
OR-ing three jamo bitmaps together. No syllable is stored whole, so a few dozen jamo shapes
render all 11,172 Hangul syllables.

| | `hangul.rom` | `hangul8.rom` |
|---|---|---|
| Glyph size | **16x16** | **8x8** (ink is 7x8) |
| Font | 8/4/4 sets, **11,520 bytes** | 1/1/1 sets, **560 bytes** |
| Per screen | 16 x 13 cells | **32 x 26 cells** |
| Set-selection tables | required (138 bytes) | **none** |
| ROM used | 12,676 bytes | **1,628 bytes** |
| Entry point | `src/hangul.asm` | `src/hangul8.asm` |

<p align="center">
  <img src="doc/img/hangul.png" width="47%" alt="16x16 johab Hangul">
  <img src="doc/img/hangul8.png" width="47%" alt="8x8 johab Hangul">
</p>

Video mode is SCREEN 5 (GRAPHIC 4), 256x212, 16 colours. Built with sjasmplus, checked in openMSX.

## Build and verify

```bash
./build.sh          # both ROMs (append 16 or 8 for just one)
./verify.sh         # boot headless, screenshot, compare against the expected image
./run.sh            # run the 16x16 ROM in a window
./run.sh 8          # run the 8x8 ROM in a window
```

On Windows use `build.ps1` / `verify.ps1`. Tool paths live in exactly one place:
`tools.sh` (Linux), `tools.ps1` (Windows).

`verify.sh` does not stop at "sjasmplus exited 0". `tools/mkdata.py` bakes both the **ROM data**
and the **expected screen image** from a single screen definition; the emulator's screenshot is then
quantised back to the 16-colour palette and compared index by index.
Both ROMs currently match on **all 54,272 pixels**.

The Z80 side and the Python side each hold their own copy of the johab tables, and they check each
other two different ways:

| What | How | Coverage |
|---|---|---|
| Tables | `tools/proof.py` parses the `db` lines out of `src/hangul*.asm` and diffs them against the Python lists | 2 files, 11 tables, **all 298 entries** |
| Composition + blit | `tools/compare.py` diffs the emulator screenshot against the expected image | the glyphs actually on screen |

The table check exists because the glyphs on screen do not cover all 19 initials and 27 finals.
ㅋ, for instance, is the one initial that `FTbJung` special-cases, and it never appears on screen.
Corrupt that entry and the pixel comparison still passes — only `proof.py` catches it.

## What johab is

A syllable is two bytes holding three five-bit fields.

```
bit   15   14 13 12 11 10    9  8  7  6  5    4  3  2  1  0
      1    [  initial 5  ]   [  medial 5  ]   [   final 5  ]
```

`한` is initial ㅎ (20), medial ㅏ (3), final ㄴ (5), so `0xD065`.
Each field also has a dedicated **filler** value, which is how a lone jamo is written.
The `ㅎ + ㅏ + ㄴ = 한` panel at the bottom of both screens uses exactly that: the three
left-hand cells are real johab codes with the unused fields set to filler.

**Both ROMs are identical up to this point** — the same bit-slicing, and the same
code-value-to-glyph-index tables (`TbCho`/`TbJung`/`TbJong`), entry for entry.
Exactly one thing differs.

## The one hard part: jamo sets (벌)

A jamo changes shape depending on its neighbours. The ㄱ in `가` is not the ㄱ in `구`.
So a 16x16 johab font stores each jamo in several **sets**, and which set to use is decided
**crosswise**:

| Set for | Chosen by | Count |
|---|---|---|
| Initial | the **medial** (and whether there is a final) | 8 sets |
| Medial | the **initial** (and whether there is a final) | 4 sets |
| Final | the **medial** | 4 sets |

The middle row of the 16x16 screen, `가 고 구 과 궈 각 곡 곽`, is all eight sets of the initial ㄱ.
All eight are different drawings. The tables are transcribed from `PUTHAN.PAS` (1992, by Hyun
Sil-hwan) and live in `src/hangul.asm` as `FTbJung0/1`, `MTbCho0/1`, `MTbJong`.

**The 8x8 GaemiChe font has one set each**, because 8x8 leaves no room to vary a jamo's shape.
So `hangul8.asm` has none of those tables — the glyph index alone gives the address.
On that screen, the same `가고구과궈각곡곽` row shows the same ㄱ eight times.

> Many johab examples floating around get the set-selection rule wrong. The `hangle.c` consulted
> while building this repo did — its example codes are wrong too: `0xB463`, commented as "한",
> actually decodes to ㅇ+ㅏ+ㄲ, i.e. `앆`. Every number here follows `PUTHAN.PAS` instead, and is
> cross-checked by `proof.py` below.

## Font file layout

### 16x16 (11,520 bytes)

```
initials  8 sets x 20 jamo x 32 bytes = 5,120      0x0000~
medials   4 sets x 22 jamo x 32 bytes = 2,816      0x1400~
finals    4 sets x 28 jamo x 32 bytes = 3,584      0x1F00~
```

### 8x8 (560 bytes)

```
initials  1 set x 20 jamo x 8 bytes = 160          0x000~
medials   1 set x 22 jamo x 8 bytes = 176          0x0A0~
finals    1 set x 28 jamo x 8 bytes = 224          0x150~
```

In both cases the jamo inside a set are ordered by **glyph index**, which is not the same as the
johab code value — the code space has gaps (medials skip 8, 9, 16, 17…; finals skip 18).
`TbCho` / `TbJung` / `TbJong` are that mapping, and both ROMs use it identically.

GaemiChe ships in the FNT container of the DOS Hangul library HalaPro 3 — a 2x1x2-set, 16x16
format of 3,616 bytes — with the 8x8 art crammed into the top-left. `build_font8()` in
`tools/johab.py` extracts **rows 1–8, left byte only** of each 16x16 cell and inserts an empty
8 bytes where GaemiChe has no filler glyph, producing the 560-byte font. (The container holds two
sets, but both are drawn identically — `proof.py` asserts this.)

### What's bundled

| File | Size | Origin and license |
|---|---|---|
| `gaemi7x8.fnt` | 7x8 **(8x8 default)** | GaemiChe 1.0, 2012, by Hong Gi-jeong. **AGPL v3** |
| `gaemi8x8.fnt` | 8x8 | GaemiChe 1.0, 2012, by Hong Gi-jeong. **AGPL v3** |
| `hangul16.fnt` | 16x16 **(16x16 default)** | `h_soft.han` from SDLHan 0.5. Package is GPL v2; the font's own author is unknown |
| `gothic16.fnt` | 16x16 | `HANG.FNT` from `hangul11` (1990). License unknown |

To swap: `HANGUL_FONT=assets/gothic16.fnt ./build.sh 16`,
`GAEMI_FONT=assets/gaemi8x8.fnt ./build.sh 8`.

`gaemi8x8` fills all 8 columns, so adjacent syllables touch. `gaemi7x8` uses 7, leaving a 1-pixel
gap inside the 8-pixel advance — that is why it is the default.

> **The code here is MIT, but the fonts are not.** GaemiChe in particular is **AGPL v3** with no
> font exception, and the two 16x16 fonts have unverified rights. Read [`NOTICE.md`](NOTICE.md)
> before redistributing.

## ROM budget

| | `hangul.rom` | `hangul8.rom` |
|---|---:|---:|
| Cartridge header | 16 | 16 |
| Code | 633 | 540 |
| Code-value tables (`Tb*`) | 96 | 96 |
| Set tables + per-set addresses | 138 | **0** |
| Screen data + symbol glyphs | 273 | 416 |
| Font | 11,520 | 560 |
| **Total (of 16,384)** | **12,676** | **1,628** |

Drawing one syllable costs three or four table lookups, an OR of two or three jamo bitmaps, and a
1bpp-to-4bpp expansion into VRAM.

## Files

```
src/hangul.asm      the 16x16 ROM
src/hangul8.asm     the 8x8 ROM. Diff it against the above: only the set-selection part is missing
src/hantext*.asm    screen data (generated by mkdata.py — do not edit)
tools/johab.py      johab tables, the Python composer, GaemiChe extraction
tools/mkdata.py     screen definition -> ROM data + expected screen image
tools/compare.py    emulator screenshot vs expected image
tools/proof.py      self-checks on the tables and the fonts (below)
assets/*.fnt        johab fonts
```

To change what appears on screen, edit `SCREENS` in `tools/mkdata.py`. Write plain Unicode Hangul
and it is converted to johab at build time. Pass `None` for `x` to centre a line; the build stops
if a line runs off the screen.

## What was proven before any Z80 was written

```bash
python3 tools/proof.py
```

```
어셈블리 표    : 통과 (파일 2개, 표 11개, 298칸)
왕복 검사      : 통과
gaemi7x8.fnt   : 1x1x1벌 맞고, 뽑아낸 8x8 폰트 560바이트
gaemi8x8.fnt   : 1x1x1벌 맞고, 뽑아낸 8x8 폰트 560바이트
gothic16.fnt   : 11172자 중 통째 OR 과 PUTHAN 방식이 다른 글자 0개
hangul16.fnt   : 11172자 중 통째 OR 과 PUTHAN 방식이 다른 글자 0개
```

Four checks:

1. **Is a plain OR of the three jamo enough?** `PUTHAN.PAS` splits the composition into rows
   0–10, 8–10 and 11–15 when there is a final. Composing all 11,172 syllables both ways gives
   **byte-identical results**, because the with-final sets already leave the lower rows empty.
   So the Z80 side does the simple full OR.
2. **Unicode -> johab -> glyph index round-trip.** The forward and reverse tables are checked
   against each other. The gap at final code value 18 is exactly where an off-by-one would hide.
3. **Do the hand-transcribed assembly tables match the Python ones?** The `db` lines of both
   `.asm` files are parsed and diffed entry by entry, covering jamo that never appear on screen.
   It also flags a set table left behind in the 8x8 ROM.
4. **Was GaemiChe extracted correctly?** That the two stored sets really are identical
   (i.e. it is a 1/1/1-set font), and that all ink sits within rows 1–8 and columns 0–7.

## Z80 notes

* **The display stays off while drawing.** With it on, VRAM writes must be spaced at least
  29 T-states apart. There is no reason to fight that on a screen drawn once. Output still goes
  through `otir` (21 T-states per byte), which covers the display-off spacing requirement.
* **R#14.** SCREEN 5 page 0 is 27,136 bytes, so any y past 128 crosses `0x4000`. Without feeding
  the high address bits to R#14, the lower half of the screen lands in the wrong place.
* **x is always even.** At 4bpp one byte is two pixels. Advancing only in 16- (or 8-) pixel steps
  keeps x even, which keeps every glyph byte-aligned — no shifting anywhere.
* **`ExpandTbl` must be page-aligned.** `ExpandByte` loads only the high byte and indexes with E.
  Leaving that as a comment would let a RAM-map change break it silently, so
  `assert (ExpandTbl & 0xFF) == 0` pins it at assembly time.
* **Sets hold 20, 22 and 28 jamo** — not powers of two, so the multiply is awkward. The 16x16 ROM
  keeps a table of per-set start addresses and only multiplies the glyph index by 32. The 8x8 ROM
  has no sets, so it is just group start + index x 8.

## Requirements

**sjasmplus 1.23.1**, **openMSX** (with C-BIOS_MSX2), **python3** (Pillow, numpy).
The first two live outside the repo; `tools.sh` / `tools.ps1` point at them.
The default is `../tools/`, overridable with `MSX_TOOLS_ROOT`.

## License

Source code is MIT ([LICENSE](LICENSE)). The fonts are not — each carries its own license,
see [NOTICE.md](NOTICE.md).

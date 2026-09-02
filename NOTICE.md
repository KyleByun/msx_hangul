# 제3자 저작물 고지 / Third-Party Notices

이 저장소의 소스 코드는 MIT 라이선스입니다([LICENSE](LICENSE)).
아래 항목은 **MIT 가 적용되지 않습니다.** 각자의 저작권자와 라이선스를 따릅니다.

The source code in this repository is MIT licensed ([LICENSE](LICENSE)).
The items below are **not covered by MIT** and follow their own licenses.

---

## 비트맵 폰트 / Bitmap fonts (`assets/`)

### `gaemi7x8.fnt`, `gaemi8x8.fnt`

| | |
|---|---|
| 이름 / Name | 개미체 1.0 (GaemiChe) |
| 만든 이 / Author | 홍기정 (Hong Gi-jeong), 2012 |
| 라이선스 / License | **AGPL v3** |

원본은 `개미체7x8.FNT` / `개미체8x8.FNT` 이고 이름만 바꿔 넣었습니다. 내용은 바이트 그대로입니다.
`tools/johab.py` 의 `build_font8()` 이 빌드할 때 8x8 부분만 뽑아내지만, 저장소에 든 파일은 원본입니다.

> **배포하실 때 주의하세요.** AGPL v3 는 강한 카피레프트이고, 이 폰트에는 글꼴 예외 조항이 따로
> 없습니다. 개미체를 박은 롬을 배포하면 소스 공개 의무가 따라올 수 있습니다. 상업 배포를
> 생각하신다면 만드신 분께 먼저 확인하시는 편이 안전합니다.

The files are the original `개미체7x8.FNT` / `개미체8x8.FNT`, renamed but byte-identical.
`build_font8()` in `tools/johab.py` extracts the 8x8 portion at build time; the stored files are untouched.

> **Note before redistributing.** AGPL v3 is a strong copyleft and this font ships with no font
> exception clause. Shipping a ROM with GaemiChe embedded may carry a source-disclosure obligation.
> Check with the author first if you intend to distribute commercially.

### `saemmul12.fnt`, `saemmul12.txt`

| | |
|---|---|
| 원본 / Origin | 도스 샘물체 `DOSSaemmul-16.bdf` (fonts_220507 묶음) |
| 만든 이 / Author | Damheo Lee, 2016 |
| 라이선스 / License | **명시되어 있지 않음 / Not stated** (BDF 에 `COPYRIGHT "Copyright (c) 2016 Damheo Lee"` 만 있음) |

원본 BDF 는 4MB 라 넣지 않았습니다. 이 파일은 화면에 쓰는 **72자만** 16x16 에서 12x12 로 줄여
뽑아낸 것입니다(1,728바이트). 만드는 방법은 `tools/mkfont12.py` 에 있습니다.
BDF 안에 라이선스 조항이 적혀 있지 않으므로, 배포하실 것이라면 만드신 분께 확인하시는 편이 안전합니다.

The original BDF is 4 MB and is not included. This file is a **72-syllable** excerpt, shrunk from
16x16 to 12x12; see `tools/mkfont12.py`. The BDF states a copyright line but no license terms, so
check with the author before redistributing.

### `dalmoori/`

| | |
|---|---|
| 이름 / Name | 달무리 글꼴 (dalmoori) |
| 만든 이 / Author | ranolp 외 / and contributors, 2022 |
| 라이선스 / License | **Apache License 2.0** (`assets/dalmoori/LICENSE`) |
| 원본 / Upstream | https://github.com/ranolp/dalmoori-font |

`generator/glyph/` 의 `hangul-phoneme/` 와 `basic-latin/` 을 그대로 옮겼습니다.
`tools/dalmoori.py` 는 같은 저장소 `generator/src/core/` 의 조합 규칙
(`ascii-font.ts`, `hangul-phoneme.ts`, `combine.ts`)을 파이썬으로 옮긴 것입니다.

원본 조합기는 글리프 폴더를 정렬 없이 읽어서, 조건을 통과하는 후보가 여럿일 때
파일시스템 순서가 결과를 가릅니다. 이 저장소는 빌드가 재현되도록 이름 정렬 순서로
고정했으므로, 결과물이 공식 배포판과 글자별로 다를 수 있습니다.

Copied verbatim from `generator/glyph/`: `hangul-phoneme/` and `basic-latin/`.
`tools/dalmoori.py` is a Python port of the composition rules in the same repository's
`generator/src/core/` (`ascii-font.ts`, `hangul-phoneme.ts`, `combine.ts`).

Upstream's combiner reads its glyph directories unsorted, so when several candidates satisfy the
conditions the filesystem order decides. This repository fixes the order to sorted filenames for
reproducible builds, so individual glyphs may differ from the official release.

### `hangul16.fnt`

| | |
|---|---|
| 원본 / Origin | SDLHan 0.5 의 `fonts/h_soft.han` |
| 패키지 라이선스 / Package license | GPL v2 (SDLHan by ageldama) |
| 폰트 저작자 / Font author | **알 수 없음 / Unknown** |

SDLHan 의 `README.ko` 에 "fonts/에 위치한 몇 개의 폰트들의 원저작자는 모르겠습니다 (에듀넷에서 받음)"
라고 적혀 있습니다. 패키지는 GPL v2 지만 폰트 자체의 권리 관계는 확인되지 않았습니다.

SDLHan's own `README.ko` states that the original authors of the fonts in `fonts/` are unknown
(obtained from EDUNET). The package is GPL v2, but the rights to the font itself are unverified.

### `gothic16.fnt`

| | |
|---|---|
| 원본 / Origin | `hangul11` 배포판의 `HANG.FNT` (1990) |
| 라이선스 / License | **알 수 없음 / Unknown** — 1990년대 국내 셰어웨어 |

권리 관계가 확인되지 않았습니다. 시험용으로만 쓰시고, 배포물에 넣지 마세요.

Rights are unverified. Use for testing only; do not include in anything you distribute.

---

## 자료표 / Data tables

`src/hangul.asm`, `src/hangul8.asm`, `tools/johab.py` 의 조합형 변환표
(`TbCho`/`TbJung`/`TbJong`, `FTbJung*`, `MTb*`) 는 **`PUTHAN.PAS` (1992, 현실환)** 에서
옮긴 것입니다. 1990년대 국내에 배포된 터보 파스칼 한글 라이브러리의 일부입니다.

The johab conversion tables in `src/hangul.asm`, `src/hangul8.asm` and `tools/johab.py`
(`TbCho`/`TbJung`/`TbJong`, `FTbJung*`, `MTb*`) are transcribed from **`PUTHAN.PAS` (1992,
by Hyun Sil-hwan)**, part of a Turbo Pascal Hangul library distributed in Korea in the 1990s.

## 코드 / Code

`BuildExpand` 루틴은 같은 저자의 MSX 프로젝트 `quest` 의 `src/questtext.asm` 에서 가져왔습니다.

The `BuildExpand` routine is taken from `src/questtext.asm` in the author's own MSX project `quest`.

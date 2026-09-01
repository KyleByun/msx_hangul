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

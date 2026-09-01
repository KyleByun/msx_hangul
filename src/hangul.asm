;-----------------------------------------------------------------------------
; MSX2 조합형 한글 출력 예제
;
; 0x4000 에 매핑되는 16KB 카트리지 롬. 매퍼도 슬롯 전환도 없다.
; 화면은 SCREEN 5 (GRAPHIC 4), 256x212, 16색.
;
; 한 글자를 통째로 그려 두지 않는다. 두 바이트짜리 조합형 코드에서 초성,
; 중성, 종성을 다섯 비트씩 뽑아, 폰트에서 자모 셋을 골라 실행 중에 겹친다.
; 한글 11172자를 자모 70벌(11520바이트)로 낸다.
;
;   비트 15  14 13 12 11 10   9  8  7  6  5   4  3  2  1  0
;        1   [   초성 5    ]  [   중성 5   ]  [   종성 5   ]
;
; 자모는 이웃에 따라 모양이 바뀌므로 폰트가 같은 자모를 '벌'별로 여러 벌
; 담고 있다. 어느 벌을 쓸지는 서로 엇갈려서 정해진다 - 이것이 조합형
; 출력의 핵심이고, 참고한 hangle.c 가 틀린 곳이기도 하다.
;
;        초성의 벌 <- 중성이 정한다
;        중성의 벌 <- 초성이 정한다
;        종성의 벌 <- 중성이 정한다
;
; 표는 hangul11/PUTHAN.PAS (1992, 현실환) 에서 옮겼다.
;
; 그리는 동안에는 화면을 꺼 둔다. 켜 놓고 쓰면 VRAM 쓰기 간격을 29 T-state
; 이상으로 벌려야 하는데, 한 번 그리고 마는 화면에서 그럴 이유가 없다.
;
; 빌드: ./build.sh   확인: ./verify.sh
;-----------------------------------------------------------------------------

    DEVICE NOSLOT64K

;--- VDP 입출력 포트 -----------------------------------------------------------
VDP_DATA    equ 0x98
VDP_ADDR    equ 0x99

;--- 화면 ----------------------------------------------------------------------
SCR_W_BYTES equ 128                 ; 256픽셀 / 바이트당 2픽셀
SCR_LINES   equ 212
BG_COLOUR   equ 4                   ; 바탕 - 어두운 파랑

;--- 폰트 배치 -----------------------------------------------------------------
; 자모 하나가 16x16 = 32바이트다. 초성은 여덟 벌, 중성과 종성은 네 벌씩
; 들어 있고, 벌 안에서 자모가 폰트 번호 순으로 늘어선다.
CHO_ORG     equ 0                   ; 초성 8벌 x 20자
CHO_SET     equ 20 * 32             ; 한 벌의 크기
JUNG_ORG    equ CHO_ORG  + 8 * CHO_SET      ; 중성 4벌 x 22자
JUNG_SET    equ 22 * 32
JONG_ORG    equ JUNG_ORG + 4 * JUNG_SET     ; 종성 4벌 x 28자
JONG_SET    equ 28 * 32
FONT_SIZE   equ JONG_ORG + 4 * JONG_SET     ; = 11520

;--- 작업용 RAM (페이지 3 는 어느 MSX 에서나 RAM 이다) --------------------------
; ExpandTbl 은 반드시 페이지 시작(하위 바이트 0)에 둔다. ExpandByte 가
; 상위 바이트만 넣고 색인해 쓴다.
ExpandTbl   equ 0xC000              ; 니블 -> 화면 두 바이트, 16 x 2
Compose     equ 0xC020              ; 합성한 16x16 한 글자, 32바이트
RowBuf      equ 0xC040              ; 펼친 화면 한 줄, 8바이트
TextFg      equ 0xC048
TextBg      equ 0xC049
FillByte    equ 0xC04A
CurX        equ 0xC04B
CurY        equ 0xC04C
Count       equ 0xC04D
FCho        equ 0xC04E              ; 자모의 폰트 번호
FJung       equ 0xC04F
FJong       equ 0xC050
BCho        equ 0xC051              ; 자모가 쓸 벌
BJung       equ 0xC052
BJong       equ 0xC053
GlyphPtr    equ 0xC054              ; word
VramPtr     equ 0xC056              ; word
RowLo       equ 0xC058
RowHi       equ 0xC059

    ; ExpandByte 가 상위 바이트만 넣고 E 로 색인하므로, 표가 페이지 시작에
    ; 있지 않으면 엉뚱한 곳을 읽는다. 주석 대신 여기서 못박아 둔다.
    assert (ExpandTbl & 0xFF) == 0

STACK_TOP   equ 0xF380              ; 위쪽은 BIOS 작업 영역이다

    ORG 0x4000

;-----------------------------------------------------------------------------
; 카트리지 롬 헤더
;-----------------------------------------------------------------------------
    db "AB"                         ; 롬 식별자
    dw Init                         ; INIT - 부팅할 때 불린다
    dw 0                            ; STATEMENT
    dw 0                            ; DEVICE
    dw 0                            ; TEXT
    ds 6, 0

;-----------------------------------------------------------------------------
; 진입점
;-----------------------------------------------------------------------------
Init:
    di                              ; 인터럽트 없이 폴링만 쓴다
    ld sp, STACK_TOP

    call InitScreen5                ; 이 시점에는 화면이 꺼져 있다

    ld a, BG_COLOUR                 ; 바탕을 한 번 지우고
    ld d, 0
    ld e, SCR_LINES
    call FillLines

    call DrawBands                  ; 띠를 깔고
    call DrawText                   ; 그 위에 글자를 얹는다

    ld a, 0x40                      ; R#1 - 이제 화면을 켠다
    ld c, 1
    call WriteVdpReg

Stop:
    jr Stop                         ; 한 번 그리면 끝이다

;-----------------------------------------------------------------------------
; InitScreen5 - VDP 레지스터 R#0..R#23 을 쓴다
;-----------------------------------------------------------------------------
InitScreen5:
    ld hl, Screen5Regs
    ld c, 0                         ; 레지스터 번호
    ld b, Screen5RegsEnd - Screen5Regs
.loop:
    ld a, (hl)
    inc hl
    out (VDP_ADDR), a               ; 값을 먼저 쓰고...
    ld a, c
    or 0x80                         ; ...그다음 0x80 | 레지스터 번호
    out (VDP_ADDR), a
    inc c
    djnz .loop
    ret

Screen5Regs:
    db 0x06                         ; R#0  M5=0 M4=1 M3=1 -> GRAPHIC 4
    db 0x00                         ; R#1  화면 끔. 다 그린 뒤에 켠다
    db 0x1F                         ; R#2  비트맵 시작 = 0x00000 (페이지 0)
    db 0xFF                         ; R#3  (G4 에서는 미사용)
    db 0x03                         ; R#4  (G4 에서는 미사용)
    db 0xEF                         ; R#5  스프라이트 속성 (안 쓴다)
    db 0x0F                         ; R#6  스프라이트 패턴 (안 쓴다)
    db 0x00                         ; R#7  테두리 색
    db 0x0A                         ; R#8  VR=1 (VRAM 64Kx8), SPD=1 스프라이트 끔
    db 0x80                         ; R#9  LN=1 -> 212라인
    db 0x00                         ; R#10
    db 0x00                         ; R#11
    db 0x00                         ; R#12
    db 0x00                         ; R#13
    db 0x00                         ; R#14 VRAM 주소 A16-A14
    db 0x00                         ; R#15 상태 레지스터 선택 = S#0
    db 0x00                         ; R#16
    db 0x00                         ; R#17
    db 0x00                         ; R#18
    db 0x00                         ; R#19
    db 0x00                         ; R#20
    db 0x00                         ; R#21
    db 0x00                         ; R#22
    db 0x00                         ; R#23 수직 스크롤
Screen5RegsEnd:

;-----------------------------------------------------------------------------
; FillLines - 가로 한 줄을 통째로 칠한다
; A = 색, D = 시작 y, E = 라인 수
;
; 한 줄이 꼭 128바이트라 여러 줄이 VRAM 에서 이어져 있다. 주소 카운터가
; 알아서 올라가므로 주소는 처음 한 번만 준다.
;-----------------------------------------------------------------------------
FillLines:
    and 0x0F
    ld b, a
    rlca
    rlca
    rlca
    rlca
    or b                            ; 한 바이트에 같은 색 두 픽셀
    ld (FillByte), a

    ld l, d
    ld h, 0
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl                      ; y * 128
    call SetVramWrite

    ld a, (FillByte)
.line:
    ld b, SCR_W_BYTES               ; 128 -> djnz 가 128번 돈다
.byte:
    out (VDP_DATA), a
    djnz .byte
    dec e
    jr nz, .line
    ret

;-----------------------------------------------------------------------------
; DrawBands - 글자 뒤에 깔 색 띠들
;-----------------------------------------------------------------------------
DrawBands:
    ld hl, BandList
.next:
    ld a, (hl)
    cp 0xFF
    ret z
    ld d, a                         ; y
    inc hl
    ld e, (hl)                      ; 라인 수
    inc hl
    ld a, (hl)                      ; 색
    inc hl
    push hl
    call FillLines
    pop hl
    jr .next

;-----------------------------------------------------------------------------
; DrawText - 글줄 목록을 훑어 한 칸씩 찍는다
;-----------------------------------------------------------------------------
DrawText:
    ld hl, TextList
.line:
    ld a, (hl)
    cp 0xFF
    ret z
    ld (CurY), a
    inc hl
    ld a, (hl)
    ld (CurX), a
    inc hl
    ld a, (hl)
    ld (TextFg), a
    inc hl
    ld a, (hl)
    ld (TextBg), a
    inc hl
    ld a, (hl)
    ld (Count), a
    inc hl

    push hl
    call BuildExpand                ; 색이 바뀌었으니 니블 표를 다시 만든다
    pop hl

.cell:
    ld e, (hl)                      ; 코드 두 바이트
    inc hl
    ld d, (hl)
    inc hl
    push hl

    ld a, (CurX)
    ld b, a
    ld a, (CurY)
    ld c, a
    call PutCell

    ld a, (CurX)
    add a, 16                       ; 한 칸이 16픽셀. x 는 짝수로 남는다
    ld (CurX), a

    pop hl
    ld a, (Count)
    dec a
    ld (Count), a
    jr nz, .cell
    jr .line

;-----------------------------------------------------------------------------
; PutCell - 한 칸 찍기. DE = 코드, B = x(짝수), C = y
;
; 조합형 코드는 언제나 비트 15 가 1이다. 0 이면 조합형이 아니라 SymbolGlyphs
; 안의 낱개 그림 번호로 본다 ('+', '=', 빈칸).
;-----------------------------------------------------------------------------
PutCell:
    ld a, d
    and 0x80
    jr z, .symbol

    push bc
    call ComposeHan
    pop bc
    ld hl, Compose
    jp BlitGlyph

.symbol:
    ld l, e
    ld h, 0
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl                      ; 번호 * 32
    ld de, SymbolGlyphs
    add hl, de
    jp BlitGlyph

;-----------------------------------------------------------------------------
; ComposeHan - 조합형 코드 DE 를 Compose 32바이트로 합성한다
;-----------------------------------------------------------------------------
ComposeHan:
    ; --- 다섯 비트씩 셋으로 자른다 ---
    ld a, d
    srl a
    srl a
    and 0x1F                        ; 초성 = (코드 >> 10) & 31
    ld (FCho), a

    ld a, d
    and 0x03
    rlca
    rlca
    rlca                            ; 중성 위쪽 두 비트
    ld b, a
    ld a, e
    rlca
    rlca
    rlca
    and 0x07                        ; 중성 아래쪽 세 비트
    or b
    ld (FJung), a                   ; 중성 = (코드 >> 5) & 31

    ld a, e
    and 0x1F                        ; 종성 = 코드 & 31
    ld (FJong), a

    ; --- 코드값을 폰트 안의 자모 번호로 바꾼다 ---
    ; 조합형 코드값에는 빈 자리가 있어서 번호가 이어지지 않는다.
    ld hl, TbCho
    ld a, (FCho)
    call Lookup
    ld (FCho), a
    ld hl, TbJung
    ld a, (FJung)
    call Lookup
    ld (FJung), a
    ld hl, TbJong
    ld a, (FJong)
    call Lookup
    ld (FJong), a

    ; --- 벌을 고른다 (초성 <- 중성, 중성 <- 초성, 종성 <- 중성) ---
    ld a, (FJong)
    or a                            ; 받침이 있나
    ld hl, MTbCho0                  ; 없을 때 쓰는 두 표
    ld de, FTbJung0
    jr z, .sel
    ld hl, MTbCho1                  ; 있을 때 쓰는 두 표
    ld de, FTbJung1
.sel:
    push de
    ld a, (FJung)
    call Lookup                     ; 초성의 벌은 중성이 정한다
    ld (BCho), a
    pop hl
    ld a, (FCho)
    call Lookup                     ; 중성의 벌은 초성이 정한다
    ld (BJung), a
    ld hl, MTbJong
    ld a, (FJung)
    call Lookup                     ; 종성의 벌도 중성이 정한다
    ld (BJong), a

    ; --- 자모 셋을 겹친다 ---
    ld a, (FCho)
    ld c, a
    ld a, (BCho)
    ld hl, ChoBase
    call GlyphAddr
    ld de, Compose
    ld bc, 32
    ldir                            ; 초성을 깔고

    ld a, (FJung)
    ld c, a
    ld a, (BJung)
    ld hl, JungBase
    call GlyphAddr
    call OrCompose                  ; 중성을 겹치고

    ld a, (FJong)
    or a
    ret z                           ; 받침이 없으면 여기서 끝
    ld c, a
    ld a, (BJong)
    ld hl, JongBase
    call GlyphAddr
                                    ; 종성까지 겹친다 (아래로 이어짐)

; HL 의 자모 비트맵 32바이트를 Compose 에 OR 한다
OrCompose:
    ld de, Compose
    ld b, 32
.loop:
    ld a, (de)
    or (hl)
    ld (de), a
    inc hl
    inc de
    djnz .loop
    ret

;-----------------------------------------------------------------------------
; Lookup - A = (HL + A). 표는 전부 256바이트 안에 들어간다.
;-----------------------------------------------------------------------------
Lookup:
    ld e, a
    ld d, 0
    add hl, de
    ld a, (hl)
    ret

;-----------------------------------------------------------------------------
; GlyphAddr - 자모 비트맵의 주소
; A = 벌, C = 자모 번호, HL = 벌별 시작 주소표  ->  HL = 비트맵 주소
;
; 한 벌에 든 자모 수가 20, 22, 28 이라 곱셈이 어중간하다. 벌마다 시작
; 주소를 미리 표로 적어 두고, 자모 번호에 32만 곱해 더한다.
;-----------------------------------------------------------------------------
GlyphAddr:
    add a, a
    ld e, a
    ld d, 0
    add hl, de
    ld e, (hl)
    inc hl
    ld d, (hl)                      ; DE = 이 벌의 첫 자모
    ld l, c
    ld h, 0
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl                      ; 자모 번호 * 32
    add hl, de
    ret

;-----------------------------------------------------------------------------
; BlitGlyph - 16x16 1bpp 비트맵을 화면에 찍는다
; HL = 비트맵 32바이트, B = x(짝수), C = y
;
; 화면은 4bpp 라 한 바이트에 두 픽셀이 든다. 가로 16픽셀 = 8바이트인데,
; x 가 짝수라 언제나 바이트 경계에 딱 맞는다 - 시프트가 한 번도 없다.
;-----------------------------------------------------------------------------
BlitGlyph:
    ld (GlyphPtr), hl

    ld l, c                         ; 주소 = y * 128 + x / 2
    ld h, 0
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    ld a, b
    srl a
    add a, l
    ld l, a
    jr nc, .noinc
    inc h
.noinc:
    ld (VramPtr), hl

    ld b, 16                        ; 열여섯 줄
.row:
    push bc

    ld hl, (VramPtr)
    call SetVramWrite               ; 줄마다 주소를 새로 준다
    ld de, SCR_W_BYTES
    add hl, de
    ld (VramPtr), hl

    ld hl, (GlyphPtr)
    ld a, (hl)
    ld (RowLo), a                   ; 왼쪽 여덟 픽셀
    inc hl
    ld a, (hl)
    ld (RowHi), a                   ; 오른쪽 여덟 픽셀
    inc hl
    ld (GlyphPtr), hl

    ld hl, RowBuf
    ld a, (RowLo)
    call ExpandByte
    ld a, (RowHi)
    call ExpandByte

    ld hl, RowBuf                   ; otir 는 바이트당 21 T-state 라
    ld bc, 8 * 256 + VDP_DATA       ; 화면이 꺼진 동안의 VRAM 간격을 채운다
    otir

    pop bc
    djnz .row
    ret

;-----------------------------------------------------------------------------
; ExpandByte - 1bpp 여덟 픽셀을 화면 네 바이트로 펼친다
; A = 픽셀 여덟 개, HL = 쓸 곳. HL 은 네 칸 나아간다.
;-----------------------------------------------------------------------------
ExpandByte:
    ld c, a
    rrca
    rrca
    rrca
    rrca
    call .nibble                    ; 왼쪽 네 픽셀 먼저
    ld a, c                         ; 오른쪽 네 픽셀 (아래로 이어짐)
.nibble:
    and 0x0F
    add a, a
    ld e, a
    ld d, ExpandTbl >> 8            ; 표가 페이지 시작에 있어서 이렇게 된다
    ld a, (de)
    ld (hl), a
    inc hl
    inc e
    ld a, (de)
    ld (hl), a
    inc hl
    ret

;-----------------------------------------------------------------------------
; BuildExpand - 니블 하나(픽셀 넷)를 화면 두 바이트로 바꾸는 표를 만든다
; (TextFg, TextBg) 를 보고 채운다. 표는 32바이트고 색이 바뀔 때만 다시 만든다.
; quest 프로젝트 src/questtext.asm 의 같은 이름 루틴을 그대로 가져왔다.
;-----------------------------------------------------------------------------
BuildExpand:
    ld hl, ExpandTbl
    ld c, 0                         ; 니블 값 0~15
.nib:
    ld a, c
    rlca
    rlca
    rlca
    rlca                            ; 니블을 상위로 올려 rlca 로 왼쪽부터 꺼낸다
    ld e, a
    ld b, 2                         ; 바이트 둘
.byte:
    push bc
    ld d, 0
    ld b, 2                         ; 한 바이트에 픽셀 둘
.px:
    sla d
    sla d
    sla d
    sla d                           ; 앞서 넣은 픽셀을 상위 니블로 민다
    ld a, e
    rlca                            ; 다음 픽셀 비트를 캐리로
    ld e, a
    jr nc, .off
    ld a, (TextFg)
    jr .put
.off:
    ld a, (TextBg)
.put:
    or d
    ld d, a
    djnz .px
    ld (hl), d
    inc hl
    pop bc
    djnz .byte
    inc c
    ld a, c
    cp 16
    jr nz, .nib
    ret

;-----------------------------------------------------------------------------
; SetVramWrite - VDP 를 VRAM 주소 HL 의 쓰기 모드로 맞춘다
; HL 은 보존, A 와 C 는 부순다.
;
; SCREEN 5 페이지 0 은 27136바이트라 y 가 128 을 넘으면 주소가 0x4000 을
; 지난다. R#14 에 위쪽 비트를 넣지 않으면 화면 아래쪽이 엉뚱한 데로 간다.
;-----------------------------------------------------------------------------
SetVramWrite:
    ld a, h
    rlca
    rlca
    and 0x03                        ; A15, A14
    ld c, 14
    call WriteVdpReg
    ld a, l
    out (VDP_ADDR), a               ; A7-A0
    ld a, h
    and 0x3F
    or 0x40                         ; A13-A8 과 쓰기 비트
    out (VDP_ADDR), a
    ret

;-----------------------------------------------------------------------------
; WriteVdpReg - VDP 레지스터 C 에 A 를 쓴다
;-----------------------------------------------------------------------------
WriteVdpReg:
    out (VDP_ADDR), a
    ld a, c
    or 0x80
    out (VDP_ADDR), a
    ret

;=============================================================================
; 조합형 표 - hangul11/PUTHAN.PAS (1992, 현실환)
;=============================================================================

;--- 코드값(0~31) -> 폰트 안의 자모 번호. 빈 자리는 0(채움)이다 ----------------
TbCho:
    db 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14
    db 15,16,17,18,19, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
TbJung:
    db 0, 0, 0, 1, 2, 3, 4, 5, 0, 0, 6, 7, 8, 9,10,11
    db 0, 0,12,13,14,15,16,17, 0, 0,18,19,20,21, 0, 0
TbJong:
    db 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14
    db 15,16, 0,17,18,19,20,21,22,23,24,25,26,27, 0, 0

;--- 초성 번호(0~19) -> 중성이 쓸 벌 (PUTHAN 의 FTb) ---------------------------
; ㄱ, ㅋ 처럼 오른쪽이 트인 초성 뒤에서는 중성이 다른 벌로 바뀐다.
FTbJung0:                           ; 받침 없을 때
    db 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1
FTbJung1:                           ; 받침 있을 때
    db 0, 2, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 2, 3, 3, 3

;--- 중성 번호(0~21) -> 종성/초성이 쓸 벌 (PUTHAN 의 MTb) ----------------------
MTbJong:                            ; 종성의 벌
    db 0, 0, 2, 0, 2, 1, 2, 1, 2, 3, 0, 2, 1, 3, 3, 1, 2, 1, 3, 3, 1, 1
MTbCho0:                            ; 받침 없을 때 초성의 벌
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 3, 3, 3, 1, 2, 4, 4, 4, 2, 1, 3, 0
MTbCho1:                            ; 받침 있을 때 초성의 벌
    db 0, 5, 5, 5, 5, 5, 5, 5, 5, 6, 7, 7, 7, 6, 6, 7, 7, 7, 6, 6, 7, 5

;--- 벌별 첫 자모의 주소 -------------------------------------------------------
ChoBase:
    dw HanFont + CHO_ORG  + 0 * CHO_SET,  HanFont + CHO_ORG  + 1 * CHO_SET
    dw HanFont + CHO_ORG  + 2 * CHO_SET,  HanFont + CHO_ORG  + 3 * CHO_SET
    dw HanFont + CHO_ORG  + 4 * CHO_SET,  HanFont + CHO_ORG  + 5 * CHO_SET
    dw HanFont + CHO_ORG  + 6 * CHO_SET,  HanFont + CHO_ORG  + 7 * CHO_SET
JungBase:
    dw HanFont + JUNG_ORG + 0 * JUNG_SET, HanFont + JUNG_ORG + 1 * JUNG_SET
    dw HanFont + JUNG_ORG + 2 * JUNG_SET, HanFont + JUNG_ORG + 3 * JUNG_SET
JongBase:
    dw HanFont + JONG_ORG + 0 * JONG_SET, HanFont + JONG_ORG + 1 * JONG_SET
    dw HanFont + JONG_ORG + 2 * JONG_SET, HanFont + JONG_ORG + 3 * JONG_SET

;=============================================================================
; 화면에 찍을 것 - tools/mkdata.py 가 만든다
;=============================================================================
    include "src/hantext.asm"

;=============================================================================
; 조합형 폰트
;=============================================================================
HanFont:
    incbin "build/hanfont.bin"
HanFontEnd:

    assert HanFontEnd - HanFont == FONT_SIZE
    assert $ <= 0x8000

; 경로는 현재 작업 디렉터리 기준이다. build.sh 가 어셈블러를 부르기 전에
; 프로젝트 뿌리로 옮겨 준다.
    SAVEBIN "build/hangul.rom", 0x4000, 0x4000

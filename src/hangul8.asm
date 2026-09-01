;-----------------------------------------------------------------------------
; MSX2 조합형 한글 출력 예제 - 8x8 판 (개미체)
;
; src/hangul.asm 의 16x16 판과 짝을 이룬다. 조합형 코드를 다섯 비트씩 셋으로
; 자르고 자모 셋을 겹치는 것까지 똑같고, 다른 것은 두 가지뿐이다.
;
;   1. 개미체는 벌이 하나씩(1x1x1벌)이다. 자모의 모양이 이웃에 따라 바뀌지
;      않으므로 벌을 고르는 표(FTb, MTb)와 벌별 주소표가 통째로 없어진다.
;      코드값 -> 자모 번호 표(Tb*)만 16x16 판과 똑같이 남는다.
;   2. 자모 하나가 8x8 = 8바이트다. 폰트 전체가 560바이트뿐이라
;      16x16 판(11,520바이트)의 스무 분의 일이다.
;
;   초성 20자 x 8바이트 = 160     0x000~
;   중성 22자 x 8바이트 = 176     0x0A0~
;   종성 28자 x 8바이트 = 224     0x150~
;
; 자모 번호 0번은 '채움'이다. 개미체에는 채움 글리프가 없어서
; tools/johab.py 의 build_font8 이 빈 8바이트를 끼워 넣는다.
;
; 한 칸이 8픽셀이라 한 줄에 서른두 글자가 들어간다. 게임 대사 상자에 쓸
; 만한 크기다.
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
CELL        equ 8                   ; 한 칸의 폭이자 높이

;--- 폰트 배치 -----------------------------------------------------------------
CHO_ORG     equ 0                   ; 초성 20자
JUNG_ORG    equ CHO_ORG  + 20 * CELL
JONG_ORG    equ JUNG_ORG + 22 * CELL
FONT_SIZE   equ JONG_ORG + 28 * CELL        ; = 560

;--- 작업용 RAM (페이지 3 는 어느 MSX 에서나 RAM 이다) --------------------------
ExpandTbl   equ 0xC000              ; 니블 -> 화면 두 바이트, 16 x 2
Compose     equ 0xC020              ; 합성한 8x8 한 글자, 8바이트
RowBuf      equ 0xC028              ; 펼친 화면 한 줄, 4바이트
TextFg      equ 0xC02C
TextBg      equ 0xC02D
FillByte    equ 0xC02E
CurX        equ 0xC02F
CurY        equ 0xC030
Count       equ 0xC031
FCho        equ 0xC032              ; 자모의 폰트 번호
FJung       equ 0xC033
FJong       equ 0xC034
GlyphPtr    equ 0xC035              ; word
VramPtr     equ 0xC037              ; word

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
    add a, CELL                     ; 한 칸이 8픽셀. x 는 짝수로 남는다
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
    ld a, e
    ld hl, SymbolGlyphs
    call GlyphAddr                  ; 번호 * 8
    jp BlitGlyph

;-----------------------------------------------------------------------------
; ComposeHan - 조합형 코드 DE 를 Compose 8바이트로 합성한다
;
; 16x16 판과 견주면 벌을 고르는 대목이 통째로 없다. 개미체는 자모마다
; 그림이 하나뿐이라, 번호만 알면 바로 주소가 나온다.
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

    ; --- 자모 셋을 겹친다 ---
    ld a, (FCho)
    ld hl, HanFont + CHO_ORG
    call GlyphAddr
    ld de, Compose
    ld bc, CELL
    ldir                            ; 초성을 깔고

    ld a, (FJung)
    ld hl, HanFont + JUNG_ORG
    call GlyphAddr
    call OrCompose                  ; 중성을 겹치고

    ld a, (FJong)
    or a
    ret z                           ; 받침이 없으면 여기서 끝
    ld hl, HanFont + JONG_ORG
    call GlyphAddr
                                    ; 종성까지 겹친다 (아래로 이어짐)

; HL 의 자모 비트맵 8바이트를 Compose 에 OR 한다
OrCompose:
    ld de, Compose
    ld b, CELL
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
; GlyphAddr - A = 번호, HL = 무리의 시작 주소  ->  HL = 비트맵 주소
;-----------------------------------------------------------------------------
GlyphAddr:
    ld e, a
    ld d, 0
    ex de, hl                       ; HL = 번호, DE = 무리 시작
    add hl, hl
    add hl, hl
    add hl, hl                      ; 번호 * 8
    add hl, de
    ret

;-----------------------------------------------------------------------------
; BlitGlyph - 8x8 1bpp 비트맵을 화면에 찍는다
; HL = 비트맵 8바이트, B = x(짝수), C = y
;
; 화면은 4bpp 라 한 바이트에 두 픽셀이 든다. 가로 8픽셀 = 4바이트인데,
; 한 칸이 8픽셀이라 x 가 늘 짝수로 남아 바이트 경계에 딱 맞는다.
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

    ld b, CELL                      ; 여덟 줄
.row:
    push bc

    ld hl, (VramPtr)
    call SetVramWrite               ; 줄마다 주소를 새로 준다
    ld de, SCR_W_BYTES
    add hl, de
    ld (VramPtr), hl

    ld hl, (GlyphPtr)
    ld a, (hl)                      ; 이 줄의 여덟 픽셀
    inc hl
    ld (GlyphPtr), hl

    ld hl, RowBuf
    call ExpandByte

    ld hl, RowBuf                   ; otir 는 바이트당 21 T-state 라
    ld bc, 4 * 256 + VDP_DATA       ; 화면이 꺼진 동안의 VRAM 간격을 채운다
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
; 코드값(0~31) -> 폰트 안의 자모 번호. 빈 자리는 0(채움)이다.
; 16x16 판(src/hangul.asm)의 같은 이름 표와 한 칸도 다르지 않다.
; tools/proof.py 가 두 파일을 모두 읽어 파이썬 표와 대 본다.
;=============================================================================
TbCho:
    db 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14
    db 15,16,17,18,19, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
TbJung:
    db 0, 0, 0, 1, 2, 3, 4, 5, 0, 0, 6, 7, 8, 9,10,11
    db 0, 0,12,13,14,15,16,17, 0, 0,18,19,20,21, 0, 0
TbJong:
    db 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14
    db 15,16, 0,17,18,19,20,21,22,23,24,25,26,27, 0, 0

;=============================================================================
; 화면에 찍을 것 - tools/mkdata.py 가 만든다
;=============================================================================
    include "src/hantext8.asm"

;=============================================================================
; 조합형 폰트 (8x8, 벌 하나씩)
;=============================================================================
HanFont:
    incbin "build/hanfont8.bin"
HanFontEnd:

    assert HanFontEnd - HanFont == FONT_SIZE
    assert $ <= 0x8000

; 경로는 현재 작업 디렉터리 기준이다. build.sh 가 어셈블러를 부르기 전에
; 프로젝트 뿌리로 옮겨 준다.
    SAVEBIN "build/hangul8.rom", 0x4000, 0x4000

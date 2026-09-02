;-----------------------------------------------------------------------------
; MSX2 완성형 부분집합 한글 출력 예제 - 12x12
;
; src/hangul.asm (16x16) 및 src/hangul8.asm (8x8) 과 짝을 이루지만, 방식이
; 반대다. 저 둘은 조합형이라 자모를 실행 중에 겹쳐서 11,172자를 다 낸다.
; 여기서는 겹치지 않는다. 글자를 통째로 갖되 **쓰는 글자만** 갖는다.
;
; 왜 그러냐면 - 글자를 12x12 로 줄이면 자모를 겹칠 자리가 모자란다. 16x16
; 조합형 폰트를 12x12 로 줄여서 겹쳐 보면 한글 11,172자 중 2,301자가 서로
; 구별되지 않는다 (녹, 뇩, 늑 이 같은 그림이 된다). 8x8 개미체가 성립하는
; 것은 애초에 그 크기에 맞춰 손으로 그렸기 때문이다.
;
; 게임 대사는 빌드할 때 이미 정해져 있으므로, 쓰는 글자만 담으면 된다.
; 이 롬은 서로 다른 글자 일흔두 자를 쓴다. 한 자에 24바이트니 1,728바이트다.
;
; 그래서 이 롬에는 조합형 표가 하나도 없다. 글줄에 적힌 값이 곧 폰트 안의
; 글리프 번호이고, 번호에 24를 곱하면 바로 주소다.
;
; 폰트는 tools/mkfont12.py 가 16x16 완성형 BDF(도스 샘물체)에서 12x12 로
; 줄여 뽑는다. 어느 폰트를 줄이느냐가 크게 갈리는데, 같은 조건에서 서로
; 구별 안 되는 글자가 샘물체는 94자(0.8%), 고딕체는 2,635자(23.6%) 생긴다.
;
; 화면은 SCREEN 5, 한 칸 12픽셀이라 한 줄에 스물한 자가 들어간다.
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
CELL        equ 12                  ; 한 칸의 폭이자 높이
GLYPH_SIZE  equ CELL * 2            ; 한 줄이 12비트지만 2바이트에 담는다
ROW_BYTES   equ 6                   ; 12픽셀 = 화면 6바이트 (4bpp)

;--- 작업용 RAM (페이지 3 는 어느 MSX 에서나 RAM 이다) --------------------------
ExpandTbl   equ 0xC000              ; 니블 -> 화면 두 바이트, 16 x 2
RowBuf      equ 0xC020              ; 펼친 화면 한 줄, 6바이트
TextFg      equ 0xC026
TextBg      equ 0xC027
FillByte    equ 0xC028
CurX        equ 0xC029
CurY        equ 0xC02A
Count       equ 0xC02B
GlyphPtr    equ 0xC02C              ; word
VramPtr     equ 0xC02E              ; word
RowLo       equ 0xC030
RowHi       equ 0xC031

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
    ld e, (hl)                      ; 글리프 번호 두 바이트
    inc hl
    ld d, (hl)
    inc hl
    push hl

    ld a, (CurX)
    ld b, a
    ld a, (CurY)
    ld c, a
    push bc
    call GlyphAddr                  ; DE = 번호 -> HL = 비트맵 주소
    pop bc
    call BlitGlyph

    ld a, (CurX)
    add a, CELL                     ; 한 칸이 12픽셀. x 는 짝수로 남는다
    ld (CurX), a

    pop hl
    ld a, (Count)
    dec a
    ld (Count), a
    jr nz, .cell
    jr .line

;-----------------------------------------------------------------------------
; GlyphAddr - DE = 글리프 번호  ->  HL = 비트맵 주소
;
; 조합형 판과 견주면 이 한 줄이 표 여섯 번 보던 자리를 대신한다.
; 한 자가 24바이트라 번호에 8을 곱한 뒤 세 배 한다.
;-----------------------------------------------------------------------------
GlyphAddr:
    ld h, d
    ld l, e
    add hl, hl
    add hl, hl
    add hl, hl                      ; 번호 * 8
    ld d, h
    ld e, l
    add hl, hl                      ; 번호 * 16
    add hl, de                      ; 번호 * 24
    ld de, HanFont
    add hl, de
    ret

;-----------------------------------------------------------------------------
; BlitGlyph - 12x12 1bpp 비트맵을 화면에 찍는다
; HL = 비트맵 24바이트, B = x(짝수), C = y
;
; 한 줄이 2바이트지만 쓰는 것은 위쪽 12비트뿐이다. 화면은 4bpp 라
; 12픽셀 = 6바이트다. 한 칸이 12픽셀이라 x 가 늘 짝수로 남아
; 바이트 경계에 딱 맞는다.
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

    ld b, CELL                      ; 열두 줄
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
    ld (RowHi), a                   ; 위쪽 니블이 나머지 네 픽셀
    inc hl
    ld (GlyphPtr), hl

    ld hl, RowBuf
    ld a, (RowLo)
    call ExpandByte                 ; 여덟 픽셀 -> 네 바이트
    ld a, (RowHi)
    rrca
    rrca
    rrca
    rrca
    call ExpandByte.nibble          ; 남은 네 픽셀 -> 두 바이트

    ld hl, RowBuf                   ; otir 는 바이트당 21 T-state 라
    ld bc, ROW_BYTES * 256 + VDP_DATA   ; 화면이 꺼진 동안의 VRAM 간격을 채운다
    otir

    pop bc
    djnz .row
    ret

;-----------------------------------------------------------------------------
; ExpandByte - 1bpp 여덟 픽셀을 화면 네 바이트로 펼친다
; A = 픽셀 여덟 개, HL = 쓸 곳. HL 은 네 칸 나아간다.
; .nibble 로 들어오면 아래 니블 네 픽셀만 두 바이트로 펼친다.
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
; 화면에 찍을 것 - tools/mkdata.py 가 만든다
; (조합형 표가 없다. 값이 곧 글리프 번호다.)
;=============================================================================
    include "src/hantext12.asm"

;=============================================================================
; 12x12 완성형 부분집합 폰트
;=============================================================================
HanFont:
    incbin "build/hanfont12.bin"
HanFontEnd:

    assert HanFontEnd - HanFont == GLYPH_COUNT * GLYPH_SIZE
    assert $ <= 0x8000

; 경로는 현재 작업 디렉터리 기준이다. build.sh 가 어셈블러를 부르기 전에
; 프로젝트 뿌리로 옮겨 준다.
    SAVEBIN "build/hangul12.rom", 0x4000, 0x4000

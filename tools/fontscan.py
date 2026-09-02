#!/usr/bin/env python3
"""어느 폰트를 어느 크기로 줄일지 정할 때 쓴 잣대.

한글 11,172자를 전부 만들어 보고, **서로 구별되지 않는 글자가 몇 자인가**를 센다.
비트맵이 똑같아지면 읽는 사람도 구별할 수 없다. 필요조건이지 충분조건은 아니지만,
'눈으로 보니 괜찮더라' 보다는 훨씬 낫다. 몇 글자만 보고 고르면 틀린다.

이 잣대로 얻은 결론:

  달무리 8x8 (8x8 전용으로 그린 것, 자리마다 변형)      0자 (0.0%)
  개미체 8x8 (손으로 그린 것, 벌 하나씩)               0자 (0.0%)
  16x16 조합형 폰트를 자모째 12x12 로 줄여 겹치기   2,301자 (20.6%)   <- 못 쓴다
  DOSSaemmul 완성형 16x16 -> 12x12                     94자 (0.8%)   <- 쓴다
  DOSGothic  완성형 16x16 -> 12x12                  2,635자 (23.6%)
  DOSSaemmul 완성형 16x16 -> 14x14                      0자 (0.0%)

손으로 그 크기에 맞춰 그린 글꼴만 8x8 에서 성립한다. 줄여서 만든 것은 전부 실패한다.
달무리와 개미체는 둘 다 충돌 0이지만 달무리가 훨씬 또렷하다 - 자모가 자리에 맞춰
바뀌기 때문이다(개미체는 벌이 하나씩이라 안 바뀐다).

원본 BDF 가 있어야 돌아간다 (4MB 라 저장소에 없다).
    python3 tools/fontscan.py --bdf ~/다운로드/hangul/fonts_220507/bdf/DOSSaemmul-16.bdf
"""
import argparse, collections, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import johab as J, wanseong

SYL = [chr(u) for u in range(0xAC00, 0xD7A4)]

def count(bitmaps, label):
    d = collections.defaultdict(list)
    for ch, b in zip(SYL, bitmaps):
        d[bytes(b)].append(ch)
    dup = [v for v in d.values() if len(v) > 1]
    n = sum(len(v) for v in dup)
    ex = ' '.join(''.join(v[:3]) for v in sorted(dup, key=lambda v: -len(v))[:3])
    print("  %-42s %5d자 (%4.1f%%)  %s" % (label, n, 100.0 * n / len(SYL), ex))
    return n

def scan_johab():
    print("조합형 폰트 (자모를 겹쳐서 만든다)")
    for name in ('hangul16', 'gothic16'):
        f = open('assets/%s.fnt' % name, 'rb').read()
        count([J.compose(f, J.johab(c)) for c in SYL], "%s 16x16 원본" % name)
    for name in ('gaemi7x8', 'gaemi8x8'):
        f = J.build_font8('assets/%s.fnt' % name)
        count([J.compose8(f, J.johab(c)) for c in SYL], "%s 8x8 (손으로 그린 것)" % name)
    if os.path.isdir('assets/dalmoori'):
        import dalmoori
        dm = dalmoori.Font('assets/dalmoori')
        count([dm.bitmap(c) for c in SYL], "달무리 8x8 (빌드할 때 조합)")

def scan_shrunk_johab(n):
    """16x16 조합형 폰트의 자모를 낱개로 줄여서 겹치면 어떻게 되나."""
    for name in ('hangul16', 'gothic16'):
        f = open('assets/%s.fnt' % name, 'rb').read()
        tab = {}
        for org, per, sets, cnt in ((J.OFF_CHO, J.N_CHO, 8, J.N_CHO),
                                    (J.OFF_JUNG, J.N_JUNG, 4, J.N_JUNG),
                                    (J.OFF_JONG, J.N_JONG, 4, J.N_JONG)):
            for b in range(sets):
                for i in range(cnt):
                    p = org + (b * per + i) * 32
                    g = [[bool(((f[p+r*2] << 8) | f[p+r*2+1]) & (0x8000 >> c)) for c in range(16)]
                         for r in range(16)]
                    tab[(org, b, i)] = wanseong.shrink(g, n)
        out = []
        for ch in SYL:
            cho, jung, jong = J.decompose(J.johab(ch))
            has = 1 if jong else 0
            ps = [tab[(J.OFF_CHO, J.MTB[2][jung] if has else J.MTB[1][jung], cho)],
                  tab[(J.OFF_JUNG, J.FTB[has][cho], jung)]]
            if has: ps.append(tab[(J.OFF_JONG, J.MTB[0][jung], jong)])
            out.append(wanseong.pack([[any(p[y][x] for p in ps) for x in range(n)] for y in range(n)]))
        count(out, "%s 자모를 %dx%d 로 줄여 겹치기" % (name, n, n))

def scan_bdf(path, sizes):
    ent, ascent = wanseong.load_bdf(path, SYL)
    grids = {c: wanseong.to_grid(ent[ord(c)], ascent) for c in SYL if ord(c) in ent}
    count([wanseong.pack(grids[c]) for c in SYL], "%s 16x16 원본" % os.path.basename(path))
    for n in sizes:
        count([wanseong.pack(wanseong.shrink(grids[c], n)) for c in SYL],
              "%s -> %dx%d" % (os.path.basename(path), n, n))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--bdf', nargs='*', default=[],
                    help="16x16 완성형 BDF. 없으면 조합형 쪽만 잰다.")
    ap.add_argument('--sizes', type=int, nargs='*', default=[12, 14])
    a = ap.parse_args()
    scan_johab()
    print("\n조합형 폰트를 줄여서 겹치면 (12x12 롬에서 쓰지 않기로 한 방식)")
    for n in a.sizes:
        scan_shrunk_johab(n)
    if a.bdf:
        print("\n완성형 폰트를 줄이면 (12x12 롬이 쓰는 방식)")
        for p in a.bdf:
            scan_bdf(p, a.sizes)
    else:
        print("\n완성형 쪽은 --bdf 로 원본을 줘야 잽니다 (4MB 라 저장소에 없습니다).")

if __name__ == '__main__':
    main()

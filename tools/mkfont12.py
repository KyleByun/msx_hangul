#!/usr/bin/env python3
"""16x16 완성형 BDF 에서 12x12 부분집합 폰트를 뽑는다.

화면에 쓰는 글자가 바뀌었을 때만 돌리면 된다. 원본 BDF 는 4MB 라 저장소에
넣지 않았으므로, 이 스크립트를 돌리려면 원본이 있어야 한다.

    python3 tools/mkfont12.py --bdf ~/다운로드/hangul/fonts_220507/bdf/DOSSaemmul-16.bdf

샘물체를 쓰는 이유는 tools/proof.py 의 충돌 검사 결과다. 16x16 을 12x12 로
줄일 때 한글 11,172자 중 서로 구별 안 되는 글자가
샘물체는 94자(0.8%), 고딕체는 2,635자(23.6%) 생긴다.
"""
import argparse, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wanseong, mkdata

DEFAULT_BDF = os.path.expanduser('~/다운로드/hangul/fonts_220507/bdf/DOSSaemmul-16.bdf')

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--bdf', default=os.environ.get('SAEMMUL_BDF', DEFAULT_BDF))
    ap.add_argument('--out', default='assets/saemmul12')
    a = ap.parse_args()
    if not os.path.exists(a.bdf):
        sys.exit("원본 BDF 를 찾을 수 없다: %s\n"
                 "  --bdf 로 경로를 주거나 SAEMMUL_BDF 환경변수를 쓰세요." % a.bdf)

    chars = mkdata.used_chars(mkdata.SCREENS[12])
    syls = sorted(set(chars))
    font, index, base = wanseong.build_subset(a.bdf, chars)
    wanseong.save_subset(a.out, font, sorted(index, key=index.get))
    print("%s -> %s.fnt (%d자, %d바이트) + %s.txt"
          % (os.path.basename(a.bdf), a.out, base, len(font), a.out))

if __name__ == '__main__':
    main()

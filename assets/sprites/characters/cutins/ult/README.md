# 오의 컷인 그림 (#544, #546, #549)

`<id>/<id>_ult.tres` — 오의 풀 연출에서 재생하는 **LD(편성 초상 그림체) 공격 애니메이션**. 원화 24장
(`<id>/<id>_ult_00.webp` ~ `_23.webp`)의 SpriteFrames 이고, 짧게 모드는 마지막 장(결정 포즈)을 잘라 쓴다.

- `tools/build_ultimate_frames.py` 가 만든다. 원본·제작 경위: [art/ultimate-ld](../../../../../art/ultimate-ld/README.md)
- 애니메이션이 없으면 `char_<id>_ult.png`(전용 정지 일러스트, 사양: docs/ultimate-cutin-art-spec.md),
  그것도 없으면 전투 프레임 공격 컷(SD)으로 떨어진다.

> 상위 폴더의 `char_<id>_cutin.png`(2400×1350)는 #544 부터 쓰지 않는다.

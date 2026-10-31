# 검열판(전체이용가) 그림 (#586)

`assets/` 와 **같은 상대 경로·같은 파일 이름**으로 둔다. 검열판 빌드에서만 원본 대신 쓰인다.

```
assets/sprites/characters/portraits/mina.png
assets_censored/sprites/characters/portraits/mina.png            <- 검열판 초상
assets_censored/sprites/characters/cutins/ult/mina/mina_ult.tres <- 검열판 궁극기 (24장과 함께)
```

- 짝이 없는 파일은 검열판에서도 원본을 쓴다. 한 장씩 넣어도 된다.
- 초상은 원본과 **같은 픽셀 크기·같은 머리 위치**로 둔다(`data/portraits/portrait_meta.tres` 를 같이 쓴다).
- 궁극기는 원화 24장 폴더를 `python tools/build_ultimate_frames.py <id> <폴더> --censored` 로 넣는다.
- 넣은 뒤 `godot --headless --path . --import` — `.import` 도 함께 커밋한다.
- 확인: `godot --headless --path . res://tests/edition/VerifyGameEdition.tscn -- --censored`
  (마지막 줄에 아직 검열판 그림이 없는 목록이 나온다)

원화 프롬프트: [docs/censored-art-prompts.md](../docs/censored-art-prompts.md) ·
릴리스 절차: [docs/release-editions.md](../docs/release-editions.md)

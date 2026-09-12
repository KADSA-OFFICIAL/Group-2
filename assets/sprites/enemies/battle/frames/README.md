# battle/frames

턴제 전투 프레임 시트의 **낱장 프레임**을 두는 곳.

```
<유닛id>/<동작>_<번호>.png      예: harang/attack_0.png
```

동작은 `idle` · `attack` · `hit` · `death` 넷뿐이다. 재생 경로가 있는 것만 그린다.

조립:

```bash
godot --headless --path . --script tools/build_battle_frames.gd
```

`<유닛id>.tres`(`SpriteFrames`)가 나오면 그 캐릭터 `.tres` 의 `battle_frames` 에 넣는다.

규격과 생성 프롬프트: [docs/battle-animation-prompts.md](../../../../docs/battle-animation-prompts.md)
규약 정본: `entities/combat/turn/BattleAnimation.gd`

**한 장짜리 시트를 두지 않는다.** 생성 도구가 격자를 못 맞춰 인물이 셀 안에서 흘러간다
(`tools/normalize_walk_sheet.gd` 머리말). 낱장은 그 문제가 없다.

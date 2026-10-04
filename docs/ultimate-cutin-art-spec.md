# 오의 컷인 일러스트 사양 · 프롬프트 (#544)

> **#546 에서 방향이 바뀌었다.** 컷인 캐릭터는 SD 정지 일러스트가 아니라 **LD(편성 초상 그림체) 2D 공격
> 애니메이션**을 쓴다. 현행 산출물·제작 경위는 [art/ultimate-ld](../art/ultimate-ld/README.md),
> 24장 원화 제작 프롬프트(#549)는 [ultimate-ld-animation-prompts.md](ultimate-ld-animation-prompts.md) 를 본다.
> 아래는 #544 당시의 SD 정지 일러스트 사양으로, 기록으로 남긴다.

오의(궁극기) 연출에 들어갈 **캐릭터 6명의 컷인 일러스트**를 새로 받기 위한 사양서다.
생성 도구는 이 저장소를 읽지 못하므로, 각 프롬프트는 필요한 규칙을 전부 담은 **자기 완결형**이다.

| 대상 | 정본 |
|---|---|
| 그림체 · 의상 · 정체성 | 전투 프레임 `assets/sprites/characters/battle/frames/<id>/` (#533 리스타일) |
| 연출 구도 · 타이밍 | `stage/turn/UltimateCutin.gd` 머리말 |
| 파일 경로 규칙 | `UITheme.ultimate_cutin_path()` |
| 원소색 | `TurnCombat.element_color()` — **그림에 넣지 않는다**(아래 §2) |

---

## 0. 왜 새로 받나

예전 컷인 4장(`cutins/char_<id>_cutin.png`, 2400×1350)은 **성숙한 등신·무거운 채색**이라
지금 전투 화면의 캐릭터(약 5등신, 깔끔한 셀 채색, 귀여운 인상)와 **다른 사람처럼 보였다.**
아린·강지는 컷인이 없어 편성 초상(또 다른 그림체)으로 대체됐다.

#544 부터 전투는 그림체가 같은 것만 쓴다:

1. `assets/sprites/characters/cutins/ult/char_<id>_ult.png` 가 있으면 그것
2. 없으면 **전투 스프라이트의 공격 프레임**을 크게 키워 쓴다(지금 상태)

**파일을 1번 경로에 넣으면 코드·데이터 수정 없이 바로 교체된다.** 6명을 한꺼번에 받을 필요 없이
한 명씩 넣어도 된다.

---

## 1. 그림체 — 전투 프레임과 같은 사람으로 보여야 한다

- **같은 캐릭터 디자인**: 머리 모양·색, 눈 색, 의상, 무기, 꼬리·날개·지느러미 같은 수인 특징을
  전투 프레임과 똑같이. 의상을 바꾸거나 노출을 늘리지 않는다.
- **등신**: 전신이면 약 5~5.5등신. 컷인은 상반신~허벅지 위주라 실제로는 얼굴이 크게 보인다.
  성인 비율(7등신)·과장된 몸매로 그리지 않는다.
- **채색**: 깔끔한 애니메이션 셀 채색, 가는 갈색~회갈색 외곽선, 2~3단 명암, 부드러운 파스텔 톤.
  유화·하드 렌더링·광택 피부·과한 블룸을 쓰지 않는다.
- **표정**: 캐릭터 성격이 드러나는 결정적 순간(아래 §4).

## 2. 규격

| 항목 | 값 |
|---|---|
| 캔버스 | **1600 × 2000 px** (세로 4:5), PNG RGBA |
| 배경 | **완전 투명**. 바닥 그림자·배경 이펙트·글자 없음 |
| 인물 | 캔버스 높이를 꽉 채운다. 아래(허벅지·무릎)는 잘려도 된다. 머리 꼭대기는 위에서 4~10% |
| 시선·자세 | 3/4 정면, 몸은 **화면 왼쪽**(타이포 쪽)으로 비스듬히. 무기·손이 왼쪽 앞으로 뻗어 나오면 좋다 |
| 조명 | **중립 흰 조명.** 원소색 빛·테두리 발광을 굽지 않는다 — 연출이 코드로 입힌다(같은 그림을 속성이 바뀌어도 쓴다) |
| 무기 이펙트 | 무기 자체의 질감(얼음 결정, 불꽃 문양, 빛나는 구슬)은 그려도 되지만, 화면을 덮는 대형 이펙트는 그리지 않는다 |
| 외곽 | 반투명 경계는 1~2px 만. 흰 테두리(스티커 효과)를 넣지 않는다 |

연출에서의 쓰임: 화면 오른쪽 55~70% 자리에 화면 높이의 약 110% 크기로 서고, 잔상 두 겹과
원소색 사선 판이 뒤에 깔린다. 왼쪽 40%에는 기술명 타이포가 온다 — 그래서 인물이 왼쪽으로
너무 넘어오지 않게 **캔버스 중심보다 약간 오른쪽**에 무게를 둔다.

## 3. 넣는 법

1. `assets/sprites/characters/cutins/ult/char_<id>_ult.png` 로 저장 (`<id>`: arin, gangji, harang, mina, seola, taehee)
2. `godot --headless --path . --import` — `.import` 파일이 생긴다. **`.import` 도 함께 커밋한다**
3. `godot --headless --path . res://tests/combat/VerifyDedicatedCutins.tscn` — 전용 그림을 쓰는지 검사한다
4. 창 모드로 같은 검사를 돌리면 `docs/art-review/missing-art/<id>-ult-cutin.png` 에 연출 한 장면이 남는다

---

## 4. 캐릭터별 프롬프트

공통 꼬리말(모든 프롬프트 끝에 붙인다):

> clean anime cel shading, thin warm-brown lineart, soft pastel palette, cute proportions (about 5 heads tall, not adult proportions), same character design as the reference sprite, modest outfit exactly as reference, neutral white lighting, no colored rim light, no background, fully transparent background, no text, no logo, no ground shadow, portrait canvas 1600x2000, character fills the height, cropped at the thighs, three-quarter view, body angled toward the left side of the frame

참조 이미지로 해당 캐릭터의 `battle/frames/<id>/idle_0.png` 와 `attack_*.png` 를 함께 준다.

### 설아 (seola) — 한기 · 버퍼 · 「절대 영도 관측」
적 전체의 인성치를 깎고, 받는 피해를 늘린다. 차분하게 전장을 "관측"하는 순간.

> A calm, cool-headed mermaid girl named Seola casting an ultimate called "Absolute Zero Observation". Very long pale ice-blue wavy hair, small fin-shaped ears, red eyes, short sleeveless white-and-blue frilled dress, blue-and-white striped mermaid tail curling at her side. She holds an ice-crystal spear diagonally across her body, the crystal tip pointing toward the lower left, her free hand extended forward with fingers spread as if freezing the air. Half-lidded focused eyes, faint confident smile. Small ice crystals forming around the spear tip only. (+ 공통 꼬리말)

### 미나 (mina) — 화염 · 탱커 · 「종언의 화로」
적 전체를 불길로 밀어내고 아군을 지킨다. 방패를 앞세워 돌진하는 순간.

> An energetic, cheerful girl named Mina with small bat wings and a short dragon tail, casting an ultimate called "Furnace of the End". Blonde hair in a side ponytail with a red bow, purple eyes, white short-sleeved school shirt, red necktie, red pleated skirt, loose cream leg warmers, brown loafers. She thrusts her large cream round shield with a flame emblem forward toward the lower left, the other hand raising a short wooden baton. Big determined grin, one fang showing, wings flared. The flame emblem on the shield glows softly. (+ 공통 꼬리말)

### 태희 (taehee) — 침식 · 원거리 딜러 · 「완성된 초상」
쌓아 둔 속박을 한꺼번에 터뜨린다. 낮게 웅크렸다 튀어 나가는 순간.

> A quiet, menacing shark-girl named Taehee casting an ultimate called "Completed Portrait". Long white hair in two low twin tails, red eyes, a gray scarf with a white shark-teeth pattern covering her mouth, black sleeveless dress, dark gray shark tail, gray clawed gauntlets, holding two curved dark blades with violet edges. Low crouching lunge toward the lower left, blades crossed in front of her chest, eyes narrowed and glinting above the scarf. (+ 공통 꼬리말)

### 하랑 (harang) — 충격 · 탱커 · 「해일의 일격」
적 전체를 한 번에 내려친다. 대검을 머리 위로 휘두르는 순간.

> A cheerful, sleepy-eyed dinosaur girl named Harang casting an ultimate called "Strike of the Tidal Wave". Mint-green hair in two small buns, yellow eyes, green-and-white zip-up jacket, denim overall shorts, green dinosaur tail with yellow spikes, loose white socks, green rubber boots. She swings an oversized steel greatsword from over her shoulder, the blade sweeping across the frame toward the lower left. Mouth open in a battle shout, eyes wide. (+ 공통 꼬리말)

### 아린 (arin) — 전격 · 원거리 딜러 겸 탱커 · 「낙뢰 처형」
단일 대상에게 벼락을 떨어뜨려 처형한다. 석궁으로 조준을 끝낸 순간.

> A composed girl named Arin casting an ultimate called "Thunderbolt Execution". Short blonde bob with a hair clip, golden eyes, oversized cream cable-knit cardigan over a white top, brown shorts, small cream shoulder bag, loose white socks, white sneakers. She aims a crossbow with purple lightning motifs straight toward the viewer and slightly left, one eye closed, steady and focused. Thin crackles of electricity run along the crossbow string only. (+ 공통 꼬리말)

### 강지 (gangji) — 광휘 · 버퍼(회복) · 「여명의 각인」
아군 전체를 회복하고 힘을 북돋는다. 지팡이를 높이 드는 순간.

> A gentle, warm girl named Gangji casting an ultimate called "Seal of Dawn". Light brown short hair with a small green leaf clip, amber eyes, long cream cardigan with brown ribbon ties, green knit top, brown pleated skirt, brown lace-up boots, a brown satchel. She raises a wooden staff topped with a glowing yellow orb high above her head with both hands, body leaning slightly left, soft kind smile with eyes gently closed. The orb glows softly; no large light rays. (+ 공통 꼬리말)

---

## 5. 검수 체크리스트

- [ ] 전투 프레임 옆에 두었을 때 **같은 사람**으로 보이는가(머리·눈·의상·무기·수인 특징)
- [ ] 성인 비율·노출 증가·과한 렌더링이 없는가
- [ ] 1600×2000, 투명 배경, 글자·그림자·원소색 테두리 없음
- [ ] 머리 꼭대기가 위 4~10%, 인물 무게가 캔버스 중심보다 약간 오른쪽
- [ ] `VerifyDedicatedCutins` 통과, 창 모드 장면 확인

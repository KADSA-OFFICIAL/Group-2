# 오의 LD 공격 애니메이션 — 24장 원화 제작 프롬프트 (#549)

오의 풀 연출(#544)의 캐릭터 애니메이션을 **독립 원화 24장**으로 만든다.
#546 의 클립은 원화 6장 사이를 로컬 합성으로 이은 것이라 동작이 6단계로 끊기고(원화가 바뀌는 장에서
화면이 통째로 바뀐다), 마지막 0.9초가 완전히 멈춰 있었다. 24장이면 장마다 실제로 그린 동작이 이어진다.

- **도구**: ChatGPT 이미지 생성(이미지 첨부 가능). 영상 생성 도구로 뽑을 때는 [부록 A](#부록-a-영상-생성아스트라-프롬프트).
- **한 캐릭터는 한 대화 안에서 끝낸다.** 대화를 새로 열면 그림체·의상이 어긋난다.
- 생성 도구는 이 저장소를 읽지 못하므로 각 프롬프트는 자기 완결형이다.
- 아린·강지는 #548 의 새 초상이 들어온 뒤에 뽑는다(강지는 2026-10-04 반영됨, 아린은 대기).

---

## 1. 규격

| 항목 | 값 |
|---|---|
| 장 수 | **24장** (00 ~ 23) |
| 캔버스 | 1024×1536 세로, 장마다 같은 캔버스 |
| 그림체 | LD(편성 초상) — 약 7등신, 초상과 같은 선·채색 |
| 배경 | 단색 크로마키. 설아·미나·태희·아린 `#00FF00`, 하랑·강지 `#FF00FF` |
| 발 기준선 | 두 발바닥을 y≈1490 에 둔다(점프 동작이 아니면). 도구가 장마다 가장 낮은 점을 맞추지만, 원화에서 맞을수록 깨끗하다 |
| 크기 | 머리 크기·키가 24장 내내 같다. **장마다 인물이 커지거나 작아지면 다시 뽑는다**(#546 강지는 기도 컷만 작았다) |
| 방향 | 공격은 **화면 왼쪽 아래**로 — 컷인에서 캐릭터는 오른쪽에 서고 기술명이 왼쪽에 있다 |
| 이펙트 | 무기에 붙은 작은 이펙트만. 큰 화면 이펙트는 게임이 원소색으로 얹는다 |
| 금지 | 모션 블러·스미어, 팔다리 중복, 뒤돌아선 몸(#546 하랑 젖힘 컷), 의상·무기 모양 변화 |

### 장 구성과 타이밍 (1배속 3초)

키 6장을 먼저 그리고, 사이 18장을 이웃한 두 장을 붙여 채운다. 게임은 장마다 아래 길이(1/24초 단위)로 넘긴다.
`tools/build_ultimate_frames.py` 의 기본 타이밍표이고, 캐릭터마다 바꾸려면 `art/ultimate-ld/timing/<id>.json`.

| 장 | 박자 | 길이 | 비고 |
|---|---|---|---|
| **00** | **K0 준비** — 무기를 쥐고 선 자세 | 3 | 초상 자세에 가깝게 |
| 01 · 02 · 03 | 준비 → 예비 동작 | 3 · 3 · 3 | |
| **04** | **K1 예비 동작** — 웅크리기·힘 모으기·무기 끌어당기기 | 3 | |
| 05 · 06 · 07 | 예비 → 최대 젖힘 | 3 · 3 · 3 | 머리카락·옷자락이 몸보다 늦게 따라온다 |
| **08** | **K2 최대 젖힘** — 가장 크게 뒤로 젖히거나 들어 올린 순간 | 2 | |
| 09 · 10 | 휘두르기 시작 | 2 · 2 | 빠르게. 몸이 먼저, 무기가 뒤따른다 |
| **11** | **K3 공격 정점** — 무기가 왼쪽 아래 끝에 닿는 순간 | 2 | **기술명 타이포가 이 장에서 박힌다** |
| 12 · 13 | 지나침(오버슈트) | 2 · 2 | 무기가 정점보다 조금 더 나간다 |
| 14 · 15 | 반동 | 2 · 2 | |
| **16** | **K4 여운** — 무기를 거두며 몸을 세우기 시작 | 3 | |
| 17 ~ 21 | 여운 → 결정 포즈 | 3씩 | 머리카락·꼬리·리본이 늦게 가라앉는다 |
| 22 | 결정 포즈 들어가기 | 4 | 23 과 거의 같고 머리카락만 조금 덜 가라앉음 |
| **23** | **K5 결정 포즈** — 컷인이 끝날 때까지 보이는 그림 | 10 | 짧게 모드의 정지 그림도 이 장 |

---

## 2. 공통 머리말 — 모든 장의 프롬프트 맨 앞에 붙인다

`{NAME}`, `{NN}`, `{KEY}` 를 바꿔 넣는다(`{KEY}` = `pure green #00FF00` / `pure magenta #FF00FF`).

```
ANIMATION FRAME {NN} of 24 (00-23) for {NAME}'s ultimate attack. Draw exactly ONE full-body
image of the same character, not a sheet, not a comparison.
FRAME LOCK: vertical 1024x1536 canvas. Same character, same scale and same camera as every
attached frame of this animation: identical head size and body proportions (about 7 heads tall,
as in the reference portrait), soles of both feet on the same ground line at y=1490, whole
weapon and hair inside the canvas with margin. Do NOT shrink, enlarge, move up or crop the
character to fit the pose.
STYLE: the exact illustration style of the reference portrait - same lineart, same cel shading,
same face, eyes, hair, outfit and accessories. The character always faces the viewer or three-
quarter toward screen left; never show her back.
BACKGROUND: flat solid {KEY}, perfectly uniform. No gradient, floor, cast shadow, scenery, text,
border or frame number. Nothing in {KEY} color on the character.
EFFECTS: no motion blur, no smear, no speed lines, no duplicate limbs, no large effects; only the
small effect named for this frame, attached to the weapon.
```

---

## 3. 순서

### STEP 1 — 키 6장 (00 → 04 → 08 → 11 → 16 → 23)

| 키 | 첨부 |
|---|---|
| 00 | 초상(`assets/sprites/characters/portraits/<id>.png`) + 무기 참조(`assets/sprites/characters/battle/frames/<id>/attack_2.png`) |
| 04 · 08 · 11 · 16 · 23 | 승인한 **00** + 바로 앞 키 |

프롬프트 = 공통 머리말 + `KEY POSE:` + 아래 캐릭터 표의 해당 칸.

### STEP 2 — 사이 18장

첨부: 이미 그린 두 장(앞 장 = Image 1, 뒷 장 = Image 2). **늘 두 장의 가운데부터** 채운다 — 생성 도구는
"정확히 중간"을 가장 잘 그린다. 순서(괄호는 첨부할 두 장):

`02(00·04) → 01(00·02) → 03(02·04) → 06(04·08) → 05(04·06) → 07(06·08) → 09(08·11) → 10(09·11) →
12(11·16) → 13(12·16) → 14(13·16) → 15(14·16) → 19(16·23) → 17(16·19) → 18(17·19) → 21(19·23) → 20(19·21) → 22(21·23)`

프롬프트 = 공통 머리말 + 아래. 캐릭터마다 장 번호·위치를 채운 완성본은 사용자 로컬 `Downloads/ultimate_24f_prompts/` 에 있다.

```
IN-BETWEEN: Image 1 is frame {A}, Image 2 is frame {B}. Draw frame {NN}, {T} of the way from
Image 1 to Image 2. Interpolate body, arms, weapon, hair and clothes between the two; do not
invent a new gesture. The body leads, the weapon follows a little behind, hair, ribbons and tail
lag behind the body (follow-through). Keep scale, ground line and weapon shape exactly as both images.
```

`{T}`: 대부분 halfway. 09 = one third, 12 = a small step(지나침), 13 = one quarter, 14·17 = one third, 22 = three quarters.
박자별 덧붙임:

| 장 | 덧붙임 |
|---|---|
| 09 · 10 | `Fast swing: the torso has already turned toward screen left, the weapon still trails behind.` |
| 12 · 13 | `Overshoot: the weapon travels slightly past the strike position, hair still flying forward.` |
| 14 · 15 | `Recoil: the body springs back a little from the overshoot, hair starts to fall.` |
| 17 ~ 22 | `Settling: almost the final pose; only hair, ribbons, tail and clothes are still settling.` |

### STEP 3 — 저장

`<id>/00.png` ~ `<id>/23.png` (예: `gangji/00.png`). 폴더째 넘겨 주면 6절대로 넣는다.

---

## 4. 캐릭터별 키 포즈

캐릭터마다 맨 앞에 `CHARACTER:` 한 줄을 붙이고, 키 장마다 해당 칸을 `KEY POSE:` 로 붙인다.

### 설아 (seola) — 한기 · 「절대 영도 관측」 · `#00FF00`

`CHARACTER: Seola, a calm elegant mermaid girl: very long straight pale ice-blue hair, small fin-shaped ears, red eyes, outfit exactly as in the reference portrait, long pale blue mermaid tail. Weapon: slender ice-crystal spear, white shaft, pale blue crystal blade.`

| 키 | KEY POSE |
|---|---|
| 00 | standing calmly, spear held upright in her right hand beside her body, frost sparkle at the spear tip |
| 04 | turning her shoulders right, spear drawn back at shoulder height, eyes narrowing, hair swinging |
| 08 | maximum draw-back: spear pulled far behind her head, body coiled, weight on the back foot, tail curled |
| 11 | STRIKE: spear thrust diagonally to the lower left at full reach, front knee bent, hair streaming back, thin frost crystals on the blade |
| 16 | spear still low-left, she rises upright, free hand lifting toward her face, hair falling |
| 23 | FINAL: spear extended low-left, free hand open beside her face, half-lidded cool eyes, faint confident smile |

### 미나 (mina) — 화염 · 「종언의 화로」 · `#00FF00`

`CHARACTER: Mina, an energetic cheerful girl: long wavy blonde hair, purple eyes, small bat wings, white shirt, red necktie, red pleated skirt, cream leg warmers, brown loafers. Weapons: large cream round shield with a red flame emblem on her left arm, short wooden baton in her right hand.`

| 키 | KEY POSE |
|---|---|
| 00 | standing with the shield on her left arm and the baton at her side, cheerful grin |
| 04 | crouching behind the shield, wings half-spread, eyes fierce above the shield rim |
| 08 | deepest brace: low stance, shoulder against the shield, wings spread wide, hair flying up |
| 11 | STRIKE: whole-body shield bash to the lower left, shield at full reach, hair whipping back, small flames on the emblem |
| 16 | pulling the shield back to her chest, standing up, baton rising |
| 23 | FINAL: shield forward to the lower left, baton raised high, big determined grin with one fang, wings flared |

### 태희 (taehee) — 침식 · 「완성된 초상」 · `#00FF00`

`CHARACTER: Taehee, a quiet menacing shark girl: long white hair in two low twin tails, red eyes, gray scarf with a white shark-teeth pattern over her mouth, black dress as in the reference portrait, dark gray shark tail, gray clawed hands. Weapons: two curved dark blades with violet edges.`

| 키 | KEY POSE |
|---|---|
| 00 | standing still, one blade in each hand hanging low, eyes calm above the scarf |
| 04 | sinking into a crouch, blades crossed behind her, twin tails lifting |
| 08 | lowest crouch, coiled like a spring, eyes glinting, tail raised high |
| 11 | STRIKE: lunging to the lower left, both blades slashing in an X at full reach, thin violet trails on the blade edges |
| 16 | lunge finished, blades returning toward her chest, twin tails swinging past |
| 23 | FINAL: low lunge, blades crossed in front of her chest, narrowed eyes |

### 하랑 (harang) — 충격 · 「해일의 일격」 · `#FF00FF`

`CHARACTER: Harang, a cheerful dinosaur girl: mint-green hair in two small buns, yellow eyes, green-and-white jacket, denim overall shorts, loose white socks, green rubber boots, green dinosaur tail with yellow spikes. Weapon: oversized steel greatsword held with both hands.`

| 키 | KEY POSE |
|---|---|
| 00 | standing with the greatsword resting on her right shoulder, grinning |
| 04 | gripping with both hands, leaning back, sword lifting off the shoulder, tail swinging for balance |
| 08 | sword raised high over her head with both hands, back arched, FACING THE VIEWER (not turned away), mouth open |
| 11 | STRIKE: huge downward arc ending at the lower left, blade at full reach, buns bouncing, small dust burst at the blade end |
| 16 | blade resting low after the hit, she straightens, tail swinging back |
| 23 | FINAL: greatsword low and forward to the lower left, feet planted wide, mouth open in a shout, eyes wide |

### 아린 (arin) — 전격 · 「낙뢰 처형」 · `#00FF00` · **#548 새 초상이 들어온 뒤**

`CHARACTER: Arin, a composed girl: short blonde bob with gold hair pins, golden eyes, oversized cream cable-knit cardigan, white V-neck top, dark mini skirt, as in the reference portrait. Weapon: crossbow with purple lightning motifs.`

| 키 | KEY POSE |
|---|---|
| 00 | holding the crossbow low in both hands, calm face |
| 04 | snapping the crossbow up toward her shoulder, cardigan sleeves swaying |
| 08 | aiming to the lower left, one eye closed, string fully drawn, body still |
| 11 | STRIKE: firing; recoil pushes her shoulder back, hair flicks, purple-white sparks along the string and limbs |
| 16 | recovering from the recoil, crossbow coming back to aim |
| 23 | FINAL: still aiming to the lower left, one eye closed, steady and focused |

### 강지 (gangji) — 광휘 · 「여명의 각인」(아군 회복) · `#FF00FF`

`CHARACTER: Gangji, a gentle kind adult woman: light brown chin-length wavy bob, green leaf hairpin and a tiny gold hairpin, olive green eyes, soft downturned eyes and a small smile; open long oversized cream cardigan with brown ribbon laces and bows on the sleeves, olive green cropped camisole, brown pleated mini skirt with black bike shorts, brown belt with a green leaf charm, brown shoulder satchel, cream slouch socks, chunky brown lace-up ankle boots - exactly as in the reference portrait. Weapon: wooden staff wrapped in green leaves and small white flowers, topped with a glowing yellow orb.`

| 키 | KEY POSE |
|---|---|
| 00 | standing with the staff held upright in her right hand, gentle smile |
| 04 | bringing the staff close to her chest with both hands, eyes closing, head bowed as if praying |
| 08 | deepest prayer: knees soft, staff hugged to her chest, cardigan and ribbons settling, orb faintly glowing |
| 11 | STRIKE (blessing): staff swept high above her head with both hands, the orb flaring bright yellow, cardigan and ribbons flying upward |
| 16 | staff still high, the glow softening, ribbons starting to fall |
| 23 | FINAL: staff raised high, body leaning slightly to screen left, eyes softly closed, gentle smile |

---

## 5. 검수

- [ ] 24장을 이어 보면 동작이 끊기지 않는가(키와 사이 장의 자세가 이어지는가)
- [ ] 얼굴·머리·의상·무기 모양이 24장 내내 같은가, 손가락 수가 맞는가
- [ ] 인물 크기가 같은가(머리 크기 비교), 두 발이 기준선에 있는가
- [ ] 정면 또는 3/4 — 뒤돌아선 장이 없는가
- [ ] 배경이 균일한 단색인가, 캐릭터에 크로마키 색이 묻지 않았는가
- [ ] 11장이 공격이 닿는 순간인가(아니면 `timing/<id>.json` 의 `strike_frame` 을 고친다)
- 초상의 노출이 있는 의상은 참조 그대로 둔다 — 프롬프트로 더하거나 바꾸지 않는다.

## 6. 넣는 법

```bash
python tools/build_ultimate_frames.py <id> <24장 폴더 또는 zip>
godot --headless --path . --editor --import --quit
godot --headless --path . res://tests/combat/VerifyDedicatedCutins.tscn
```

- 결과: `assets/sprites/characters/cutins/ult/<id>/<id>_ult_00.webp` ~ `_23.webp` + `<id>_ult.tres`(SpriteFrames).
  같은 이름으로 덮어쓰므로 코드는 고치지 않는다. 자세한 것은 [art/ultimate-ld/README.md](../art/ultimate-ld/README.md).
- 공격 정점이 11장이 아니면 `art/ultimate-ld/timing/<id>.json` 에 `{"strike_frame": n}` 을 두고 다시 돌린다.
- 영상 생성 도구로 뽑은 3초 클립(.mp4, 단색 배경)도 같은 명령으로 넣는다 — 타이밍표대로 24장을 뽑는다.

---

## 부록 A. 영상 생성(아스트라) 프롬프트

> #546 때 쓴 이미지→영상 프롬프트다. 영상 생성으로 뽑으면 6절의 명령이 3초 클립에서 24장을 뽑는다.
> 강지는 4절의 새 디자인 설명(올리브 초록 눈, 크롭 캐미솔, 웨이브 단발)으로 바꿔 쓴다.

### A1. 공통 규격

| 항목 | 값 | 이유 |
|---|---|---|
| 참조 이미지 1 | `assets/sprites/characters/portraits/<id>.png` | LD 그림체·얼굴·의상의 기준. **첫 프레임**으로 쓴다 |
| 참조 이미지 2 (도구가 허용하면) | `assets/sprites/characters/battle/frames/<id>/attack_2.png` | **초상에는 무기가 없다.** 무기 모양·색의 기준 |
| 화면비 · 해상도 | 9:16 세로, 1080×1920 이상 | 컷인 오른쪽 자리에 세로로 크게 선다 |
| 길이 · 프레임 | 3초, 24fps | 컷인 홀드 구간(약 2초)을 채우고 앞뒤 여유 |
| 배경 | **단색 크로마키**(캐릭터별 아래 표) | 배경을 깨끗이 빼야 연출 위에 얹힌다 |
| 카메라 | **완전 고정**(줌·팬·회전 없음) | 카메라가 움직이면 연출의 사선 판·타이포와 어긋난다 |
| 이펙트 | 무기에 붙은 작은 이펙트만 | 큰 화면 이펙트는 연출 코드가 원소색으로 얹는다. 크로마키 색과 겹치는 이펙트 금지 |
| 마지막 0.6초 | **결정 포즈로 거의 정지** | 컷인 홀드 동안 이 포즈가 유지된다 |

#### 동작 박자 (모든 캐릭터 공통)

| 구간 | 동작 |
|---|---|
| 0.0 ~ 0.3초 | 참조 그림 자세에서 시작 → 무기를 꺼내거나 고쳐 쥔다 |
| 0.3 ~ 0.8초 | **예비 동작**(뒤로 젖히기·웅크리기·힘 모으기) — 머리카락·옷자락이 따라 흔들린다 |
| 0.8 ~ 1.6초 | **공격의 정점** — 빠르고 시원하게. 몸 전체를 쓴 한 동작 |
| 1.6 ~ 2.4초 | 여운 — 머리카락·꼬리·옷자락이 늦게 따라와 가라앉는다 |
| 2.4 ~ 3.0초 | **결정 포즈 유지**, 숨 쉬는 정도의 미세한 움직임 |

#### 크로마키 색

캐릭터 색과 겹치지 않는 색을 고른다(초록 머리·꼬리가 있는 하랑·강지는 자홍색).

| 캐릭터 | 배경 |
|---|---|
| 설아 · 미나 · 태희 · 아린 | 순수 초록 `#00FF00` |
| 하랑 · 강지 | 순수 자홍 `#FF00FF` |

#### 공통 꼬리말 (모든 프롬프트 끝에 붙인다)

```
2D anime animation in the exact art style of the reference illustration: clean cel shading,
thin lineart, same face, same hair, same outfit, same body proportions as the reference
(tall, about 7 heads), smooth hand-drawn-like motion, hair and clothes follow through naturally.
Static locked camera, no zoom, no pan, no camera shake. Full body stays inside the frame.
Solid flat {KEY} background, perfectly uniform, no gradient, no shadow on the background,
no floor, no scenery. Only small effects attached to the weapon, no large screen effects,
nothing in {KEY} color on the character. 3 seconds, 24 fps, vertical 9:16.
The last 0.6 seconds hold the final pose almost still.
```

#### 공통 네거티브 (도구가 지원하면)

```
morphing face, changing outfit, extra fingers, extra limbs, deformed hands, weapon changing
shape, chibi proportions, camera movement, zoom, background scenery, gradient background,
floor shadow, text, logo, watermark, blur, motion smear covering the face, flickering
```

---

### A2. 캐릭터별 프롬프트

`{KEY}` 는 위 표의 배경색으로 바꿔 넣는다(`pure green #00FF00` / `pure magenta #FF00FF`).

#### 설아 (seola) — 한기 · 「절대 영도 관측」 · 배경 초록
적 전체를 얼려 약하게 만드는 오의. **차분하고 우아한 한 번의 찌르기.**

```
Seola, a calm and elegant mermaid girl from the reference image: very long straight pale
ice-blue hair, small fin-shaped ears, red eyes, outfit exactly as in the reference, long pale
blue mermaid tail. She summons a slender ice-crystal spear (white shaft, pale blue crystal
blade, as in the second reference) into her right hand with a sparkle of frost. She draws the
spear back with a slow graceful turn, hair flowing, then thrusts it diagonally toward the lower
left in one smooth precise motion. Thin frost crystals bloom only along the spear tip.
Final pose: spear extended to the lower left, free hand open beside her face, half-lidded cool
eyes and a faint confident smile, hair and tail settling.
```
+ 공통 꼬리말 (`{KEY}` = pure green #00FF00)

#### 미나 (mina) — 화염 · 「종언의 화로」 · 배경 초록
적 전체를 불길로 밀어내는 탱커의 오의. **방패를 앞세운 힘찬 돌진.**

```
Mina, an energetic cheerful girl from the reference image: long wavy blonde hair, purple eyes,
small bat wings, outfit exactly as in the reference (white shirt, red necktie, red pleated
skirt, cream leg warmers, brown loafers). She pulls a large cream round shield with a red flame
emblem onto her left arm and a short wooden baton into her right hand (as in the second
reference). She crouches and braces behind the shield, wings spreading wide, then bashes the
shield forward toward the lower left with her whole body, hair whipping back. Small flames
flicker only on the shield emblem. Final pose: shield thrust forward to the lower left, baton
raised high, big determined grin with one fang showing, wings flared.
```
+ 공통 꼬리말 (`{KEY}` = pure green #00FF00)

#### 태희 (taehee) — 침식 · 「완성된 초상」 · 배경 초록
쌓아 둔 속박을 터뜨리는 오의. **낮게 웅크렸다 튀어 나가는 교차 베기.**

```
Taehee, a quiet and menacing shark girl from the reference image: long white hair in two low
twin tails, red eyes, a gray scarf with a white shark-teeth pattern covering her mouth, black
dress exactly as in the reference, dark gray shark tail, gray clawed hands. Two curved dark
blades with violet edges appear in her hands (as in the second reference). She sinks into a
low crouch, eyes glinting above the scarf, then springs forward and slashes both blades in an
X toward the lower left, twin tails and tail lashing behind her. Faint violet trails follow the
blade edges only. Final pose: low lunge, blades crossed in front of her chest, narrowed eyes.
```
+ 공통 꼬리말 (`{KEY}` = pure green #00FF00)

#### 하랑 (harang) — 충격 · 「해일의 일격」 · 배경 자홍
적 전체를 한 번에 내려치는 탱커의 오의. **대검을 크게 돌려 내려치기.**

```
Harang, a cheerful dinosaur girl from the reference image: mint-green hair in two small buns,
yellow eyes, outfit exactly as in the reference (green-and-white jacket, denim overall shorts,
loose white socks, green rubber boots), green dinosaur tail with yellow spikes. An oversized
steel greatsword (as in the second reference) appears in her hands. She heaves it up over her
shoulder with both hands, leaning back, tail swinging for balance, then brings it down in a
huge arc toward the lower left with a battle shout, buns bouncing. A small burst of dust only
where the blade ends. Final pose: greatsword low and forward to the lower left, feet planted
wide, mouth open in a shout, eyes wide.
```
+ 공통 꼬리말 (`{KEY}` = pure magenta #FF00FF)

#### 아린 (arin) — 전격 · 「낙뢰 처형」 · 배경 초록
한 적에게 벼락을 떨어뜨려 처형하는 오의. **침착하게 조준해 쏘는 한 발.**

```
Arin, a composed girl from the reference image: short blonde bob with a hair clip, golden eyes,
outfit exactly as in the reference (oversized cream cable-knit cardigan, white top, dark short
skirt, small cream shoulder bag, white sneakers). A crossbow with purple lightning motifs (as
in the second reference) appears in her hands. She snaps it up to her shoulder, closes one eye
and aims toward the lower left, cardigan sleeves swaying, then fires; the recoil pushes her
shoulder back slightly and her hair flicks. Thin purple-white electricity crackles only along
the crossbow string and limbs. Final pose: still aiming to the lower left, one eye closed,
steady and focused.
```
+ 공통 꼬리말 (`{KEY}` = pure green #00FF00)

#### 강지 (gangji) — 광휘 · 「여명의 각인」 · 배경 자홍
아군 전체를 회복하고 북돋는 오의. **지팡이를 높이 들어 빛을 내리는 기도.**

```
Gangji, a gentle warm girl from the reference image: light brown short hair with a small green
leaf clip, amber eyes, outfit exactly as in the reference (long cream cardigan with brown
ribbon ties, green knit top, brown skirt, brown lace-up boots, brown satchel). A wooden staff
topped with a glowing yellow orb (as in the second reference) appears in her hands. She holds
it close to her chest with eyes closed as if praying, then sweeps it up high above her head
with both hands, cardigan and ribbons fluttering upward. The orb brightens softly, only the orb
glows. Final pose: staff raised high, body leaning slightly to the left, gentle smile with eyes
softly closed.
```
+ 공통 꼬리말 (`{KEY}` = pure magenta #FF00FF)

---

### A3. 뽑을 때 · 고를 때

- 캐릭터마다 **3~4번 뽑아** 가장 나은 것을 고른다. 이미지→영상은 같은 프롬프트로도 결과 편차가 크다.
- 검수 기준:
  - [ ] 얼굴·머리·의상이 첫 프레임(초상)과 끝까지 같은가(얼굴 녹아내림·옷 바뀜 없음)
  - [ ] 무기 모양이 중간에 바뀌지 않는가, 손가락 수가 맞는가
  - [ ] 카메라가 완전히 고정인가, 캐릭터가 화면 밖으로 나가지 않는가
  - [ ] 배경이 끝까지 균일한 단색인가, 캐릭터에 크로마키 색이 묻지 않았는가
  - [ ] 마지막 0.6초가 결정 포즈로 거의 멈춰 있는가
- 초상의 노출이 있는 의상은 **참조 그대로** 둔다 — 프롬프트로 더하거나 바꾸지 않는다.

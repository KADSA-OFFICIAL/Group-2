# 오의 LD 2D 공격 애니메이션 — 아스트라(이미지→영상) 프롬프트

오의 연출(#544)의 캐릭터를 **SD 전투 스프라이트 대신 LD(편성 초상) 그림체**로 바꾸고,
정지 그림이 아니라 **실제로 공격하는 2D 애니메이션**을 넣기 위한 영상 생성 프롬프트다.

- **입력**: 캐릭터의 편성 초상 전신 일러스트(LD, 약 7등신)를 참조·첫 프레임으로 넣는다.
- **출력**: 단색 배경 위 캐릭터만 움직이는 2.5~3초 클립 → 크로마키로 배경을 빼서
  지금 연출(원소색 사선 판 · 기술명 타이포) 위에 재생한다.
- 생성 도구는 이 저장소를 읽지 못하므로 각 프롬프트는 **자기 완결형**이다.

---

## 1. 공통 규격

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

### 동작 박자 (모든 캐릭터 공통)

| 구간 | 동작 |
|---|---|
| 0.0 ~ 0.3초 | 참조 그림 자세에서 시작 → 무기를 꺼내거나 고쳐 쥔다 |
| 0.3 ~ 0.8초 | **예비 동작**(뒤로 젖히기·웅크리기·힘 모으기) — 머리카락·옷자락이 따라 흔들린다 |
| 0.8 ~ 1.6초 | **공격의 정점** — 빠르고 시원하게. 몸 전체를 쓴 한 동작 |
| 1.6 ~ 2.4초 | 여운 — 머리카락·꼬리·옷자락이 늦게 따라와 가라앉는다 |
| 2.4 ~ 3.0초 | **결정 포즈 유지**, 숨 쉬는 정도의 미세한 움직임 |

### 크로마키 색

캐릭터 색과 겹치지 않는 색을 고른다(초록 머리·꼬리가 있는 하랑·강지는 자홍색).

| 캐릭터 | 배경 |
|---|---|
| 설아 · 미나 · 태희 · 아린 | 순수 초록 `#00FF00` |
| 하랑 · 강지 | 순수 자홍 `#FF00FF` |

### 공통 꼬리말 (모든 프롬프트 끝에 붙인다)

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

### 공통 네거티브 (도구가 지원하면)

```
morphing face, changing outfit, extra fingers, extra limbs, deformed hands, weapon changing
shape, chibi proportions, camera movement, zoom, background scenery, gradient background,
floor shadow, text, logo, watermark, blur, motion smear covering the face, flickering
```

---

## 2. 캐릭터별 프롬프트

`{KEY}` 는 위 표의 배경색으로 바꿔 넣는다(`pure green #00FF00` / `pure magenta #FF00FF`).

### 설아 (seola) — 한기 · 「절대 영도 관측」 · 배경 초록
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

### 미나 (mina) — 화염 · 「종언의 화로」 · 배경 초록
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

### 태희 (taehee) — 침식 · 「완성된 초상」 · 배경 초록
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

### 하랑 (harang) — 충격 · 「해일의 일격」 · 배경 자홍
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

### 아린 (arin) — 전격 · 「낙뢰 처형」 · 배경 초록
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

### 강지 (gangji) — 광휘 · 「여명의 각인」 · 배경 자홍
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

## 3. 뽑을 때 · 고를 때

- 캐릭터마다 **3~4번 뽑아** 가장 나은 것을 고른다. 이미지→영상은 같은 프롬프트로도 결과 편차가 크다.
- 검수 기준:
  - [ ] 얼굴·머리·의상이 첫 프레임(초상)과 끝까지 같은가(얼굴 녹아내림·옷 바뀜 없음)
  - [ ] 무기 모양이 중간에 바뀌지 않는가, 손가락 수가 맞는가
  - [ ] 카메라가 완전히 고정인가, 캐릭터가 화면 밖으로 나가지 않는가
  - [ ] 배경이 끝까지 균일한 단색인가, 캐릭터에 크로마키 색이 묻지 않았는가
  - [ ] 마지막 0.6초가 결정 포즈로 거의 멈춰 있는가
- 초상의 노출이 있는 의상은 **참조 그대로** 둔다 — 프롬프트로 더하거나 바꾸지 않는다.

## 4. 넣는 법 (#546 에서 연동됨)

1. 원본 클립은 `art/ultimate-ld/<id>.mp4` 에 보관한다.
2. 투명 PNG 시퀀스 zip 을 `tools/build_ultimate_videos.py` 로 변환한다 →
   `assets/video/ultimate/<id>.ogv`(알파를 옆에 붙인 Theora) + 결정 포즈 정지 그림. 자세한 것은
   [art/ultimate-ld/README.md](../art/ultimate-ld/README.md).
3. 공격 정점 시점이 다르면 `UltimateCutin.VIDEO_STRIKE` 를 맞춘다.

> 현재 들어간 6명분은 아스트라가 아니라 이미지 생성 포즈 6장 + 로컬 합성으로 만든 리미티드 애니메이션이다
> (경위: art/ultimate-ld/README.md). 아스트라로 다시 뽑으면 같은 경로로 교체하면 된다.

# 검열판(전체이용가) 원화 — ChatGPT 프롬프트 (#586)

일반판 원화는 **그대로 둔다.** 검열판 빌드에서만 같은 이름·같은 규격의 그림으로 바꿔 끼운다
(구조·릴리스: [release-editions.md](release-editions.md), 넣는 곳: [assets_censored/](../assets_censored/README.md)).
대상은 **초상(파티 6명 + 스토리 인물 2명) + 궁극기 컷인 원화**뿐이다. 도트(걷기·전투 SD 스프라이트)는 건드리지 않는다.

- **한 캐릭터는 한 대화에서 끝낸다.** 초상을 먼저 승인받고, 그 초상을 궁극기 프레임의 의상 참조로 쓴다.
- ChatGPT는 저장소를 못 읽으니 아래 프롬프트는 모두 자기 완결형이다. 원본 그림을 **반드시 첨부**한다.
- 새로 그리는 게 아니라 **원본을 편집**하는 방식이다 — 포즈·얼굴·구도·타이밍을 살리고 의상·체형 강조만 바꾼다.

---

## 1. 순화 기준 (전체이용가)

| 항목 | 기준 |
|---|---|
| 노출 | 가슴골·밑가슴·옆가슴 없음. 배꼽·허리 노출 없음. 맨어깨는 한쪽 정도까지만 |
| 치마·바지 | 무릎 위 한 뼘 이상 짧지 않게. 짧으면 안에 반바지/불투명 타이츠. **속옷이 보이는 각도 없음** |
| 체형 | 가슴·엉덩이·허벅지 과장 없이 평범한 체형. 몸매를 강조하는 포즈·옷 주름·광택 피부 없음 |
| 포즈·구도 | 가슴·엉덩이·사타구니를 향한 카메라 앵글 없음. 웅크리거나 다리를 벌리는 공격 동작은 치마 대신 반바지가 보이게 |
| 유지할 것 | 얼굴, 머리 모양·색, 눈 색, 수인 특징(꼬리·날개·지느러미·발톱), 무기, 색 조합, 캐릭터 인상 |

## 2. 캐릭터별 바꿀 점

| 캐릭터 | 원본 문제 | 검열판 의상 |
|---|---|---|
| **설아** seola | 거의 맨몸에 얇은 천만 두름 (가장 심함) | 궁극기 원화의 **하늘색 프릴 원피스**를 기준으로, 목까지 올라온 민소매 원피스 + 무릎 길이 치마. 맨발·꼬리 유지 |
| **미나** mina | 밑가슴이 드러나는 짧은 셔츠, 초미니 치마, 허벅지 가터 | 단추를 끝까지 채워 넣어 입은 흰 셔츠 + 빨간 넥타이, 무릎 길이 빨간 주름치마(안에 검은 반바지), 가터 제거 |
| **하랑** harang | 재킷 가슴 트임(키홀), 짧은 반바지, 허벅지 강조 | 트임 없이 닫힌 지퍼 재킷 + 안에 흰 티셔츠, 허벅지 중간 길이의 멜빵 반바지, 평범한 체형 |
| **강지** gangji | 크롭 캐미솔(배 노출), 카디건이 어깨에서 흘러내림 | 허리까지 내려오는 올리브색 캐미솔(배 가림), 카디건을 양 어깨에 바르게, 치마는 무릎 위 정도로 |
| **아린** arin | 미니스커트 정도 | 치마를 허벅지 중간 이상으로 + 안에 반바지. 나머지는 그대로 (가벼운 수정) |
| **태희** taehee | 문제 거의 없음 | 원피스 길이만 무릎 위 정도로 확인. 필요 없으면 일반판 그림을 그대로 쓴다 |
| **여신** goddess (스토리) | 한쪽 어깨만 걸친 드레스, 허벅지까지 트인 옆선 | 양 어깨를 덮는 흰 드레스, 옆트임 없이 발목까지. 맨발·긴 금발 유지 |
| **girl_green** (초상 목록) | 짧은 크롭 세일러 상의(배 노출), 골반 끈, 아주 짧은 치마 | 허리까지 덮는 세일러 상의, 골반 끈 제거, 무릎 위 주름치마 + 반바지 |

> 우선순위: 설아 → 미나 → 여신 → 하랑 → girl_green → 강지 → 아린 → 태희
> 소꿉친구(childhood_friend)·girl_lilac 은 그대로 써도 된다.

---

## 3. 대화 시작 프롬프트 (캐릭터마다 대화 첫 메시지)

```
I am making an ALL-AGES (rated "everyone") edition of my game's character art.
In this conversation I will attach my own original artwork of ONE character and ask you to EDIT it.
Rules for every image in this conversation:
- Keep the exact same character: face, eyes, hair style and color, expression, animal traits
  (tail, wings, fins, claws), weapon, color palette, line art and cel-shading style.
- Keep the exact same pose, camera, framing, canvas size and the head at the same position and size.
- Change ONLY the outfit and body emphasis so it is modest and suitable for all ages:
  no cleavage, no underboob or sideboob, no bare midriff, skirts no shorter than mid-thigh with
  shorts underneath, no visible underwear from any angle, normal non-exaggerated body proportions,
  no glossy skin, no suggestive pose or camera angle.
- Background exactly as the original (transparent, or the same flat chroma color).
- No text, no watermark, no border.
Reply "ready" and wait for the first image.
```

## 4. 초상 편집 프롬프트

첨부: `assets/sprites/characters/portraits/<id>.png` (설아는 궁극기 원화 `cutins/ult/seola/seola_ult_00.webp`도 함께 — 의상 참조)

```
EDIT the attached portrait of {NAME}. Same full-body standing pose, same face and expression,
same canvas ({W}x{H}, vertical), head at exactly the same position and size, transparent background.
OUTFIT CHANGE: {OUTFIT}
Everything else stays exactly as the original.
```

`{OUTFIT}` 과 원본 크기(편집 후 이 크기로 맞춰 저장 — 초상 머리 자르기 좌표 `data/portraits/portrait_meta.tres` 가 비율로 잡혀 있어 머리 위치가 바뀌면 편성 화면 얼굴이 어긋난다):

| id | 크기 | `{OUTFIT}` |
|---|---|---|
| seola | 1345×2416 | `Replace the thin wrapped cloth with the pale ice-blue frilled sleeveless dress from the second attached image: high round neckline, fully covered chest and sides, knee-length skirt. Keep her bare feet, fin ears and long mermaid tail. Natural modest body shape.` |
| mina | 1267×2277 | `The white shirt is full length, fully buttoned up to the collar and tucked into the skirt, red necktie neatly tied, no exposed chest or stomach. Red pleated skirt lengthened to just above the knee with black shorts underneath. Remove the thigh garter. Keep the bat wings, leg warmers and loafers. Normal modest body shape.` |
| harang | 1278×1946 | `Close the keyhole cutout of the green-and-white jacket completely, zipped up, with a plain white t-shirt underneath. Denim overall shorts lengthened to mid-thigh. Normal, non-exaggerated thighs and hips. Keep the bowl and spoon, socks, green boots and dinosaur tail.` |
| gangji | 918×1650 | `Olive green camisole lengthened to cover her stomach fully, tucked into the belt. The cream cardigan sits properly on both shoulders. Brown pleated skirt a little longer, black bike shorts underneath. Keep the ribbons, satchel, socks and boots.` |
| arin | 918×1649 | `Dark skirt lengthened to mid-thigh with dark shorts underneath. Everything else unchanged.` |
| taehee | 1011×1816 | `Black dress hem at least just above the knee. Everything else unchanged.` |
| goddess | 1184×2127 | `Replace the one-shoulder dress with a white dress that covers both shoulders and her chest, no side slit, hem down to the ankles. Keep her long blonde hair, bare feet and gentle pose.` |
| girl_green | 1090×1958 | `The white sailor top reaches her waist and covers her stomach. Remove the hip straps. Green pleated skirt lengthened to just above the knee with shorts underneath. Keep the gloves, socks, claws and tail.` |

저장: `assets_censored/sprites/characters/portraits/<id>.png` (원본 크기 그대로, PNG 투명).
승인 기준(§7 체크리스트)을 통과하면 다음 단계로.

---

## 5. 궁극기 원화 편집 프롬프트 (24장)

초상 의상을 바꾼 캐릭터는 궁극기 원화도 같은 의상으로 바꿔야 한다(같은 사람으로 보여야 하므로).
**새로 그리지 않고 일반판 24장을 한 장씩 편집**한다 — 동작·타이밍·발 위치가 그대로 살아난다.

첨부 (매 장): ① 일반판 원화 `assets/sprites/characters/cutins/ult/<id>/<id>_ult_{NN}.webp`
② 승인한 검열판 초상 ③ (2장째부터) 바로 앞에 승인한 검열판 프레임

```
ANIMATION FRAME {NN} of 24 for {NAME}'s ultimate attack.
EDIT image 1 only. Keep its exact pose, body position, weapon, hair, effects, scale and canvas size.
Change the outfit to match the modest outfit in image 2 (the approved all-ages portrait).
Image 3 is the previous edited frame: the outfit must look identical to it (same lengths, folds, colors).
{POSE_NOTE}
Fully transparent background (or flat {KEY} if transparency is not possible).
No motion blur, no text, no border, no frame number.
```

`{KEY}`: 설아·미나·태희·아린 `pure green #00FF00`, 하랑·강지 `pure magenta #FF00FF`

`{POSE_NOTE}` — 동작 때문에 노출이 생기는 장에만 붙인다:

| 캐릭터 | 장 | `{POSE_NOTE}` |
|---|---|---|
| mina | 04 ~ 15 (웅크림·방패 돌진) | `In this low stance the skirt must not reveal underwear; show the black shorts if anything.` |
| taehee | 04 ~ 23 (낮은 돌진) | `Low lunge: the dress hem covers her, shorts visible underneath if anything.` |
| harang | 04 ~ 10 (검을 머리 위로) | `Arms raised: the jacket and t-shirt still cover her stomach.` |
| gangji | 08 ~ 23 (지팡이를 머리 위로) | `Arms raised: the camisole still covers her stomach.` |
| seola | 04 ~ 15 | `Wide stance: the dress skirt covers her thighs; no exposed chest or sides.` |

순서: 키 6장 `00 → 04 → 08 → 11 → 16 → 23` 먼저, 그다음 사이 장(`01 02 03 05 06 07 09 10 12 13 14 15 17 18 19 20 21 22`).
저장: `<id>/00.png ~ 23.png` 폴더로 모은 뒤
`python tools/build_ultimate_frames.py <id> <폴더> --censored` — 같은 상자로 잘라
`assets_censored/sprites/characters/cutins/ult/<id>/` 에 넣는다.

> 아린·태희처럼 초상 변경이 거의 없으면 궁극기 원화는 일반판을 그대로 쓴다.

---

## 6. ChatGPT가 거절하거나 어긋날 때

- 거절: 첫 메시지의 "ALL-AGES edition", "my own original artwork", "make it MORE modest" 를 다시 강조한다. 원본 노출이 심한 설아는 편집이 막히면 **궁극기 원화(seola_ult_00)만 첨부**하고 그 원피스 차림의 전신 초상을 그리라고 한다.
- 얼굴·그림체가 바뀜: `The face changed. Keep the face, eyes and line art EXACTLY as the original; only the clothes may change.`
- 크기·위치가 바뀜: 그대로 받아서 원본 크기로 맞춘다. 머리 위치가 크게 어긋나면 다시 뽑는다.
- 프레임마다 옷 길이가 달라짐: ③ 앞 프레임을 꼭 첨부하고, 어긋나면 그 장만 다시 뽑는다.

## 7. 검수 체크리스트

- [ ] §1 기준을 모두 만족 (특히 웅크림·돌진 장의 치마 속)
- [ ] 얼굴·머리·눈 색·꼬리/날개·무기가 일반판과 같다
- [ ] 초상: 원본과 같은 픽셀 크기, 투명 배경, 머리 위치 동일
- [ ] 궁극기: 24장 내내 의상·인물 크기 동일, 공격 방향(화면 왼쪽 아래) 유지
- [ ] 글자·워터마크·테두리 없음
- [ ] `godot --headless --path . --import` 후 `res://tests/edition/VerifyGameEdition.tscn -- --censored` 통과

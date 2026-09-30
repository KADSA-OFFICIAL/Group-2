# assets/audio

게임의 소리를 두는 곳이다. `bgm/` 은 배경음악이다.

재생은 [`MusicSystem`](../../autoload/MusicSystem.gd)(autoload)이 한다. 여기 파일을 두는 것만으로는
아무 소리도 나지 않는다 — 어느 화면이 어느 곡을 쓰는지는 그 화면 쪽이 정한다
(로비 곡은 [`main_screen_launcher.gd`](../../screens/main/main_screen_launcher.gd)의 `LOBBY_BGM`).

| 파일 | 쓰이는 곳 | 곡 | 길이 | 음량 |
|---|---|---|---|---|
| `bgm/lobby_theme.ogg` | 로비(메타 화면) | "Afterschool Plaza" — D장조 98BPM 시티팝. 로즈·핑거 베이스·클린 기타 커팅·종 | 1:18.4 (32마디) | −23 LUFS |
| `bgm/story_theme.ogg` | 스토리 화면 | "Letters in Blue" — F장조 72BPM. 피아노 → 로즈 분산화음·베이스 → 현 패드·종 | 1:20.0 (24마디) | −23.5 LUFS |
| `bgm/sortie_theme.ogg` | 스테이지 선택 · 편성 | "Blue Sortie" — A장조 124BPM 퓨처 펑크. 네 박 킥·플럭 분산화음·로즈·리드 훅 | 1:01.9 (32마디) | −22 LUFS |
| `bgm/battle_land.ogg` | 전투 · 1챕터(육지) | "Schale Skirmish" — B단조/D장조 148BPM. 피아노 스탭·신스 베이스·브레이크비트 | 0:51.9 (32마디) | −21 LUFS |
| `bgm/battle_sea.ogg` | 전투 · 2챕터(바다) | "Coral Parade" — E장조 122BPM 트로피컬 퓨처 펑크. 나무 건반·로즈 뒷박·셰이커 | 1:03.0 (32마디) | −21 LUFS |
| `bgm/battle_sky.ogg` | 전투 · 3챕터(하늘) | "Skyline Rush" — G장조 156BPM. 16분 종 분산화음 위로 긴 음의 선율 | 0:49.2 (32마디) | −21 LUFS |
| `bgm/battle_boss.ogg` | 보스 웨이브 | "Crimson Protocol" — D단조 138BPM. 피아노 16분 오스티나토·8분 베이스·현·합창 | 0:55.7 (32마디) | −20.5 LUFS |
| `bgm/battle_final.ogg` | 3챕터(하늘) 보스 웨이브 | "Last Sanctuary" — C단조 146BPM. 피아노 옥타브·플럭·현·합창·낮은 붐 | 0:52.6 (32마디) | −20.5 LUFS |
| `bgm/jingle_victory.ogg` | 결과 · 승리 (1회) | 로즈 화음 위로 종이 올라가 으뜸화음에서 멈춤 | 0:09.0 | −21 LUFS |
| `bgm/jingle_defeat.ogg` | 결과 · 패배 (1회) | 로즈·피아노가 조용히 내려와 sus 화음에 머묾 | 0:09.8 | −23 LUFS |

### 블루 아카이브 풍 배경음 (#539)

"옛날 게임 같다 / AI 같다 / 배경음치고 크다"는 피드백으로 10곡을 다시 썼다. 참고한 것은 블루 아카이브
사운드트랙의 **분위기**(밝은 시티팝·퓨처 펑크, 7·9화음, 로즈 피아노, 사이드체인으로 숨 쉬는 패드)뿐이다.

- **칩튠 소리를 쓰지 않는다.** 사각파 리드·FM 브라스·슈퍼소 대신 로즈(`rhodes`)·피아노·카플러스-스트롱
  기타(`guitar`)·핑거 베이스(`bass`)·부드러운 리드(`lead`)·종(`bell`).
- **여백.** 곡마다 첫 8마디는 반주·그루브만 흐르고, 선율은 쉼표를 두고 움직인다.
- **작게.** 예전보다 3~4dB 낮다(일상 −23, 전투 −21, 보스 −20.5 LUFS). 마스터 고역을 15kHz 에서 살짝 깎아
  오래 틀어도 귀가 피곤하지 않게 했다.
- **믹스 균형은 숫자로 남긴다.** 각 곡의 `mix(levels=...)` 는 버스별 목표 dB(드럼 0 기준)다. 악기나 세기를 고쳐도
  균형이 흔들리지 않는다.

메타 화면의 곡은 `main_screen_launcher.gd` 의 `SCREEN_MUSIC` 이 맨 위 화면으로 고른다(없으면 로비 곡, 결과 화면이면
전투가 튼 징글을 그대로 둔다). 3챕터 보스 곡은 `TurnBattle._boss_music()` 이 고른다(없으면 `battle_boss`).

전투곡은 `TurnBattle` 이 고른다: 스테이지 챕터 컨셉(`StageData.get_concept()`, 배경과 같은 규칙)으로 전투곡,
적 중에 `EnemyTier.BOSS` 가 있는 웨이브는 보스곡, 결과 배너와 함께 징글(반복 없음, `.import` `loop=false`).
곡 파일이 없으면 육지 전투곡으로 떨어진다.

## 자체 작곡곡이다 (#535, #539)

모든 곡을 [`tools/gen_bgm.py`](../../tools/gen_bgm.py) 가 **외부 샘플 없이 합성**해 만든다. 멜로디·코드 진행·
편곡은 그 파일에 직접 적은 자작곡이고, 참고한 것은 분위기뿐이다(#539: 블루 아카이브 사운드트랙의 청량한
시티팝·퓨처 펑크 감). **원곡의 멜로디를 옮기지 않는다** — 그러면 같은 저작권 문제가 된다.

> 예전 `lobby_theme.ogg` 는 트릭컬의 상용 BGM 을 자리 채우기로 넣은 것이었다(#308). #535 에서 교체했다.
> 저장소 기록(git history)에는 남아 있으므로, 배포 저장소를 따로 만들 때는 기록째 옮기지 않는다.

다시 만들기(같은 시드면 같은 곡):

```bash
python tools/gen_bgm.py                  # 전부
python tools/gen_bgm.py lobby boss       # 골라서 (lobby story sortie land sea sky boss final victory defeat)
```

음량을 정할 때의 기준: 곡 안의 리드(멜로디)는 반주보다 앞에 나오지 않게 섞었다 — 배경음이다.
효과음은 각 −15dB 로 재생되므로(docs/battle-audio.md) 전투곡을 −21 LUFS 로 낮춰 타격음이 묻히지 않게 했다.
반복 이음새는 곡 끝에서 넘친 잔향을 곡 처음에 더해 없앤다.

교체할 때 코드는 건드릴 필요가 없다. 같은 경로에 같은 이름으로 넣거나, `LOBBY_BGM` 이 가리키는
경로만 바꾸면 된다.

## 형식 규약

**OGG Vorbis 를 쓴다.** Godot 이 루프 BGM 에 쓰는 기본 형식이고, `.import` 에서 `loop` 와
`loop_offset` 을 지정할 수 있다. MP3 도 재생은 되지만 굳이 섞지 않는다.

**`.import` 의 `loop` 를 켜야 반복된다.** 파일을 새로 넣으면 기본값이 `loop=false` 라
한 번 재생되고 멈춘다. `MusicSystem` 은 이 값을 건드리지 않는다 — 반복 여부는 "그 곡 자신의
성질"이라 재생기가 아니라 에셋이 갖는다.

## 긴 음원을 받았을 때 (루프 1주기 잘라내기)

유튜브의 "1시간 반복" 음원처럼 같은 곡이 여러 번 이어 붙은 파일은 **그대로 커밋할 수 없다.**
GitHub 은 100MB 초과 파일을 거부하고, 그보다 작아도 저장소에 영구히 남는다.

예전 `lobby_theme.ogg`(#308)를 만든 절차를 남긴다. 원본은 60분 320kbps MP3(137MB)였다.

1. **주기 찾기** — 100Hz 모노로 줄여 자기상관을 본다.
   ```bash
   ffmpeg -i src.mp3 -ac 1 -ar 100 -f s16le env.raw
   ```
   그 신호에서 지연을 30~420초 훑어 상관이 가장 높은 지점을 찾는다. 진짜 주기라면
   **2배·3배 지연에서도** 상관이 유지된다(우연한 일치 배제). 이 곡은 **242.6초**였다.

2. **정밀화** — 44.1kHz 로 다시 뽑아 그 둘레만 샘플 단위로 훑는다.
   결과 10,698,660 샘플 = 242.600000초.

3. **시작점 확인** — 파일이 곡 중간부터 시작하면 `[0, T]` 가 1주기가 아니다.
   자기 자신을 T 만큼 밀어 상쇄해 잔차를 본다.
   ```bash
   ffmpeg -i src.mp3 -ss 242.6 -i src.mp3 -filter_complex \
     "[0:a]atrim=0:60,aformat=fltp,asetpts=N/SR/TB[a];\
      [1:a]atrim=0:60,aformat=fltp,asetpts=N/SR/TB,volume=-1[b];\
      [a][b]amix=inputs=2:normalize=0,volumedetect" -f null -
   ```
   원본 −25.8dB 에 잔차 −43.0dB 이면 `t=0` 과 `t=T` 가 같은 악곡 위치다.

4. **자르고 인코딩**
   ```bash
   ffmpeg -i src.mp3 -t 242.6 -vn -map_metadata -1 \
     -c:a libvorbis -q:a 4 -ar 44100 -ac 2 bgm/lobby_theme.ogg
   ```

5. **이음새 검증** — 2회 루프한 결과를 원본과 상쇄해, 이음새 구간과 일반 구간의 잔차를 비교한다.
   여기서는 −44.2dB vs −50.9dB 로 차이가 7dB 뿐이었고 클릭(0dB 근처 스파이크)이 없었다.

> **바이트 단위로 반복을 찾으려 하지 마라.** 한 번에 인코딩된 파일은 같은 음악이라도
> 비트 리저버 때문에 바이트가 달라진다. 이 파일에서도 바이트 반복은 없었다.

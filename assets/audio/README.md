# assets/audio

게임의 소리를 두는 곳이다. `bgm/` 은 배경음악이다.

재생은 [`MusicSystem`](../../autoload/MusicSystem.gd)(autoload)이 한다. 여기 파일을 두는 것만으로는
아무 소리도 나지 않는다 — 어느 화면이 어느 곡을 쓰는지는 그 화면 쪽이 정한다
(로비 곡은 [`main_screen_launcher.gd`](../../screens/main/main_screen_launcher.gd)의 `LOBBY_BGM`).

| 파일 | 쓰이는 곳 | 길이 | 크기 |
|---|---|---|---|
| `bgm/lobby_theme.ogg` | 로비(메타 화면) | 4:02.6 | 3.3MB |

## > 이 음원은 반드시 교체해야 한다

`bgm/lobby_theme.ogg` 는 **트릭컬(TrickCal)의 상용 BGM** 이다(#308). 이 저장소는 **public** 이므로,
배포 전에 **자체 제작곡이나 라이선스가 확인된 곡으로 교체해야 한다.** 지금은 "소리가 나는지"를
확인하기 위한 자리 채우기다.

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

`lobby_theme.ogg` 를 만든 절차를 남긴다. 원본은 60분 320kbps MP3(137MB)였다.

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

# 누락 아트 연결 검수 — 2026-09-14

## 반영 항목
- #514: 매머드 수인·보스·익룡 여왕 초상 3종, EnemyData 연결, 타임라인 얼굴 영역. [얼굴 크롭](../missing-portraits/).
- #515: 512×512 장비 아이콘 17종과 모든 EquipmentData.icon 연결. [아이콘 시트](equipment.png).
- #516: 64초/120 BPM 전투 BGM과 효과음 6종. 타격·격파·잠금 해제·상태·사망 5개 연출 경로 연결. 회복음은 회복 연출 경로가 없어 에셋만 보관. [음원 설명](../../battle-audio.md).
- #518: 하랑·미나·설아·태희 컷인 4종을 수정 문서 기준 2400×1350 RGBA로 재제작. 인물 폭 1240px(51.7%), 오른쪽 타이포 공간 보존. 얼굴은 중앙보다 위, 아래 몸통은 캔버스 끝에서 잘림.

## 제작 및 연결
이미지 생성 도구로 참조 기반 일러스트를 제작하고 색 키 제거·가장자리 색 정리·캔버스 배치는 기계적으로 처리했다. 초상/스프라이트 원본은 변경하지 않았다. 미나는 전투 프레임의 흰 셔츠·붉은 넥타이·갈색 치마·금발·날개, 설아는 청색 머리·붉은 눈·얼음 무기를 참조했다. 생성 제한에 맞춰 설아 의상에는 불투명 안감을 적용했다. 사용 프롬프트는 [prompts](prompts/)에 보관한다. mina.prompt.txt는 실패한 첫 시도이고 mina-safe.prompt.txt가 최종 입력이다.

전용 컷인은 `assets/sprites/characters/cutins/`에서 로드한다. `art/character-assets/`는 .gdignore로 실행 대상에서 제외되므로 보관용 복사본만 둔다. 전용 파일이 없으면 PortraitSystem 초상을 사용한다. 신규 4종은 인물 왼쪽/이름·스킬 오른쪽, 기존 아린·강지 폴백은 원래 배치를 유지한다. 첨부 정본 이미지의 실제 좌우 배치와 수정 문서 설명이 달라 신규 4종에는 문서의 명시된 배치를 적용했다. 연출 시간과 전투 수치는 유지했다.

## 검증
Godot 4.6.3 Windows에서 다음 검증을 실행했다.
- VerifyMissingPortraits: PASS — 3종 초상과 얼굴 크롭.
- VerifyEquipmentIcons: PASS — 17종 연결·크기·여백.
- VerifyBattleAudio: PASS — 로비/전투 음악 전환, 루프, 5종 SE, 잠금 음정, 최대 8개 동시 음성, 누락 파일 처리.
- VerifyDedicatedCutins: PASS — 4종 크기·투명 공간·좌우 배치·아린 폴백.
- VerifyTurnCombat: PASS — 438개.
- VerifyTurnStageBattle: PASS — 135개.
- 그래픽 렌더러에서도 VerifyDedicatedCutins를 실행하고 아래 4개 화면을 확인했다. 컷인 배치 확인용 정지 화면이며 전체 오의 모션 캡처는 아니다.

[하랑](harang-cutin.png) · [미나](mina-cutin.png) · [설아](seola-cutin.png) · [태희](taehee-cutin.png)

## 남은 제한
일부 검증 종료 시 ObjectDB/RID/리소스 정리 경고가 출력된다. 기능 검증 실패나 스크립트 파싱 오류와 구분해 기록한다. VerifyBattleSoak 씬은 현재 저장소에 없어 실행하지 않았다. 음원은 직접 합성한 원곡이며 디코딩·길이·레벨을 검사했지만 실제 스피커 청음 검수는 하지 않았다.

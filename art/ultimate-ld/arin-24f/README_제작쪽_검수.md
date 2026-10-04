# 아린 초상 및 오의 24장

2026-10-04 · 내장 image_gen 도구로 생성

- arin_portrait.png: 그림체 통일 전신 초상, 1024×1536, 자홍 배경. 투명 배경 재생성이 실패하여 원문에 허용된 자홍 배경 방식을 사용했다.
- arin_portrait_initial_transparent.png: 오의 생성에 사용한 초기 투명 초상. 크기와 가장자리 여백은 최종 규격과 다르므로 참고용.
- arin/00.png~23.png: 오의 24장, 각각 1024×1536. 6개 키 포즈를 먼저 생성한 뒤 원문 지정 순서로 중간 포즈를 생성했다.
- arin_24f_prompts.txt: 제공된 오의 프롬프트 원문. 첫 참조 초상은 기존 초상 대신 이 작업에서 생성한 초기 초상으로 교체했다.
- generation_prompts.json: 기본 생성 프롬프트 및 참조 관계.
- validation.csv: 실제 파일 크기, 해상도, 좌상단 색과 SHA256.

## 실제 검수 결과

24장 모두 존재하고 1024×1536 해상도다. 16~23의 발사 후 불꽃 잔류를 추가 이미지 편집으로 제거했다. 얼굴·의상·장식·하체가 대체로 유지되며 수인 특징은 추가하지 않았다.

생성된 배경은 정확한 #00FF00 또는 #FF00FF 단색과 차이가 있어 크로마키 색 정규화가 필요하다. 발 위치의 픽셀 단위 일치는 검증되지 않았다. 초기 석궁 방향이 오른쪽이고 조준 장은 왼쪽이어서 04~08 연결이 급하며, 일부 중간 포즈가 참조 키 포즈에 치우쳤다. 09~10에도 발사 효과가 나타나므로 프레임 11에만 발사 순간을 강조하려면 재검수가 필요하다. 초상과 오의의 가방 위치에도 차이가 있다.

이 묶음은 생성 원화이며 게임 조립·배경 제거·애니메이션 연결의 최종 검수를 통과한 게임 자산은 아니다. 첨부 README의 PR 승인·머지 및 다른 캐릭터 작업은 사용자 요청 범위에 포함되지 않아 수행하지 않았다.

## 추가 편집 프롬프트

회복/마무리: Remove all glowing purple/white sparks, flashes, floating particles and aura. Keep only painted purple lightning symbols on the wooden crossbow. Preserve exact pose, face, hair, hands, costume, bags, body scale and feet. Same 1024x1536 canvas and flat green background.

초상 배경: Change only background to flat solid #FF00FF magenta, remove black/brown gradient and glow; preserve exact character drawing, pose, features, outfit and accessories. 1024x1536 canvas.

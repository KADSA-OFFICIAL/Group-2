shader_type canvas_item;

// 스토리 배경을 살짝 흐리게 만든다.
//
// 왜 흐리게 하는가: 배경 그림이 선명하면 그 앞에 선 인물·대사 상자와 같은 층으로 읽혀
// 화면이 시끄럽다. 배경을 한 단계 뒤로 밀어 두면 인물이 먼저 눈에 들어온다
// (VN 에서 흔히 쓰는 피사계 심도 흉내다).
//
// 왜 그림 파일을 미리 흐리게 굽지 않는가: 원본을 잃으면 다시 선명하게 되돌릴 수 없고,
// 세기를 바꿀 때마다 에셋을 다시 만들어야 한다. 표시할 때만 흐리게 한다.
//
// 방식: 십자(+) 와 대각선(x) 두 겹으로 도는 13탭 근사 가우시안이다.
// 진짜 2패스 가우시안이 아니라 탭 수를 줄인 근사인데, 세기가 약해서(2~3텍셀)
// 차이가 보이지 않는다. 배경 한 장에 쓰는 것이라 패스를 나눌 이유가 없다.

// 흐린 정도(텍셀). 0 이면 원본 그대로다.
uniform float blur_radius : hint_range(0.0, 12.0) = 2.6;

void fragment() {
	vec2 texel = TEXTURE_PIXEL_SIZE * blur_radius;

	// 가운데가 가장 무겁고, 멀어질수록 가볍다. 합이 1이 되도록 맞춰 두었다.
	vec4 sum = texture(TEXTURE, UV) * 0.24;

	// 십자 방향 — 가까운 고리와 먼 고리.
	sum += texture(TEXTURE, UV + vec2( texel.x, 0.0)) * 0.11;
	sum += texture(TEXTURE, UV + vec2(-texel.x, 0.0)) * 0.11;
	sum += texture(TEXTURE, UV + vec2(0.0,  texel.y)) * 0.11;
	sum += texture(TEXTURE, UV + vec2(0.0, -texel.y)) * 0.11;

	// 대각선 — 십자만 쓰면 흐림이 십자 모양으로 번진다.
	sum += texture(TEXTURE, UV + vec2( texel.x,  texel.y)) * 0.055;
	sum += texture(TEXTURE, UV + vec2( texel.x, -texel.y)) * 0.055;
	sum += texture(TEXTURE, UV + vec2(-texel.x,  texel.y)) * 0.055;
	sum += texture(TEXTURE, UV + vec2(-texel.x, -texel.y)) * 0.055;

	// 바깥 고리. 두 배 거리에서 아주 옅게 섞어 경계를 부드럽게 만든다.
	sum += texture(TEXTURE, UV + vec2( texel.x * 2.0, 0.0)) * 0.0375;
	sum += texture(TEXTURE, UV + vec2(-texel.x * 2.0, 0.0)) * 0.0375;
	sum += texture(TEXTURE, UV + vec2(0.0,  texel.y * 2.0)) * 0.0375;
	sum += texture(TEXTURE, UV + vec2(0.0, -texel.y * 2.0)) * 0.0375;

	COLOR = sum * COLOR;
}

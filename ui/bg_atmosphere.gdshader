// res://ui/bg_atmosphere.gdshader
// HTML 메인 화면의 트와일라잇 배경(중앙 그라데이션 + 주황/시안 글로우)을 재현.
shader_type canvas_item;

uniform vec3 c_bg2  : source_color = vec3(0.227, 0.122, 0.369); // #3a1f5e
uniform vec3 c_bg1  : source_color = vec3(0.141, 0.090, 0.259); // #241742
uniform vec3 c_bg0  : source_color = vec3(0.078, 0.059, 0.149); // #140f26
uniform vec3 c_warm : source_color = vec3(1.000, 0.549, 0.353); // rgba(255,140,90)
uniform vec3 c_cyan : source_color = vec3(0.314, 0.784, 1.000); // rgba(80,200,255)

void fragment() {
	vec2 uv = UV;

	// 중앙 -> 가장자리: bg2 -> bg1 -> bg0
	float d = distance(uv, vec2(0.5));
	float t = clamp(d / 0.7, 0.0, 1.0);
	vec3 col = mix(c_bg2, c_bg1, smoothstep(0.0, 0.55, t));
	col = mix(col, c_bg0, smoothstep(0.55, 1.0, t));

	// 우상단 따뜻한 모닥불 글로우
	float gw = smoothstep(0.55, 0.0, distance(uv, vec2(0.70, 0.18)));
	col += c_warm * gw * 0.30;

	// 좌하단 시안 글로우
	float gc = smoothstep(0.55, 0.0, distance(uv, vec2(0.18, 0.85)));
	col += c_cyan * gc * 0.22;

	COLOR = vec4(col, 1.0);
}

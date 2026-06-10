// res://ui/glow_button.gdshader
// 둥근 사각형 + 대각선 그라데이션(주황→핑크) + 외곽 글로우 + 광택 sweep.
shader_type canvas_item;

uniform vec4 col_a : source_color = vec4(1.000, 0.541, 0.239, 1.0); // #ff8a3d
uniform vec4 col_b : source_color = vec4(1.000, 0.302, 0.553, 1.0); // #ff4d8d
uniform vec2 size = vec2(220.0, 84.0);
uniform float radius = 28.0;
uniform float glow = 16.0;
uniform float sheen = 1.0;

float sd_round(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = (UV - 0.5) * size;
	vec2 half_box = size * 0.5 - glow;
	float d = sd_round(p, half_box, radius);

	float fill  = smoothstep(1.0, -1.0, d);
	float glowA = smoothstep(glow, 0.0, d) * 0.55;

	float g = clamp((UV.x + UV.y) * 0.5, 0.0, 1.0);
	vec3 grad = mix(col_a.rgb, col_b.rgb, g);

	float s = 0.0;
	if (sheen > 0.5) {
		float x = fract(TIME * 0.25);
		float band = smoothstep(0.10, 0.0, abs(UV.x - (x * 1.4 - 0.2) + (UV.y - 0.5) * 0.2));
		s = band * 0.30 * fill;
	}

	vec3 rgb = grad + s + col_b.rgb * glowA * 0.6;
	float a = max(fill, glowA);
	COLOR = vec4(rgb, a);
}

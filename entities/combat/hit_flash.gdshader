shader_type canvas_item;

uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 base_color = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(base_color.rgb, vec3(1.0), flash), base_color.a);
}

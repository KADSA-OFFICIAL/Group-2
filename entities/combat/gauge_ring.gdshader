shader_type canvas_item;

uniform float brighten : hint_range(0.0, 1.0) = 0.0;
uniform vec4 highlight_color : source_color = vec4(1.0);

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, highlight_color.rgb, brighten);
}

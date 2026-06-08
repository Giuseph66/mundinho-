shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.12, 0.35, 0.12, 1.0);
uniform vec4 line_color : source_color = vec4(0.02, 0.12, 0.03, 1.0);
uniform float brick_scale = 3.0;
varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float leaf_shape(vec2 uv) {
	uv = uv * 2.0 - 1.0;
	float body = 1.0 - smoothstep(0.0, 0.16, length(vec2(uv.x * 1.6, uv.y)) - 0.62);
	float vein = 1.0 - smoothstep(0.0, 0.045, abs(uv.x));
	return max(body * 0.7, vein * body);
}

void fragment() {
	vec3 n = abs(NORMAL);
	vec2 projected = n.x > n.z ? local_pos.zy : local_pos.xy;
	vec2 uv = projected * brick_scale;
	vec2 cell = fract(uv);
	float row = floor(uv.y);
	cell.x = fract(cell.x + mod(row, 2.0) * 0.5);
	float leaf = leaf_shape(cell);
	float shade = 0.86 + 0.14 * sin((floor(uv.x) + floor(uv.y)) * 1.7);
	vec3 leaf_color = base_color.rgb * shade;
	ALBEDO = mix(base_color.rgb * 0.55, leaf_color, leaf);
	ALBEDO = mix(ALBEDO, line_color.rgb, 1.0 - smoothstep(0.0, 0.08, min(cell.x, cell.y)));
	ROUGHNESS = 0.9;
}

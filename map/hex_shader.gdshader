shader_type canvas_item;
render_mode unshaded;

uniform vec4 outline_color : source_color = vec4(0.20, 0.12, 0.04, 1.0);

// 外层六边形（SVG 第一层 path）
const vec2 V0 = vec2(34.0, 0.5727726);
const vec2 V1 = vec2(0.5, 19.293362);
const vec2 V2 = vec2(0.5, 56.706638);
const vec2 V3 = vec2(34.0, 75.42723);
const vec2 V4 = vec2(67.5, 56.706638);
const vec2 V5 = vec2(67.5, 19.293362);

// 内层六边形（SVG 第二层 path）
const vec2 I0 = vec2(34.0, 1.1455536);
const vec2 I1 = vec2(1.0, 19.586727);
const vec2 I2 = vec2(1.0, 56.413273);
const vec2 I3 = vec2(34.0, 74.854446);
const vec2 I4 = vec2(67.0, 56.413273);
const vec2 I5 = vec2(67.0, 19.586727);


float cross2d(vec2 a, vec2 b) {
	return a.x * b.y - a.y * b.x;
}


float distance_to_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}


bool inside_hex(vec2 p, vec2 a, vec2 b, vec2 c, vec2 d, vec2 e, vec2 f) {
	if (cross2d(b - a, p - a) > 0.0) return false;
	if (cross2d(c - b, p - b) > 0.0) return false;
	if (cross2d(d - c, p - c) > 0.0) return false;
	if (cross2d(e - d, p - d) > 0.0) return false;
	if (cross2d(f - e, p - e) > 0.0) return false;
	if (cross2d(a - f, p - f) > 0.0) return false;
	return true;
}


float hex_distance(vec2 p, vec2 a, vec2 b, vec2 c, vec2 d, vec2 e, vec2 f) {
	float d0 = distance_to_segment(p, a, b);
	float d1 = distance_to_segment(p, b, c);
	float d2 = distance_to_segment(p, c, d);
	float d3 = distance_to_segment(p, d, e);
	float d4 = distance_to_segment(p, e, f);
	float d5 = distance_to_segment(p, f, a);
	float dist = min(min(min(d0, d1), min(d2, d3)), min(d4, d5));
	return inside_hex(p, a, b, c, d, e, f) ? -dist : dist;
}


void fragment() {
	vec2 p = UV * vec2(68.0, 76.0);

	float outer_d = hex_distance(p, V0, V1, V2, V3, V4, V5);
	float inner_d = hex_distance(p, I0, I1, I2, I3, I4, I5);

	float aa = fwidth(outer_d);

	float outer = 1.0 - smoothstep(0.0, aa, outer_d);
	float inner = 1.0 - smoothstep(0.0, aa, inner_d);

	vec4 tex = texture(TEXTURE, UV);
	COLOR = mix(outline_color, tex, inner);
	COLOR.a *= outer;
}

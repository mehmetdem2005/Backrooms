// Kir decal shader'ı (MultiMesh quad'lar için) — siyah arka planı şeffaf yapar.
// Kir dokusu siyah üstüne kahve olduğundan, alfa = parlaklık (siyah = görünmez).
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float alpha_boost : hint_range(0.5, 4.0) = 1.8;
uniform float rough : hint_range(0.0, 1.0) = 0.85;
uniform float renk_boost : hint_range(0.5, 3.0) = 1.3;

void fragment() {
	vec4 c = texture(tex, UV);
	float a = clamp(max(c.r, max(c.g, c.b)) * alpha_boost, 0.0, 1.0);
	ALBEDO = clamp(c.rgb * renk_boost, vec3(0.0), vec3(1.0));
	ALPHA = a;
	ROUGHNESS = rough;
	METALLIC = 0.0;
}

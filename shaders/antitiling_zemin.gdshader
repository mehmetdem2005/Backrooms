// Anti-tiling zemin shader'ı (Godot 4, Mobile renderer uyumlu).
// 6 PBR haritasını AYNI UV ile örnekler (hepsi entegre, birlikte hizalı).
// Tekrar eden ızgara görünümünü kırmak için:
//   • büyük ölçekli (dünya-uzayı) gürültüyle makro parlaklık/kir varyasyonu,
//   • hafif UV bükme -> birebir tekrar olmaz.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D tex_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_rough : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_metal : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_ao : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform float normal_scale : hint_range(0.0, 2.0) = 1.0;
uniform float macro_amount : hint_range(0.0, 1.0) = 0.45;   // tekrar kırma şiddeti
uniform float macro_scale = 0.12;                            // dünya birimi başına frekans
uniform float warp_amount : hint_range(0.0, 0.3) = 0.06;     // UV bükme miktarı

varying vec3 v_wpos;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
float fbm(vec2 p) {
	return vnoise(p) * 0.6 + vnoise(p * 2.03) * 0.3 + vnoise(p * 4.01) * 0.1;
}

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 wuv = v_wpos.xz;
	float macro = fbm(wuv * macro_scale);

	// Hafif UV bükme: ızgara birebir tekrar etmesin
	vec2 warp = (vec2(fbm(wuv * macro_scale * 0.5),
					  fbm(wuv * macro_scale * 0.5 + 13.0)) - 0.5) * warp_amount;
	vec2 uv = UV * uv_scale + warp;

	vec3 alb = texture(tex_albedo, uv).rgb;
	// Makro varyasyon: bazı geniş bölgeler daha koyu/kirli, bazıları açık
	float v = mix(1.0 - macro_amount, 1.0 + macro_amount * 0.3, macro);
	ALBEDO = alb * v;

	NORMAL_MAP = texture(tex_normal, uv).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
	ROUGHNESS = texture(tex_rough, uv).r;
	METALLIC = texture(tex_metal, uv).r;
	AO = texture(tex_ao, uv).r;
	AO_LIGHT_AFFECT = 1.0;
}

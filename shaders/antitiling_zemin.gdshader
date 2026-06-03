// Anti-tiling zemin shader'ı (Godot 4, Mobile uyumlu).
// Tekrarı KIRAR: dokuyu DÜNYA-uzayında karelere böler ve her kareyi hash'e göre
// rastgele 90° döndürür + yatay çevirir. Kare fayans simetrik olduğundan grout
// hizalı kalır ama KİR/LEKE şekilleri her karede farklılaşır -> geometrik tekrar
// gözükmez. textureGrad ile mipmap dikişleri önlenir.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D tex_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_rough : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_metal : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_ao : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform float tile_size = 4.0;                     // bir doku tekrarının dünya boyutu (m)
uniform float normal_scale : hint_range(0.0, 2.0) = 1.0;
uniform float macro_amount : hint_range(0.0, 1.0) = 0.35;
uniform float macro_scale = 0.12;
uniform bool per_tile_rotate = true;               // kare başına rastgele döndürme/çevirme

varying vec3 v_wpos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float a = hash21(i), b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0)), d = hash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
float fbm(vec2 p) { return vnoise(p) * 0.6 + vnoise(p * 2.03) * 0.3 + vnoise(p * 4.01) * 0.1; }

vec2 rot90_dir(vec2 d, int k) {
	if (k == 1) return vec2(-d.y, d.x);
	if (k == 2) return -d;
	if (k == 3) return vec2(d.y, -d.x);
	return d;
}

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 tc = v_wpos.xz / tile_size;
	vec2 cell = floor(tc);
	vec2 f = fract(tc);

	int rot = 0;
	bool flipx = false;
	if (per_tile_rotate) {
		rot = int(floor(hash21(cell) * 4.0));
		flipx = hash21(cell + 7.3) > 0.5;
	}

	// Sürekli türevler (mipmap için), aynı dönüşümle döndürülür -> dikiş yok
	vec2 ddx = dFdx(tc);
	vec2 ddy = dFdy(tc);
	if (flipx) { f.x = 1.0 - f.x; ddx.x = -ddx.x; ddy.x = -ddy.x; }
	// f'i kare merkezinde döndür
	vec2 fc = f - 0.5;
	fc = rot90_dir(fc, rot);
	f = fc + 0.5;
	ddx = rot90_dir(ddx, rot);
	ddy = rot90_dir(ddy, rot);

	vec3 alb = textureGrad(tex_albedo, f, ddx, ddy).rgb;
	float macro = fbm(v_wpos.xz * macro_scale);
	float v = mix(1.0 - macro_amount, 1.0 + macro_amount * 0.3, macro);
	ALBEDO = alb * v;

	vec3 n = textureGrad(tex_normal, f, ddx, ddy).rgb;
	vec2 nxy = n.xy * 2.0 - 1.0;
	if (flipx) nxy.x = -nxy.x;
	nxy = rot90_dir(nxy, rot);
	NORMAL_MAP = vec3(nxy * 0.5 + 0.5, n.z);
	NORMAL_MAP_DEPTH = normal_scale;

	ROUGHNESS = textureGrad(tex_rough, f, ddx, ddy).r;
	METALLIC = textureGrad(tex_metal, f, ddx, ddy).r;
	AO = textureGrad(tex_ao, f, ddx, ddy).r;
	AO_LIGHT_AFFECT = 1.0;
}

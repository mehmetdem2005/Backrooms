// Anti-tiling zemin shader'ı (Godot 4, Mobile uyumlu) — DÖNDÜRME YOK, dikiş yok.
//
// Fikir: Fayans ızgarası (grout) düzenli tekrar eder -> bu DOĞAL, dokunma.
// Yapay duran, KİRİN her karede aynı tekrarlaması. Bu yüzden:
//  • Doku dünya-uzayında hizalı/periyodik örneklenir (grout sağlam, ofset/döndürme yok).
//  • Kir KAHVERENGİ (grout gri) -> kahve bileşeninden ayrıştırılır.
//  • Büyük ölçekli, çok-oktavlı, TEKRARSIZ gürültüyle kir yerelde temizlenir/derinleşir.
//    Böylece kir düzensiz büyük lekeler halinde olur; tekrarlayan kare deseni gözükmez.
//  • Grout gri olduğu için temizlemeden etkilenmez -> kenar çizgileri her yerde tutarlı.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D tex_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_rough : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_metal : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_ao : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform float tile_size = 4.0;                 // bir doku tekrarının dünya boyutu (m)
uniform float normal_scale : hint_range(0.0, 2.0) = 1.0;
uniform float grime_scale = 0.13;              // leke alanı frekansı (düşük = büyük lekeler)
uniform float grime_amount : hint_range(0.0, 1.0) = 0.75;  // ne kadar bölge temizlensin
uniform float dirt_select : hint_range(0.5, 6.0) = 3.0;    // kahve-kir ayrışma keskinliği
uniform vec3 clean_tile_color : source_color = vec3(0.74, 0.73, 0.70);

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
float fbm(vec2 p) {
	float s = 0.0, a = 0.5;
	for (int i = 0; i < 5; i++) { s += a * vnoise(p); p = p * 2.03 + 7.1; a *= 0.5; }
	return s;
}

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Hizalı, periyodik UV (dünya-uzayı) -> grout düzgün, döndürme/ofset YOK
	vec2 uv = v_wpos.xz / tile_size;

	vec3 alb = texture(tex_albedo, uv).rgb;
	// Kir = KAHVERENGİ bileşen (grout gri olduğu için ~0 -> grout korunur)
	float brown = clamp((alb.r - alb.b) * dirt_select, 0.0, 1.0);

	// Büyük ölçekli, tekrarsız kir alanı (iki decorrelated katman)
	float field = fbm(v_wpos.xz * grime_scale) * 0.7
				+ fbm(v_wpos.xz * grime_scale * 2.37 + 19.3) * 0.3;
	float keep = smoothstep(0.40, 0.72, field);          // 1 = kir kalsın, 0 = temizle
	keep = mix(1.0 - grime_amount, 1.0, keep);

	// Temiz bölgede kahve kiri fayans rengine çek (grout'a dokunmaz)
	vec3 cleanA = mix(alb, clean_tile_color, brown * 0.9);
	vec3 outA = mix(cleanA, alb, keep);
	// Kirli bölgede ekstra organik koyulaşma (yeni, tekrarsız şekiller)
	float extra = clamp((field - 0.62) * 2.5, 0.0, 1.0) * brown;
	outA *= mix(1.0, 0.7, extra);
	ALBEDO = outA;

	NORMAL_MAP = texture(tex_normal, uv).rgb;
	NORMAL_MAP_DEPTH = normal_scale * mix(0.5, 1.0, keep);  // temizde kir kabartması azalır

	float r = texture(tex_rough, uv).r;
	ROUGHNESS = mix(0.55, r, keep);                        // temiz alan daha düzgün
	METALLIC = texture(tex_metal, uv).r;
	float ao = texture(tex_ao, uv).r;
	AO = mix(mix(ao, 1.0, 0.6), ao, keep);                 // temizde AO lekesi azalır
	AO_LIGHT_AFFECT = 1.0;
}

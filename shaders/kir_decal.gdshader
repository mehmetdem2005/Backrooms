// Leke/kir decal shader'ı — siyah arka planı TAM şeffaf yapar, lekeyi ORİJİNAL
// renginde gösterir (siyah halo yok). Yüzeyin üstüne yapışan çıkartma gibi.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, diffuse_burley, specular_schlick_ggx;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float esik_min : hint_range(0.0, 0.5) = 0.05;   // bunun altı = tam şeffaf
uniform float esik_max : hint_range(0.0, 0.6) = 0.22;   // bunun üstü = tam opak
uniform float parlaklik : hint_range(0.3, 2.0) = 1.0;   // orijinal renk (1.0)
uniform float opaklik : hint_range(0.0, 1.0) = 1.0;
uniform float rough : hint_range(0.0, 1.0) = 0.8;

void fragment() {
	vec4 c = texture(tex, UV);
	float lum = max(c.r, max(c.g, c.b));
	float a = smoothstep(esik_min, esik_max, lum) * opaklik;
	ALBEDO = c.rgb * parlaklik;     // lekenin kendi rengi
	ALPHA = a;
	ROUGHNESS = rough;
	METALLIC = 0.0;
}

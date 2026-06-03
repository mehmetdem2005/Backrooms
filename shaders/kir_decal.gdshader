// Leke/kir decal — lekeyi ORİJİNAL haliyle gösterir.
//  • unshaded: sahne ışığından etkilenmez -> renk tam orijinal (kararmaz).
//  • filter_linear (mipmap YOK): uzakta/küçükken siyaha ortalanmaz.
//  • Siyah arka plan şeffaf (zorunlu; yoksa siyah kare olurdu) — başka işlem yok.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, unshaded;

uniform sampler2D tex : source_color, filter_linear;
uniform float esik_min : hint_range(0.0, 0.3) = 0.03;   // bunun altı = şeffaf (siyah bg)
uniform float esik_max : hint_range(0.0, 0.4) = 0.10;   // bunun üstü = tam görünür

void fragment() {
	vec4 c = texture(tex, UV);
	float lum = max(c.r, max(c.g, c.b));
	ALBEDO = c.rgb;                              // lekenin orijinal rengi (aynen)
	ALPHA = smoothstep(esik_min, esik_max, lum);
}

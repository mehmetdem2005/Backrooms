shader_type canvas_item;
// UYANMA POST-EFEKTI: bulanik->net, koyu->normal, goz kapagi (ust/alt) acilmasi,
// vignette + desaturasyon. Tam-ekran ColorRect uzerinde calisir (ekran dokusunu okur).

uniform float blur_amt   : hint_range(0.0, 1.0) = 1.0;  // 1=cok bulanik, 0=net
uniform float vignette   : hint_range(0.0, 1.0) = 0.0;
uniform float eyelid     : hint_range(0.0, 1.0) = 0.0;  // 0=goz kapali(siyah), 1=acik
uniform float darken     : hint_range(0.0, 1.0) = 0.0;  // ek karartma
uniform float desat      : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D ekran : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col;
	float r = blur_amt * 0.010;
	if (r > 0.0002) {
		vec3 acc = vec3(0.0);
		for (int x = -2; x <= 2; x++) {
			for (int y = -2; y <= 2; y++) {
				acc += texture(ekran, uv + vec2(float(x), float(y)) * r).rgb;
			}
		}
		col = acc / 25.0;
	} else {
		col = texture(ekran, uv).rgb;
	}
	// desaturasyon
	float g = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(g), desat);
	// karartma
	col *= (1.0 - darken);
	// vignette (kenarlar koyu)
	float d = distance(uv, vec2(0.5));
	col *= 1.0 - vignette * smoothstep(0.25, 0.85, d);
	// goz kapaklari: ust ve alttan kapanan siyah bantlar
	float cover = (1.0 - eyelid) * 0.5;
	float ust = smoothstep(cover, cover + 0.05, uv.y);
	float alt = smoothstep(1.0 - cover, 1.0 - cover - 0.05, uv.y);
	col *= ust * alt;
	COLOR = vec4(col, 1.0);
}

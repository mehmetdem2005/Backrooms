shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float time = 0.0;
uniform float fear = 0.0;
// 0 = aydınlık (fener açık), 1 = tam karanlık (fener kapalı, ışıksız)
uniform float darkness = 0.0;
// Fener kapalıyken merkezde kalan küçük görüş yarıçapı (0..1)
uniform float vision_radius = 0.62;
// Jumpscare flaşı (0..1)
uniform float flash = 0.0;
uniform float flash_dark = 0.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 center = uv - vec2(0.5);
    float dist = length(center * vec2(1.32, 1.0));

    // Temel sinematik vinyet
    float vignette = smoothstep(0.30, 0.84, dist);

    // KALİTELİ KARANLIK: fener kapalıyken kenarlar kararır ama tam siyaha gitmez;
    // merkezde gözün alıştığı dim bir görüş alanı kalır (kapkaranlık değil).
    float dark_edge = smoothstep(vision_radius * 0.5, vision_radius * 1.25, dist);
    float dark_amount = darkness * dark_edge;

    float grain = hash(uv * vec2(1280.0, 720.0) + time * 41.0) - 0.5;
    float scan = sin((uv.y + time * 0.06) * 850.0) * 0.010;
    float pulse = sin(time * 7.0) * fear * 0.045;

    // Karanlıkta hafif nefes alıp veren daralma
    float breath = sin(time * 1.4) * 0.012 * darkness;

    vec3 tint = vec3(0.95, 0.78, 0.37);
    vec3 fear_tint = vec3(0.85, 0.18, 0.12);
    tint = mix(tint, fear_tint, fear * 0.55);

    float overlay = vignette * (0.40 + fear * 0.24)
                  + max(0.0, grain) * (0.030 + darkness * 0.04)
                  + scan + pulse + breath;

    float alpha = clamp(0.09 + vignette * 0.42 + fear * 0.18 + dark_amount * 0.82 + breath, 0.0, 0.80);
    vec3 col = tint * overlay;

    // Karanlıkta koyu ama tam siyah değil (dim görüş korunur)
    col = mix(col, vec3(0.0), dark_amount * 0.6);

    // JUMPSCARE: önce kısa beyaz patlama, sonra siyah kapanış
    col = mix(col, vec3(1.0, 0.96, 0.93), flash);
    alpha = max(alpha, flash);
    col = mix(col, vec3(0.0), flash_dark);
    alpha = max(alpha, flash_dark);

    COLOR = vec4(col, alpha);
}

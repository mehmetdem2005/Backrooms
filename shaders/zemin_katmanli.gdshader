// Islak çamurlu fayans (Godot 4, Mobile uyumlu) — referans görünümü.
//  • Albedo referans dokudan (ıslak parlak fayans + kahve çamur).
//  • ISLAKLIK: temiz fayans alanı düşük roughness (parlak yansıma), çamur mat.
//  • TEKRAR KIRMA: çamur (kahve bileşen) büyük organik gürültüyle dağıtılır;
//    "temiz" bölgelerde çamur ıslak gri fayansa çekilir -> kare tekrarı gözükmez,
//    grout sabit (gri olduğu için korunur). Döndürme/ofset yok, dikiş yok.
shader_type spatial;
render_mode cull_back, specular_schlick_ggx, diffuse_burley;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;

uniform float tile_size = 4.0;
uniform float wet : hint_range(0.0, 1.0) = 0.85;            // ıslaklık (parlaklık)
uniform float mud_amount : hint_range(0.0, 1.5) = 1.0;      // çamur yoğunluğu
uniform float patch_scale = 0.11;                          // büyük leke alanı
uniform float dirt_select : hint_range(1.0, 6.0) = 3.0;     // kahve-çamur ayrışma
uniform vec3 clean_tile : source_color = vec3(0.52, 0.51, 0.47); // ıslak gri fayans
uniform float normal_scale : hint_range(0.0, 2.0) = 1.0;

varying vec3 wp;

float hash21(vec2 p){ p=fract(p*vec2(123.34,345.45)); p+=dot(p,p+34.345); return fract(p.x*p.y); }
float vnoise(vec2 p){
	vec2 i=floor(p), f=fract(p);
	float a=hash21(i), b=hash21(i+vec2(1,0)), c=hash21(i+vec2(0,1)), d=hash21(i+vec2(1,1));
	vec2 u=f*f*(3.0-2.0*f);
	return mix(mix(a,b,u.x), mix(c,d,u.x), u.y);
}
float fbm(vec2 p){ float s=0.0,a=0.5; for(int i=0;i<5;i++){ s+=a*vnoise(p); p=p*2.03+7.1; a*=0.5; } return s; }

void vertex(){ wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }

void fragment(){
	vec2 uv = wp.xz / tile_size;
	vec3 a = texture(albedo_tex, uv).rgb;
	float brown = clamp((a.r - a.b) * dirt_select, 0.0, 1.0);   // çamur (grout gri -> ~0)

	// Çamuru büyük organik gürültüyle dağıt (tekrarsız)
	float dirt = smoothstep(0.30, 0.72, fbm(wp.xz * patch_scale)) * mud_amount;
	float fb = clamp(brown * clamp(dirt * 2.0, 0.0, 1.0), 0.0, 1.0);

	vec3 cleanv = mix(a, clean_tile, brown * 0.9);   // çamuru sil -> ıslak gri fayans
	ALBEDO = mix(cleanv, a, clamp(brown * dirt * 2.2, 0.0, 1.0));

	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = normal_scale;

	// Islak fayans parlak (düşük roughness), çamur mat
	ROUGHNESS = mix(mix(0.55, 0.13, wet), 0.72, fb);
	METALLIC = 0.0;
	SPECULAR = 0.85;
}

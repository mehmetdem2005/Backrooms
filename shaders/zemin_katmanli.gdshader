// Katmanlı zemin shader'ı (Godot 4, Mobile uyumlu) — DÖNDÜRME YOK, dikiş yok.
//
// TEMİZ fayans tabanı + üstüne KİR (dirt) overlay'i.
//  • Taban dünya-uzayında hizalı/periyodik (grout düzgün, doğal).
//  • Kir, fayans ızgarasıyla ORANSIZ bir ölçekte (decorrelated) örneklenir -> kir
//    deseni ızgarayla tekrar etmez.
//  • Kir maskesi = kir-albedo'sunun parlaklığı (kir görseli siyah arka plan üstünde,
//    siyah = kir yok) × büyük ölçekli organik gürültü -> kir düzensiz büyük lekeler
//    halinde, her yerde rastgele/tekrarsız.
//  • normal/roughness/ao maskeyle harmanlanır.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Temiz fayans
uniform sampler2D base_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D base_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D base_rough : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D base_ao : hint_default_white, filter_linear_mipmap, repeat_enable;
// Kir (siyah üstüne kahve)
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_rough : hint_roughness_r, filter_linear_mipmap, repeat_enable;

uniform float tile_size = 4.0;                 // fayans ızgara boyutu (m)
uniform float dirt_size = 5.3;                 // kir ölçeği (4'e oransız = decorrelated)
uniform float dirt_amount : hint_range(0.0, 1.5) = 1.0;     // kir yoğunluğu
uniform float patch_scale = 0.10;              // büyük leke alanı (düşük = büyük)
uniform float dirt_boost : hint_range(1.0, 4.0) = 2.2;      // kir rengini parlat
uniform float dirt_roughness : hint_range(0.0, 1.0) = 0.9;  // çamur matlığı
uniform float normal_scale : hint_range(0.0, 2.0) = 1.0;

varying vec3 v_wpos;

float hash21(vec2 p){ p=fract(p*vec2(123.34,345.45)); p+=dot(p,p+34.345); return fract(p.x*p.y); }
float vnoise(vec2 p){
	vec2 i=floor(p), f=fract(p);
	float a=hash21(i), b=hash21(i+vec2(1,0)), c=hash21(i+vec2(0,1)), d=hash21(i+vec2(1,1));
	vec2 u=f*f*(3.0-2.0*f);
	return mix(mix(a,b,u.x), mix(c,d,u.x), u.y);
}
float fbm(vec2 p){ float s=0.0,a=0.5; for(int i=0;i<5;i++){ s+=a*vnoise(p); p=p*2.03+7.1; a*=0.5; } return s; }

void vertex(){ v_wpos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }

void fragment(){
	vec2 buv = v_wpos.xz / tile_size;             // fayans (hizalı, periyodik)
	vec2 duv = v_wpos.xz / dirt_size + vec2(3.7, 1.9);  // kir (decorrelated)

	vec3 bA = texture(base_albedo, buv).rgb;
	vec3 bN = texture(base_normal, buv).rgb;
	float bR = texture(base_rough, buv).r;
	float bAO = texture(base_ao, buv).r;

	vec3 dA = texture(dirt_albedo, duv).rgb;
	vec3 dN = texture(dirt_normal, duv).rgb;
	float dRv = texture(dirt_rough, duv).r;

	// Maske: kir-albedo parlaklığı (siyah=0) × büyük organik gürültü × miktar
	float dl = max(dA.r, max(dA.g, dA.b));
	dl = pow(clamp(dl * 3.0, 0.0, 1.0), 0.7);          // zayıf kiri de görünür yap
	float patch = smoothstep(0.25, 0.70, fbm(v_wpos.xz * patch_scale));
	float mask = clamp(dl * dirt_amount * mix(0.55, 1.35, patch), 0.0, 1.0);

	ALBEDO = mix(bA, clamp(dA * dirt_boost, vec3(0.0), vec3(1.0)), mask);
	NORMAL_MAP = mix(bN, dN, mask);
	NORMAL_MAP_DEPTH = normal_scale;
	ROUGHNESS = mix(bR, max(dRv, dirt_roughness), mask);
	METALLIC = 0.0;
	AO = bAO * mix(1.0, 0.82, mask);
	AO_LIGHT_AFFECT = 1.0;
}

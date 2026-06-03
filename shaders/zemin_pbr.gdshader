// 5-haritalı PBR zemin (Godot 4, Mobile uyumlu).
// albedo + normal + roughness + ao taban dokudan; DIRT MASK ayrı, BAĞIMSIZ
// (decorrelated) ölçekte örneklenip büyük organik gürültüyle karıştırılır ->
// kir taban ızgarasıyla aynı hizada tekrar etmez, her yer farklı görünür.
// Döndürme yok, dikiş yok.
shader_type spatial;
render_mode cull_back, specular_schlick_ggx, diffuse_burley;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_tex : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_mask : hint_default_black, filter_linear_mipmap, repeat_enable;

uniform float tile_size = 6.0;        // tabanın dünya boyutu (bir tam doku = kaç m)
uniform float dirt_size = 7.7;        // kir maskesi ölçeği (tabana oransız = decorrelated)
uniform float dirt_amount : hint_range(0.0, 1.5) = 0.9;
uniform float macro_scale = 0.10;
uniform vec3 dirt_color : source_color = vec3(0.32, 0.26, 0.19);  // çamur tonu
uniform float wet : hint_range(0.0, 1.0) = 0.4;   // ıslaklık (taban roughness düşür)
uniform float normal_scale : hint_range(0.0, 2.0) = 1.0;
uniform bool mirror = true;           // ayna-döşeme: kenarlar hep uyar -> dikiş çizgisi yok

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
	vec2 buv0 = wp.xz / tile_size;
	vec2 buv = buv0;
	if (mirror) {
		// üçgen dalga: 0..1..0 -> her komşu karo aynalanır, kenarlar daima eşleşir
		vec2 m = mod(buv0, 2.0);
		buv = mix(m, 2.0 - m, step(vec2(1.0), m));
	}
	// sürekli türevler (aynalama sıçramasından etkilenmez) -> mip dikişi yok
	vec2 ddx = dFdx(buv0);
	vec2 ddy = dFdy(buv0);
	vec2 duv = wp.xz / dirt_size + vec2(4.3, 1.7);

	vec3 a = textureGrad(albedo_tex, buv, ddx, ddy).rgb;
	vec3 n = textureGrad(normal_tex, buv, ddx, ddy).rgb;
	float r = textureGrad(rough_tex, buv, ddx, ddy).r;
	float ao = textureGrad(ao_tex, buv, ddx, ddy).r;

	float dm = texture(dirt_mask, duv).r;           // beyaz = kir
	float macro = fbm(wp.xz * macro_scale);
	float dirt = clamp(dm * mix(0.4, 1.35, macro) * dirt_amount, 0.0, 1.0);

	ALBEDO = mix(a, a * dirt_color * 3.0, dirt);    // kir bölgesinde çamur tonuna çek
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = normal_scale;
	ROUGHNESS = mix(r * mix(1.0, 0.55, wet), 0.8, dirt);  // taban ıslakça, çamur mat
	METALLIC = 0.0;
	SPECULAR = 0.6;
	AO = ao * mix(1.0, 0.82, dirt);
}

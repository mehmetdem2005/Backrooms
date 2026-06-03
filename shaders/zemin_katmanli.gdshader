// Stokastik ıslak çamurlu fayans (Godot 4, Mobile uyumlu) — DÖNDÜRME YOK.
//
// Doku 4x4 karo içerir. Her 1m'lik DÜNYA hücresine, hash ile o 16 karodan
// RASTGELE biri seçilir (yalnız offset, döndürme/ayna yok). Grout hücre sınırına
// denk geldiği için dikiş yok; her hücre bağımsız rastgele -> geometrik/deterministik
// tekrar gözükmez. Üstüne büyük ölçekli sürekli gürültü ile ıslaklık/çamur varyasyonu.
shader_type spatial;
render_mode cull_back, specular_schlick_ggx, diffuse_burley;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;

uniform float tile_size = 4.0;        // dokunun dünya boyutu (bir tam doku = kaç m)
uniform float grid_n = 4.0;           // doku içindeki karo sayısı (4x4)
uniform float wet : hint_range(0.0, 1.0) = 0.85;
uniform float mud_amount : hint_range(0.0, 1.5) = 0.6;
uniform float macro_scale = 0.10;     // büyük ıslak/kuru alan frekansı
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
	float csize = tile_size / grid_n;          // bir karonun dünya boyutu
	vec2 wuv = wp.xz / csize;                   // karo koordinatı (1 birim = 1 karo)
	vec2 cell = floor(wuv);
	vec2 local = fract(wuv);
	// bu hücre için 16 karodan rastgele biri (offset, döndürme YOK)
	vec2 pick = floor(vec2(hash21(cell), hash21(cell + vec2(11.0, 7.0))) * grid_n);
	vec2 uv = (pick + local) / grid_n;
	// mipmap için sürekli türevler (fract sıçramasından etkilenmez)
	vec2 ddx = dFdx(wuv) / grid_n;
	vec2 ddy = dFdy(wuv) / grid_n;

	vec3 a = textureGrad(albedo_tex, uv, ddx, ddy).rgb;
	vec3 n = textureGrad(normal_tex, uv, ddx, ddy).rgb;
	float brown = clamp((a.r - a.b) * 3.0, 0.0, 1.0);

	// büyük ölçekli sürekli varyasyon (ıslak/kuru, ekstra organik)
	float macro = fbm(wp.xz * macro_scale);
	float fb = clamp(brown * mix(0.5, 1.4, macro) * (0.5 + mud_amount), 0.0, 1.0);

	ALBEDO = a * mix(1.0, 0.82, clamp((macro - 0.5) * 1.5, 0.0, 1.0) * brown); // bazı alanlar daha koyu/kirli
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = normal_scale;
	ROUGHNESS = mix(mix(0.55, 0.13, wet), 0.72, fb);   // fayans ıslak parlak, çamur mat
	METALLIC = 0.0;
	SPECULAR = 0.85;
}

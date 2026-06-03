// Çift yüzlü duvar: ÖN yüz (+Z) tam dokulu (albedo+normal+roughness+ao),
// ARKA yüz ve kenarlar SİMSİYAH. Backrooms "void" görünümü için.
// Yön yereldir (model space) -> duvarı döndürünce ön/arka onunla döner.
// Arkayı 180° döndürerek dokulu yüzü istediğin tarafa çevirebilirsin.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_tex : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float normal_scale : hint_range(0.0, 2.0) = 1.0;

varying vec3 yerel_n;   // model-space normal (yerleştirme döndürmesinden bağımsız değil; obje ile döner)

void vertex() {
	yerel_n = NORMAL;
}

void fragment() {
	// sadece +Z yüzü dokulu; geri kalan her yüz (arka, kenarlar) siyah
	float on = step(0.5, yerel_n.z);

	ALBEDO = texture(albedo_tex, UV).rgb * on;          // arka: 0 -> difüz yok
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_scale * on;
	ROUGHNESS = mix(1.0, texture(rough_tex, UV).r, on);
	AO = mix(0.0, texture(ao_tex, UV).r, on);            // arka: 0 -> ortam ışığı da kapalı
	SPECULAR = 0.5 * on;                                 // arka: parlama yok -> tam siyah
	METALLIC = 0.0;
}

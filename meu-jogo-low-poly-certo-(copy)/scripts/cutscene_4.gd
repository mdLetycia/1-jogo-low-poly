extends Node3D

const PANORAMA := "res://assets/Galaxia.png"             # céu do espaço (planos 1 e 2)
const PANORAMA_TERRA := "res://assets/ceu.jpeg"      # TROQUE: céu da Terra (plano 3)
const CEU_TERRA_BRILHO := 1.0                            # brilho do céu da Terra
const PROXIMA := "res://scenes/mundo.tscn"      # depois vira a próxima cena
const MUSICAS := [
	"res://assets/audio/musica_queda.ogg",
	"res://assets/audio/musica_queda.mp3",
	"res://assets/audio/musica_queda.wav",
	"res://assets/audio/musica_tensa.ogg",
	"res://assets/audio/musica_tensa.mp3",
	"res://assets/audio/musica_tensa.wav",
]
const SOM_IMPACTO := "res://assets/audio/impacto.ogg"    # opcional: toca na colisão
const PLANETA_TEXTURA := "res://assets/planeta.png"       # opcional (senão, gera um planeta)

const PLANO_INICIAL := 1       # PARA TESTAR: 2 = começa no planeta, 3 = começa na queda

# duração dos planos (segundos)
const T_CEU := 5.5
const T_ENTRADA := 4.2         # planeta: tempo até a estrela tocar a atmosfera
const T_PLANETA := 6.0         # planeta: duração total do plano
const T_QUEDA := 4.8           # queda: tempo até o impacto
const PAUSA_PRETO := 3.0       # tela preta e silêncio depois do impacto
const FLASH_IMPACTO := 0.0     # segundos de clarão branco antes do preto (0 = preto direto)

# plano 1: céu
const VEL_CEU := 140.0         # velocidade da queda (m/s)

# plano 2: planeta
const PLANETA_POS := Vector3(-15, -25, -250)
const PLANETA_R := 70.0
const ATMOS_ESPESSURA := 6.0
const S2_INI := Vector3(45, 30, -120)    # de onde a estrela vem (canto superior direito)
const ESCALA_S2 := 4.0

# plano 3: queda no chão
const IMPACTO := Vector3(30, 0, -80)     # onde a estrela bate
const S3_INI := Vector3(-70, 180, -120)  # de onde ela começa a descer

const COR_FOGO := Color(1.0, 0.5, 0.15)

const CORES := {
	"feminino": Color(1.0, 0.55, 0.8),
	"masculino": Color(0.5, 0.7, 1.0),
}

const SHADER_ATMOSFERA := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec4 cor : source_color = vec4(0.35, 0.6, 1.0, 1.0);
uniform float forca = 2.5;
uniform float brilho = 1.6;
void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), forca);
	ALBEDO = cor.rgb * f * brilho;
	ALPHA = clamp(f * brilho, 0.0, 1.0);
}
"""

var camera: Camera3D
var env: Environment
var sky_espaco: Sky
var sky_terra: Sky
var sol: DirectionalLight3D
var estrela: Node3D
var bola: MeshInstance3D
var mat_estrela: StandardMaterial3D
var luz: OmniLight3D
var rastro: GPUParticles3D
var chamas: GPUParticles3D
var planeta_raiz: Node3D
var planeta: MeshInstance3D
var atmosfera: MeshInstance3D
var mat_atmos: ShaderMaterial
var chao_raiz: Node3D
var linhas_raiz: Node3D
var linhas: Array[MeshInstance3D] = []
var musica: AudioStreamPlayer
var fade: ColorRect

var tipo := "feminino"
var tempo := 0.0              # relógio geral (para o tremor)
var ts := 0.0                 # relógio do plano atual
var shot := 0
var shake := 0.0
var suave := 0.0              # > 0: a câmera segue com inércia
var linhas_vel := 0.0
var cam_pos := Vector3.ZERO
var cam_look := Vector3(0, 0, -1)
var cam_basis := Basis.IDENTITY
var s1_pos := Vector3.ZERO
var s2_atm := Vector3.ZERO
var s2_fim := Vector3.ZERO
var entrou := false
var impactou := false

func _ready() -> void:
	tipo = str(Global.dados.get("corpo", "feminino"))
	if not CORES.has(tipo):
		tipo = "feminino"
	_montar_cenario()
	_montar_planeta()
	_montar_chao()
	_criar_estrela(CORES[tipo])
	_criar_linhas()
	_montar_ui()
	_tocar_musica()
	_fade(Color.BLACK, 1.0, 0.0, 0.6)
	_iniciar_shot(PLANO_INICIAL)

# ---------------------------------------------------------------- cenário

func _criar_ceu_espaco() -> Sky:
	var sky := Sky.new()
	if ResourceLoader.exists(PANORAMA):
		var mat := PanoramaSkyMaterial.new()
		mat.panorama = load(PANORAMA)
		sky.sky_material = mat
	else:
		var p := ProceduralSkyMaterial.new()
		p.sky_top_color = Color(0.01, 0.01, 0.05)
		p.sky_horizon_color = Color(0.03, 0.03, 0.10)
		p.ground_bottom_color = Color(0.01, 0.01, 0.05)
		p.ground_horizon_color = Color(0.03, 0.03, 0.10)
		sky.sky_material = p
	return sky

# céu da Terra: outra imagem; se não achar, usa um céu noturno gerado por código
func _criar_ceu_terra() -> Sky:
	var sky := Sky.new()
	if ResourceLoader.exists(PANORAMA_TERRA):
		var mat := PanoramaSkyMaterial.new()
		mat.panorama = load(PANORAMA_TERRA)
		sky.sky_material = mat
	else:
		print("Céu da Terra não encontrado: ", PANORAMA_TERRA, " (usando um céu provisório)")
		var p := ProceduralSkyMaterial.new()
		p.sky_top_color = Color(0.02, 0.03, 0.10)
		p.sky_horizon_color = Color(0.10, 0.14, 0.28)
		p.sky_curve = 0.25
		p.ground_bottom_color = Color(0.01, 0.01, 0.03)
		p.ground_horizon_color = Color(0.10, 0.14, 0.28)
		sky.sky_material = p
	return sky

func _montar_cenario() -> void:
	sky_espaco = _criar_ceu_espaco()
	sky_terra = _criar_ceu_terra()

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky_espaco
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.2, 0.4)
	env.ambient_light_energy = 0.7
	env.fog_enabled = false
	env.fog_light_color = Color(0.06, 0.07, 0.14)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.0          # a neblina não apaga o céu
	env.glow_enabled = true
	env.glow_intensity = 1.2
	env.glow_bloom = 0.2
	env.glow_hdr_threshold = 0.8
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sol = DirectionalLight3D.new()
	sol.light_color = Color(0.85, 0.9, 1.0)
	add_child(sol)

	camera = Camera3D.new()
	camera.far = 2000.0
	add_child(camera)

func _textura_planeta() -> NoiseTexture2D:
	var ruido := FastNoiseLite.new()
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.frequency = 0.012
	ruido.fractal_octaves = 5
	ruido.seed = 11
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.42, 0.48, 0.58, 0.8, 1.0])
	g.colors = PackedColorArray([
		Color(0.02, 0.06, 0.22), Color(0.06, 0.2, 0.5), Color(0.72, 0.68, 0.42),
		Color(0.16, 0.46, 0.22), Color(0.4, 0.34, 0.3), Color(0.95, 0.95, 1.0)])
	var t := NoiseTexture2D.new()
	t.width = 1024
	t.height = 512
	t.seamless = true
	t.noise = ruido
	t.color_ramp = g
	return t

func _montar_planeta() -> void:
	planeta_raiz = Node3D.new()
	planeta_raiz.visible = false
	planeta_raiz.position = PLANETA_POS
	add_child(planeta_raiz)

	var mat := StandardMaterial3D.new()
	mat.roughness = 0.9
	if ResourceLoader.exists(PLANETA_TEXTURA):
		mat.albedo_texture = load(PLANETA_TEXTURA)
	else:
		mat.albedo_texture = _textura_planeta()
	planeta = MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = PLANETA_R
	esf.height = PLANETA_R * 2.0
	esf.radial_segments = 64
	esf.rings = 32
	planeta.mesh = esf
	planeta.material_override = mat
	planeta_raiz.add_child(planeta)

	# atmosfera: uma casca com brilho nas bordas
	atmosfera = MeshInstance3D.new()
	var ea := SphereMesh.new()
	ea.radius = PLANETA_R + ATMOS_ESPESSURA
	ea.height = (PLANETA_R + ATMOS_ESPESSURA) * 2.0
	ea.radial_segments = 64
	ea.rings = 32
	atmosfera.mesh = ea
	var sh := Shader.new()
	sh.code = SHADER_ATMOSFERA
	mat_atmos = ShaderMaterial.new()
	mat_atmos.shader = sh
	atmosfera.material_override = mat_atmos
	planeta_raiz.add_child(atmosfera)

	# pontos de entrada: onde toca a atmosfera e onde mergulha no planeta
	var para_camera := (-PLANETA_POS).normalized()
	s2_atm = PLANETA_POS + para_camera * (PLANETA_R + ATMOS_ESPESSURA)
	s2_fim = PLANETA_POS + para_camera * (PLANETA_R - 4.0)

func _montar_chao() -> void:
	chao_raiz = Node3D.new()
	chao_raiz.visible = false
	add_child(chao_raiz)

	var solo_mat := StandardMaterial3D.new()
	solo_mat.albedo_color = Color(0.05, 0.08, 0.10)
	solo_mat.roughness = 1.0
	var solo := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(900, 900)
	solo.mesh = pl
	solo.material_override = solo_mat
	chao_raiz.add_child(solo)

	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	# montanhas ao longe (silhuetas)
	var mont_mat := StandardMaterial3D.new()
	mont_mat.albedo_color = Color(0.03, 0.04, 0.07)
	mont_mat.roughness = 1.0
	for i in 40:
		var a := rng.randf() * TAU
		var d := rng.randf_range(170.0, 300.0)
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = rng.randf_range(25.0, 55.0)
		c.height = rng.randf_range(30.0, 80.0)
		c.radial_segments = 6
		var m := MeshInstance3D.new()
		m.mesh = c
		m.material_override = mont_mat
		m.position = Vector3(cos(a) * d, c.height * 0.5 - 2.0, sin(a) * d)
		chao_raiz.add_child(m)

	# árvores (cones) perto
	var arv_mat := StandardMaterial3D.new()
	arv_mat.albedo_color = Color(0.04, 0.10, 0.08)
	arv_mat.roughness = 1.0
	for i in 70:
		var a2 := rng.randf() * TAU
		var d2 := rng.randf_range(20.0, 140.0)
		var pos := Vector3(cos(a2) * d2, 0.0, sin(a2) * d2)
		if pos.distance_to(IMPACTO) < 18.0:
			continue
		var h := rng.randf_range(6.0, 13.0)
		var c2 := CylinderMesh.new()
		c2.top_radius = 0.0
		c2.bottom_radius = h * 0.28
		c2.height = h
		c2.radial_segments = 6
		var m2 := MeshInstance3D.new()
		m2.mesh = c2
		m2.material_override = arv_mat
		m2.position = Vector3(pos.x, h * 0.5, pos.z)
		chao_raiz.add_child(m2)

# ---------------------------------------------------------------- estrela e efeitos

func _criar_estrela(cor: Color) -> void:
	estrela = Node3D.new()
	add_child(estrela)

	bola = MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.6
	esf.height = 1.2
	bola.mesh = esf
	mat_estrela = StandardMaterial3D.new()
	mat_estrela.albedo_color = cor.darkened(0.5)
	mat_estrela.emission_enabled = true
	mat_estrela.emission = cor
	mat_estrela.emission_energy_multiplier = 6.0
	bola.material_override = mat_estrela
	estrela.add_child(bola)

	luz = OmniLight3D.new()
	luz.light_color = cor
	luz.omni_range = 60.0
	luz.light_energy = 3.0
	estrela.add_child(luz)

	# rastro e chamas ficam soltos no mundo (ficam para trás quando a estrela anda)
	rastro = _criar_particulas(cor.lightened(0.3), 140, 1.4, 90.0)
	estrela.add_child(rastro)
	chamas = _criar_particulas(COR_FOGO, 120, 0.9, 25.0)
	chamas.emitting = false
	estrela.add_child(chamas)

func _rampa_fade() -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	return gt

func _material_brilho(cor: Color) -> StandardMaterial3D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.albedo_color = cor
	return m

func _criar_particulas(cor: Color, qtd: int, vida: float, vel: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = qtd
	p.lifetime = vida
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-1000, -1000, -1000), Vector3(2000, 2000, 2000))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = vel * 0.05
	pm.gravity = Vector3.ZERO
	pm.scale_min = 1.0
	pm.scale_max = 2.0
	pm.color_ramp = _rampa_fade()
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	q.material = _material_brilho(cor)
	p.draw_pass_1 = q
	p.set_meta("pm", pm)
	return p

# o tamanho das partículas acompanha o tamanho da estrela
func _ajustar_particulas() -> void:
	var esc := estrela.scale.x
	var pm: ParticleProcessMaterial = rastro.get_meta("pm")
	pm.scale_min = esc * 0.7
	pm.scale_max = esc * 1.5
	var pm2: ParticleProcessMaterial = chamas.get_meta("pm")
	pm2.scale_min = esc * 0.5
	pm2.scale_max = esc * 1.2

# linhas de velocidade presas à câmera
func _criar_linhas() -> void:
	linhas_raiz = Node3D.new()
	camera.add_child(linhas_raiz)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.85, 0.92, 1.0, 0.6)
	for i in 80:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.03, 0.03, 4.0)
		m.mesh = b
		m.material_override = mat
		linhas_raiz.add_child(m)
		_reciclar_linha(m, true)
		linhas.append(m)

func _reciclar_linha(m: MeshInstance3D, inicial := false) -> void:
	var a := randf() * TAU
	var r := randf_range(2.5, 9.0)
	var z := randf_range(-60.0, -3.0) if inicial else -60.0
	m.position = Vector3(cos(a) * r, sin(a) * r, z)

func _mover_linhas(delta: float) -> void:
	for m in linhas:
		m.position.z += linhas_vel * delta
		if m.position.z > -1.0:
			_reciclar_linha(m)

# ---------------------------------------------------------------- interface e música

func _montar_ui() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 10
	add_child(camada)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _fade(cor: Color, de: float, para: float, dur: float) -> Tween:
	fade.color = Color(cor.r, cor.g, cor.b, de)
	var t := create_tween()
	t.tween_property(fade, "color:a", para, dur)
	return t

func _tocar_musica() -> void:
	musica = AudioStreamPlayer.new()
	add_child(musica)
	for caminho in MUSICAS:
		if ResourceLoader.exists(caminho):
			musica.stream = load(caminho)
			break
	if musica.stream == null:
		print("Música não encontrada. Coloque o arquivo em assets/audio/musica_queda.ogg")
		return
	musica.volume_db = -20.0
	musica.play()
	create_tween().tween_property(musica, "volume_db", 0.0, 0.8)

# ---------------------------------------------------------------- planos

func _iniciar_shot(n: int) -> void:
	shot = n
	ts = 0.0
	rastro.restart()                       # limpa o rastro do plano anterior
	planeta_raiz.visible = (n == 2)
	chao_raiz.visible = (n == 3)
	linhas_raiz.visible = (n == 1)
	env.fog_enabled = (n == 3)

	# o céu muda ao entrar na Terra: espaço (galáxia) nos planos 1 e 2, céu da Terra no 3
	if n == 3:
		env.sky = sky_terra
		env.background_energy_multiplier = CEU_TERRA_BRILHO
	else:
		env.sky = sky_espaco
		env.background_energy_multiplier = 1.0

	match n:
		1:
			suave = 0.0
			shake = 1.0
			linhas_vel = 170.0
			camera.fov = 70.0
			sol.rotation_degrees = Vector3(-35, 25, 0)
			sol.light_energy = 0.3
			estrela.scale = Vector3.ONE * 1.8
			luz.omni_range = 60.0
			luz.light_energy = 3.0
			s1_pos = Vector3.ZERO
			_p1(0.0)
		2:
			suave = 0.0
			shake = 0.25
			entrou = false
			camera.fov = 50.0
			sol.rotation_degrees = Vector3(-30, -40, 0)
			sol.light_energy = 1.8
			estrela.position = S2_INI
			estrela.scale = Vector3.ONE * ESCALA_S2
			luz.omni_range = 120.0
			luz.light_energy = 3.0
			cam_pos = Vector3.ZERO
			cam_look = PLANETA_POS
		3:
			suave = 7.0
			shake = 0.5
			impactou = false
			camera.fov = 65.0
			sol.rotation_degrees = Vector3(-55, 150, 0)
			sol.light_energy = 0.35
			estrela.position = S3_INI
			estrela.scale = Vector3.ONE * 2.5
			mat_estrela.emission = COR_FOGO
			mat_estrela.emission_energy_multiplier = 10.0
			luz.light_color = COR_FOGO
			luz.omni_range = 60.0
			luz.light_energy = 2.0
			chamas.restart()               # fogo ligado
			cam_pos = Vector3(0, 1.7, 0)
			cam_look = S3_INI
	cam_basis = Basis.looking_at(cam_look - cam_pos)

func _process(delta: float) -> void:
	tempo += delta
	ts += delta
	match shot:
		1:
			_p1(delta)
		2:
			_p2(delta)
		3:
			_p3(delta)
	if shot == 0:
		return
	if linhas_raiz.visible:
		_mover_linhas(delta)
	_ajustar_particulas()
	_atualizar_camera(delta)

# PLANO 1: a câmera segue a estrela caindo a toda velocidade
func _p1(delta: float) -> void:
	var ang := ts * 0.30
	var dir := Vector3(sin(ang) * 0.85, -0.22, -cos(ang) * 0.85).normalized()
	s1_pos += dir * VEL_CEU * delta
	estrela.position = s1_pos
	cam_pos = s1_pos - dir * 16.0 + Vector3(0.0, 3.5, 0.0)
	cam_look = s1_pos + dir * 6.0
	if ts >= T_CEU and shot == 1:
		_iniciar_shot(2)

# PLANO 2: a estrela vai até o planeta e entra na atmosfera
func _p2(delta: float) -> void:
	if not entrou:
		var u := clampf(ts / T_ENTRADA, 0.0, 1.0)
		estrela.position = S2_INI.lerp(s2_atm, pow(u, 1.5)) \
			+ Vector3(sin(ts * 9.0) * 0.15, cos(ts * 11.0) * 0.15, 0.0)
		shake = lerpf(0.25, 0.5, u)
		if u >= 1.0:
			entrou = true
			_entrar_atmosfera()
	else:
		var v := clampf((ts - T_ENTRADA) / (T_PLANETA - T_ENTRADA), 0.0, 1.0)
		estrela.position = s2_atm.lerp(s2_fim, v)
		estrela.scale = Vector3.ONE * lerpf(ESCALA_S2, ESCALA_S2 * 0.5, v)
	cam_pos = Vector3(0.0, 0.0, -ts * 1.5)          # a câmera avança devagar
	cam_look = PLANETA_POS
	planeta.rotate_y(delta * 0.03)
	if ts >= T_PLANETA and shot == 2:
		_iniciar_shot(3)

func _entrar_atmosfera() -> void:
	chamas.emitting = true
	var t := create_tween().set_parallel(true)
	t.tween_property(mat_estrela, "emission", COR_FOGO, 0.6)
	t.tween_property(luz, "light_color", COR_FOGO, 0.6)
	t.tween_property(mat_estrela, "emission_energy_multiplier", 10.0, 0.6)
	t.tween_method(_flash_atmos, 0.0, 1.0, 0.9)
	t.tween_property(self, "shake", 1.4, 0.8)

func _flash_atmos(v: float) -> void:
	var f := sin(v * PI)
	mat_atmos.set_shader_parameter("brilho", 1.6 + f * 3.5)
	mat_atmos.set_shader_parameter("cor", Color(0.35, 0.6, 1.0).lerp(COR_FOGO, f))

# PLANO 3: a bola de fogo desce pelo céu da Terra e bate no chão
func _p3(_delta: float) -> void:
	var u := clampf(ts / T_QUEDA, 0.0, 1.0)
	var uu := pow(u, 1.6)                           # acelera até o impacto
	var alvo := IMPACTO + Vector3(0.0, 0.6, 0.0)
	estrela.position = S3_INI.lerp(alvo, uu) \
		+ Vector3(sin(ts * 11.0) * 0.4, cos(ts * 13.0) * 0.4, 0.0) * (1.0 - u)
	estrela.scale = Vector3.ONE * lerpf(2.5, 10.0, uu)
	luz.light_energy = lerpf(2.0, 14.0, uu)
	luz.omni_range = lerpf(60.0, 260.0, uu)
	shake = lerpf(0.5, 1.8, uu)
	cam_pos = Vector3(0.0, 1.7, 0.0)
	cam_look = estrela.position
	if u >= 1.0 and not impactou:
		impactou = true
		_impacto()

# a estrela bate no chão: preto repentino e a música para
func _impacto() -> void:
	if musica != null:
		musica.stop()                               # a música para de uma vez
	if ResourceLoader.exists(SOM_IMPACTO):
		var som := AudioStreamPlayer.new()
		som.stream = load(SOM_IMPACTO)
		add_child(som)
		som.play()
	if FLASH_IMPACTO > 0.0:
		fade.color = Color(1, 1, 1, 1)
		await get_tree().create_timer(FLASH_IMPACTO).timeout
	fade.color = Color(0, 0, 0, 1)                  # tela preta repentina
	shot = 0                                        # congela tudo por baixo do preto
	Global.dados["cutscene4_vista"] = true
	Global.salvar()
	await get_tree().create_timer(PAUSA_PRETO).timeout
	Global.ir_para(PROXIMA)

# ---------------------------------------------------------------- câmera

func _atualizar_camera(delta: float) -> void:
	camera.position = cam_pos
	var d := cam_look - cam_pos
	if d.length() < 0.01:
		return
	var alvo := Basis.looking_at(d)
	if suave > 0.0:
		cam_basis = cam_basis.slerp(alvo, 1.0 - exp(-suave * delta))
	else:
		cam_basis = alvo
	camera.basis = cam_basis
	if shake > 0.0:                                 # tremor
		var a := shake * 0.01
		camera.rotate_object_local(Vector3.RIGHT, sin(tempo * 47.0) * a)
		camera.rotate_object_local(Vector3.UP, sin(tempo * 61.0 + 1.0) * a)
		camera.rotate_object_local(Vector3.BACK, sin(tempo * 39.0 + 2.0) * a * 1.5)

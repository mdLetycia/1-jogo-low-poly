extends Node3D

const DeusaScript := preload("res://scripts/deusa.gd")

const PANORAMA := "res://assets/Galaxia.png"
const PROXIMA := "res://scenes/cutscene_4.tscn"      # depois vira a próxima cutscene
const MUSICAS := [
	"res://assets/audio/musica_tensa.ogg",
	"res://assets/audio/musica_tensa.mp3",
	"res://assets/audio/musica_tensa.wav",
]

# --- seu santuário (se o arquivo existir, substitui a estrada provisória) ---
const SANTUARIO := "res://assets/models/santuario.glb"
const SANTUARIO_POS := Vector3.ZERO
const SANTUARIO_GIRO := 0.0
const SANTUARIO_ESCALA := 1.0
const PEDESTAL_PROVISORIO := true

# --- corrida ---
const PEDESTAL_Z := -90.0            # onde fica o pedestal; a velocidade é calculada para chegar lá
const PEDESTAL_TOPO := 1.1
const DURACAO_CORRIDA := 13.0
const Z_PARADA := PEDESTAL_Z + 1.0   # onde ela para (a 1 m do pedestal)
const VEL := -Z_PARADA / (DURACAO_CORRIDA - 0.5)
const INIMIGOS_DIST := 13.0
const COMECAR_EM := 0.0              # PARA TESTAR O ROTEIRO RÁPIDO: coloque 16.0

# --- planos de câmera da corrida (segundos) ---
const T_B := 5.0
const T_C := 8.5
const T_D := 11.8
const T_COLOCAR := 13.6
const DUR_COLOCAR := 1.6
const T_ROTEIRO := 16.0              # aqui começa o roteiro da despedida
const CAM_LADO := 4.6

const C_DIST_INI := 1.5
const C_DIST_FIM := 1.1
const C_FOV := 40.0
const C_ALTURA := 1.32

const MAOS := Vector3(0, 0.79, 0.30)

# --- roteiro ---
const YAW_PEDESTAL := 180.0          # deusa olhando para o pedestal
const YAW_ENTRADA := 360.0           # deusa olhando para a entrada (= 0 graus)
const LADO_CAM := 1.0                # troque para -1.0 para espelhar as câmeras do roteiro
const NOME_DEUSA := "Deusa"
const MOSTRAR_TOM := false           # true = mostra a direção de voz junto ao nome
const AUTO_AVANCO := 0.0             # 0 = clique para avançar; ex.: 3.0 = avança sozinho após 3 s
const CPS := 32.0                    # letras por segundo
const EST_Y := PEDESTAL_TOPO + 0.3   # altura da estrela sobre o pedestal

# brilho da estrela durante o roteiro (baixo, para não esconder o rosto dela)
const LUZ_ESTRELA := 0.9
const LUZ_PULSO := 1.8
const EMISSAO_ROTEIRO := 2.2
const GLOW_ROTEIRO := 0.55

# pontos da estrela em relação à deusa (x = lado, y = altura, z = à frente dela)
const P_TOQUE := Vector3(0.0, 1.12, 0.60)     # a estrela se inclina um pouco para ela
const P_BEIJO := Vector3(0.0, 0.90, 0.36)
const P_PEITO := Vector3(0.0, 0.52, 0.30)
const P_AFASTADA := Vector3(0.0, 0.85, 0.55)

# câmeras do roteiro (em relação à deusa)
const CAM_ROSTO := Vector3(0.95, 1.38, 0.80)    # 3/4: o rosto no centro e a estrela no canto
const ALVO_ROSTO := Vector3(0.0, 1.28, 0.05)
const CAM_PERFIL := Vector3(1.3, 1.0, 0.40)     # perfil: ela e a estrela lado a lado
const ALVO_PERFIL := Vector3(0.0, 1.0, 0.40)

const INIMIGOS_POS := [
	Vector2(-2.0, 0.0), Vector2(1.4, 1.6), Vector2(-0.6, 3.2),
	Vector2(2.2, 4.0), Vector2(-1.5, 5.4),
]

const CORES := {
	"feminino": Color(1.0, 0.55, 0.8),
	"masculino": Color(0.5, 0.7, 1.0),
}

var camera: Camera3D
var env: Environment
var lua: DirectionalLight3D
var deusa: Node3D            # posição e direção (giro)
var rig                      # a deusa articulada (deusa.gd)
var estrela: Node3D
var bola: MeshInstance3D
var mat_estrela: StandardMaterial3D
var luz: OmniLight3D
var rastro: GPUParticles3D
var marca: Sprite3D
var inimigos_raiz: Node3D
var inimigos: Array[Node3D] = []
var olhos_pares: Array[Node3D] = []
var mat_olho_longe: StandardMaterial3D
var musica: AudioStreamPlayer

var fade: ColorRect
var caixa: Control
var nome_label: Label
var fala_label: Label
var seta: Label

var tipo := "feminino"
var tl := 0.0
var rodando := false
var plano := ""
var colocada := false
var flutua := false
var estrela_alvo := Vector3.ZERO
var roteiro_iniciado := false
var clique := false

var ofego := 1.0                     # 1 = muito ofegante, 0 = calma
var ceu_brilho := 0.0: set = _set_ceu_brilho

var cam_ctrl := false                # o roteiro controla a câmera
var cam_seguir := false              # câmera acompanha a estrela
var cam_alvo := Vector3.ZERO
var _cam_tween: Tween

func _ready() -> void:
	tipo = str(Global.dados.get("corpo", "feminino"))
	if not CORES.has(tipo):
		tipo = "feminino"
	tl = COMECAR_EM
	_montar_cenario()
	_montar_templo()
	_criar_deusa()
	_criar_estrela(CORES[tipo])
	_criar_inimigos()
	_montar_ui()
	_tocar_musica()
	rodando = true
	_fade(Color.BLACK, 1.0, 0.0, 1.5)

# ---------------------------------------------------------------- cenário

func _montar_cenario() -> void:
	env = Environment.new()
	if ResourceLoader.exists(PANORAMA):
		var mat := PanoramaSkyMaterial.new()
		mat.panorama = load(PANORAMA)
		var sky := Sky.new()
		sky.sky_material = mat
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.background_energy_multiplier = 0.6
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.02, 0.02, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.2, 0.4)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.12, 0.08, 0.2)
	env.fog_density = 0.02
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	lua = DirectionalLight3D.new()
	lua.rotation_degrees = Vector3(-50, -30, 0)
	lua.light_color = Color(0.6, 0.7, 1.0)
	lua.light_energy = 0.4
	add_child(lua)

	camera = Camera3D.new()
	camera.far = 500.0
	add_child(camera)

func _set_ceu_brilho(v: float) -> void:
	ceu_brilho = v
	if env == null:
		return
	env.background_energy_multiplier = 0.6 + v * 1.0
	env.ambient_light_energy = 0.6 + v * 1.2
	if lua != null:
		lua.light_energy = 0.4 + v * 0.8

func _montar_templo() -> void:
	var pedra := StandardMaterial3D.new()
	pedra.albedo_color = Color(0.32, 0.30, 0.36)
	pedra.roughness = 0.9

	if ResourceLoader.exists(SANTUARIO):
		var cena_s: PackedScene = load(SANTUARIO)
		var s: Node3D = cena_s.instantiate()
		s.position = SANTUARIO_POS
		s.rotation_degrees.y = SANTUARIO_GIRO
		s.scale = Vector3.ONE * SANTUARIO_ESCALA
		add_child(s)
	else:
		var chao := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(10.0, 0.4, 60.0 - PEDESTAL_Z)
		chao.mesh = bx
		chao.material_override = pedra
		chao.position = Vector3(0, -0.2, PEDESTAL_Z / 2.0)
		add_child(chao)

		var i := 0
		var z := 24.0
		while z > PEDESTAL_Z - 8.0:
			for lado in [-1.0, 1.0]:
				var col := MeshInstance3D.new()
				var cil := CylinderMesh.new()
				cil.top_radius = 0.4
				cil.bottom_radius = 0.45
				cil.height = 7.0
				cil.radial_segments = 10
				col.mesh = cil
				col.material_override = pedra
				col.position = Vector3(6.0 * lado, 3.5, z)
				add_child(col)
				if i % 3 == 0:
					_tocha(Vector3(5.3 * lado, 3.2, z))
			z -= 6.0
			i += 1

	if PEDESTAL_PROVISORIO:
		var caminho := "res://assets/models/pedestal.glb"
		var ped: Node3D
		if ResourceLoader.exists(caminho):
			var cena: PackedScene = load(caminho)
			ped = cena.instantiate()
		else:
			ped = _pedestal_provisorio(pedra)
		ped.position = Vector3(0, 0, PEDESTAL_Z)
		add_child(ped)

func _tocha(pos: Vector3) -> void:
	var fogo := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.14
	esf.height = 0.28
	fogo.mesh = esf
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.2)
	mat.emission_energy_multiplier = 3.0
	fogo.material_override = mat
	fogo.position = pos
	add_child(fogo)

	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.3)
	l.omni_range = 9.0
	l.light_energy = 1.2
	l.position = pos
	add_child(l)

func _pedestal_provisorio(mat: Material) -> Node3D:
	var raiz := Node3D.new()
	var partes := [
		[0.55, 0.3, 0.15],
		[0.28, 0.7, 0.65],
		[0.50, 0.1, 1.05],
	]
	for p in partes:
		var m := MeshInstance3D.new()
		var cil := CylinderMesh.new()
		cil.top_radius = p[0]
		cil.bottom_radius = p[0]
		cil.height = p[1]
		cil.radial_segments = 10
		m.mesh = cil
		m.material_override = mat
		m.position.y = p[2]
		raiz.add_child(m)
	return raiz

# ---------------------------------------------------------------- personagens

func _criar_deusa() -> void:
	deusa = Node3D.new()
	deusa.rotation_degrees.y = YAW_PEDESTAL     # de frente para -Z (rumo ao pedestal)
	add_child(deusa)
	rig = DeusaScript.new()
	deusa.add_child(rig)
	rig.expressao("desespero", 0.0)

	# luz suave só para o rosto dela: a estrela nunca "apaga" o rosto
	var luz_rosto := OmniLight3D.new()
	luz_rosto.light_color = Color(1.0, 0.92, 0.85)
	luz_rosto.omni_range = 3.5
	luz_rosto.light_energy = 0.7
	luz_rosto.position = Vector3(0.9, 1.5, 0.8)
	deusa.add_child(luz_rosto)

func _criar_estrela(cor: Color) -> void:
	# a estrela nasce nas mãos dela (filha do corpo, então acompanha a corrida)
	estrela = Node3D.new()
	rig.add_child(estrela)
	estrela.position = MAOS
	estrela.scale = Vector3.ONE * 0.12

	bola = MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.6
	esf.height = 1.2
	bola.mesh = esf
	mat_estrela = StandardMaterial3D.new()
	mat_estrela.albedo_color = cor.darkened(0.5)
	mat_estrela.emission_enabled = true
	mat_estrela.emission = cor
	mat_estrela.emission_energy_multiplier = 4.0
	bola.material_override = mat_estrela
	estrela.add_child(bola)

	luz = OmniLight3D.new()
	luz.light_color = cor
	luz.omni_range = 6.0
	luz.light_energy = 2.0
	estrela.add_child(luz)

	var t := create_tween().set_loops()
	t.tween_property(bola, "scale", Vector3.ONE * 1.15, 0.6).set_trans(Tween.TRANS_SINE)
	t.tween_property(bola, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_SINE)

	rastro = _criar_rastro(cor)
	estrela.add_child(rastro)

	# marca lunar (aparece na testa da criança; desenhada por cima, de qualquer ângulo)
	marca = Sprite3D.new()
	marca.texture = _textura_lua()
	marca.pixel_size = 0.0035
	marca.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marca.shaded = false
	marca.no_depth_test = true
	marca.modulate = Color(2.0, 1.8, 1.0, 0.0)
	marca.position = Vector3(0, 0.22, 0)
	estrela.add_child(marca)

func _textura_lua() -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n * 0.5, n * 0.5)
	var c2 := c + Vector2(n * 0.16, -n * 0.06)
	for yy in n:
		for xx in n:
			var p := Vector2(xx, yy)
			var a1 := clampf((n * 0.36 - p.distance_to(c)) / 2.0, 0.0, 1.0)
			var a2 := clampf((p.distance_to(c2) - n * 0.30) / 2.0, 0.0, 1.0)
			img.set_pixel(xx, yy, Color(1, 1, 1, minf(a1, a2)))
	return ImageTexture.create_from_image(img)

# ---------- partículas ----------

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

func _rampa_pisca() -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.5, Color(1, 1, 1, 1))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	return gt

func _criar_particulas_ambiente() -> void:
	var p := GPUParticles3D.new()
	p.amount = 90
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.visibility_aabb = AABB(Vector3(-20, -10, -20), Vector3(40, 30, 40))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(6.0, 2.0, 7.0)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.25
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.4
	pm.scale_max = 1.2
	pm.color_ramp = _rampa_pisca()
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	q.material = _material_brilho(Color(1.0, 0.9, 0.6))
	p.draw_pass_1 = q
	p.position = Vector3(0.0, 2.0, Z_PARADA)
	add_child(p)

func _criar_rastro(cor: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 70
	p.lifetime = 1.4
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-80, -80, -80), Vector3(160, 160, 160))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.15
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.3
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	pm.color_ramp = _rampa_pisca()
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.3, 0.3)
	q.material = _material_brilho(cor.lightened(0.3))
	p.draw_pass_1 = q
	return p

# ---------- inimigos da corrida ----------

func _criar_inimigos() -> void:
	inimigos_raiz = Node3D.new()
	inimigos_raiz.visible = false
	add_child(inimigos_raiz)

	var caminho := "res://assets/models/inimigo.glb"
	var cena: PackedScene = null
	if ResourceLoader.exists(caminho):
		cena = load(caminho)

	var sombra := StandardMaterial3D.new()
	sombra.albedo_color = Color(0.02, 0.0, 0.04)
	sombra.roughness = 1.0

	var olho_mat := StandardMaterial3D.new()
	olho_mat.albedo_color = Color(1.0, 0.1, 0.1)
	olho_mat.emission_enabled = true
	olho_mat.emission = Color(1.0, 0.1, 0.1)
	olho_mat.emission_energy_multiplier = 5.0

	for i in INIMIGOS_POS.size():
		var e := Node3D.new()
		e.rotation_degrees = Vector3(14.0, 180.0, 0.0)
		e.scale = Vector3.ONE * (0.9 + 0.1 * (i % 3))
		if cena != null:
			e.add_child(cena.instantiate())
		else:
			_inimigo_provisorio(e, sombra, olho_mat)

		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.1, 0.1)
		l.omni_range = 3.0
		l.light_energy = 0.6
		l.position = Vector3(0, 1.9, 0.3)
		e.add_child(l)

		inimigos_raiz.add_child(e)
		inimigos.append(e)

func _inimigo_provisorio(e: Node3D, sombra: Material, olho_mat: Material) -> void:
	var corpo := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.32
	cap.height = 1.7
	cap.radial_segments = 8
	cap.rings = 2
	corpo.mesh = cap
	corpo.material_override = sombra
	corpo.position.y = 0.85
	e.add_child(corpo)

	var cab := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.24
	esf.height = 0.48
	esf.radial_segments = 8
	esf.rings = 4
	cab.mesh = esf
	cab.material_override = sombra
	cab.position.y = 1.95
	e.add_child(cab)

	for lado in [-1.0, 1.0]:
		var olho := MeshInstance3D.new()
		var eo := SphereMesh.new()
		eo.radius = 0.045
		eo.height = 0.09
		eo.radial_segments = 6
		eo.rings = 3
		olho.mesh = eo
		olho.material_override = olho_mat
		olho.position = Vector3(0.09 * lado, 1.98, 0.21)
		e.add_child(olho)

		var braco := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(0.1, 0.1, 0.9)
		braco.mesh = bb
		braco.material_override = sombra
		braco.position = Vector3(0.35 * lado, 1.3, 0.5)
		e.add_child(braco)

# ---------- olhos vermelhos ao longe (na entrada) ----------

func _gerar_olhos(n: int) -> void:
	if mat_olho_longe == null:
		mat_olho_longe = StandardMaterial3D.new()
		mat_olho_longe.albedo_color = Color(1.0, 0.1, 0.1)
		mat_olho_longe.emission_enabled = true
		mat_olho_longe.emission = Color(1.0, 0.1, 0.1)
		mat_olho_longe.emission_energy_multiplier = 6.0
	for i in n:
		var par := Node3D.new()
		par.position = Vector3(randf_range(-3.5, 3.5), randf_range(0.9, 2.1), Z_PARADA + randf_range(22.0, 38.0))
		for lado in [-1.0, 1.0]:
			var m := MeshInstance3D.new()
			var e := SphereMesh.new()
			e.radius = 0.07
			e.height = 0.14
			e.radial_segments = 6
			e.rings = 3
			m.mesh = e
			m.material_override = mat_olho_longe
			m.position = Vector3(0.14 * lado, 0.0, 0.0)
			par.add_child(m)
		par.scale = Vector3.ZERO
		add_child(par)
		olhos_pares.append(par)
		var t := create_tween()
		t.tween_interval(randf() * 1.2)
		t.tween_property(par, "scale", Vector3.ONE, 0.5)

func _apagar_olhos(dur: float) -> void:
	for par in olhos_pares:
		var t := create_tween()
		t.tween_property(par, "scale", Vector3.ZERO, dur)
		t.tween_callback(par.queue_free)
	olhos_pares.clear()

# ---------------------------------------------------------------- interface e música

func _montar_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)

	caixa = Control.new()
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.visible = false
	ui.add_child(caixa)
	caixa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.65)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_child(fundo)
	_ancorar(fundo, 1.0, 120, -120, -310, -60)

	nome_label = Label.new()
	nome_label.add_theme_font_size_override("font_size", 38)
	nome_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	caixa.add_child(nome_label)
	_ancorar(nome_label, 1.0, 160, -160, -295, -240)

	fala_label = Label.new()
	fala_label.add_theme_font_size_override("font_size", 42)
	fala_label.add_theme_color_override("font_outline_color", Color.BLACK)
	fala_label.add_theme_constant_override("outline_size", 6)
	fala_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caixa.add_child(fala_label)
	_ancorar(fala_label, 1.0, 160, -160, -235, -105)

	seta = Label.new()
	seta.text = "Clique para continuar"
	seta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	seta.add_theme_font_size_override("font_size", 26)
	seta.modulate = Color(1, 1, 1, 0.7)
	seta.visible = false
	caixa.add_child(seta)
	_ancorar(seta, 1.0, 160, -160, -105, -65)

	var camada := CanvasLayer.new()
	camada.layer = 10
	add_child(camada)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _ancorar(c: Control, ancora_v: float, esq: float, dir: float, topo: float, base: float) -> void:
	c.anchor_left = 0.0
	c.anchor_right = 1.0
	c.anchor_top = ancora_v
	c.anchor_bottom = ancora_v
	c.offset_left = esq
	c.offset_right = dir
	c.offset_top = topo
	c.offset_bottom = base

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
		print("Música não encontrada. Coloque o arquivo em assets/audio/musica_tensa.ogg")
		return
	musica.volume_db = -40.0
	musica.play()
	create_tween().tween_property(musica, "volume_db", 0.0, 2.5)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		clique = true
	elif event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
		clique = true

# ---------------------------------------------------------------- relógio da cena

func _process(delta: float) -> void:
	if not rodando:
		return
	tl += delta
	_atualizar_deusa()
	_atualizar_inimigos()
	_atualizar_estrela()
	if tl >= T_ROTEIRO and not roteiro_iniciado:
		roteiro_iniciado = true
		_roteiro()
	_atualizar_camera()

func _z_deusa(t: float) -> float:
	var t_freio := DURACAO_CORRIDA - 1.0
	if t <= t_freio:
		return -VEL * t
	var u := clampf(t - t_freio, 0.0, 1.0)
	return -(VEL * t_freio + VEL * u - 0.5 * VEL * u * u)

func _atualizar_deusa() -> void:
	deusa.position = Vector3(0.0, 0.0, _z_deusa(tl))

	var vel := 0.0
	var t_freio := DURACAO_CORRIDA - 1.0
	if tl <= t_freio:
		vel = 1.0
	elif tl < DURACAO_CORRIDA:
		vel = 1.0 - (tl - t_freio)

	var ciclo := tl * 9.0
	var r := sin(tl * 7.0)
	var p := clampf((tl - T_COLOCAR) / DUR_COLOCAR, 0.0, 1.0)
	var inclina := 14.0 * sin(p * PI) + (6.0 + r * 2.0) * ofego

	rig.position.y = absf(sin(ciclo)) * 0.12 * vel
	rig.rotation_degrees = Vector3(lerpf(inclina, 12.0, vel), 0.0, sin(ciclo) * 3.0 * vel)
	var resp := (1.0 - vel) * (0.35 + 0.65 * ofego)
	rig.scale = Vector3(1.0 + r * 0.008 * resp, 1.0 + r * 0.014 * resp, 1.0)
	rig.arfar = lerpf(ofego, 1.0, vel)

func _atualizar_inimigos() -> void:
	var base := _z_deusa(tl) + INIMIGOS_DIST - 0.12 * tl
	for i in inimigos.size():
		var p: Vector2 = INIMIGOS_POS[i]
		var ciclo := tl * 8.5 + i * 1.7
		inimigos[i].position = Vector3(
			p.x + sin(tl * 1.3 + i) * 0.3,
			absf(sin(ciclo)) * 0.14,
			base + p.y)

func _atualizar_estrela() -> void:
	if flutua:
		estrela.position.y = estrela_alvo.y + sin(tl * 2.0) * 0.03
	elif tl >= T_COLOCAR and not colocada:
		colocada = true
		_colocar_estrela()

func _colocar_estrela() -> void:
	estrela_alvo = Vector3(0.0, PEDESTAL_TOPO + 0.3, PEDESTAL_Z)
	estrela.reparent(self, true)
	var ini := estrela.position
	var t := create_tween()
	t.tween_method(_passo_colocar.bind(ini, estrela_alvo), 0.0, 1.0, DUR_COLOCAR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	flutua = true
	var g := create_tween().set_parallel(true)
	g.tween_property(estrela, "scale", Vector3.ONE * 0.3, 1.2)
	g.tween_property(luz, "light_energy", LUZ_ESTRELA, 1.2)
	g.tween_property(luz, "omni_range", 3.0, 1.2)
	g.tween_property(mat_estrela, "emission_energy_multiplier", EMISSAO_ROTEIRO, 1.2)

func _passo_colocar(v: float, ini: Vector3, fim: Vector3) -> void:
	estrela.position = ini.lerp(fim, v) + Vector3(0.0, sin(v * PI) * 0.25, 0.0)

# baixa o brilho da estrela e da tela para o rosto dela aparecer durante o roteiro
func _suavizar_brilho() -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(luz, "light_energy", LUZ_ESTRELA, 1.0)
	t.tween_property(luz, "omni_range", 3.0, 1.0)
	t.tween_property(mat_estrela, "emission_energy_multiplier", EMISSAO_ROTEIRO, 1.0)
	t.tween_property(env, "glow_intensity", GLOW_ROTEIRO, 1.0)
	t.tween_property(env, "glow_bloom", 0.04, 1.0)

# ---------------------------------------------------------------- câmera da corrida

func _atualizar_camera() -> void:
	if cam_ctrl:
		if cam_seguir and estrela.visible:
			camera.look_at(estrela.global_position)
		return

	var novo := "A"
	if tl >= T_D:
		novo = "D"
	elif tl >= T_C:
		novo = "C"
	elif tl >= T_B:
		novo = "B"
	if novo != plano:
		plano = novo
		inimigos_raiz.visible = (plano == "B")

	var gz := _z_deusa(tl)
	var tx := sin(tl * 37.0)
	var ty := sin(tl * 29.0 + 1.0)
	var z_meio := PEDESTAL_Z + 0.5

	match plano:
		"A":
			camera.fov = 60.0
			camera.position = Vector3(sin(tl * 0.7) * 0.5 + tx * 0.015, 1.2 + ty * 0.02, gz - 4.2)
			camera.look_at(Vector3(0.0, 1.1, gz))
		"B":
			var pz := gz + INIMIGOS_DIST - 0.12 * tl + 2.8
			camera.fov = 65.0
			camera.position = Vector3(CAM_LADO, 1.3 + ty * 0.03, pz + tx * 0.03)
			camera.look_at(Vector3(0.0, 0.9, pz))
		"C":
			var u := clampf((tl - T_C) / (T_D - T_C), 0.0, 1.0)
			var dist := lerpf(C_DIST_INI, C_DIST_FIM, u)
			camera.fov = C_FOV
			camera.position = Vector3(0.1 + tx * 0.008, C_ALTURA + 0.03 + ty * 0.008, gz - dist)
			camera.look_at(Vector3(0.0, C_ALTURA, gz - 0.1))
		"D":
			camera.fov = 60.0
			camera.position = Vector3(CAM_LADO, 1.35, z_meio)
			camera.look_at(Vector3(0.0, 1.1, z_meio))

# ---------------------------------------------------------------- ferramentas do roteiro

func _esperar(s: float) -> void:
	await get_tree().create_timer(s).timeout

# ponto no mundo a partir de uma posição "local" da deusa e da direção (yaw) em que ela olha
func _L(local: Vector3, yaw: float) -> Vector3:
	var l := Vector3(local.x * LADO_CAM, local.y, local.z)
	return Vector3(0.0, 0.0, Z_PARADA) + Basis(Vector3.UP, deg_to_rad(yaw)) * l

func _girar(yaw: float, dur: float) -> Tween:
	var t := create_tween()
	t.tween_property(deusa, "rotation_degrees:y", yaw, dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return t

# corte seco de câmera
func _corte(pos: Vector3, alvo: Vector3, fov: float) -> void:
	if _cam_tween != null:
		_cam_tween.kill()
	cam_seguir = false
	camera.position = pos
	camera.fov = fov
	camera.look_at(alvo)
	cam_alvo = alvo

# movimento suave de câmera
func _mover_cam(pos: Vector3, alvo: Vector3, fov: float, dur: float) -> void:
	if _cam_tween != null:
		_cam_tween.kill()
	cam_seguir = false
	_cam_tween = create_tween()
	_cam_tween.tween_method(
		_passo_cam.bind(camera.position, cam_alvo, camera.fov, pos, alvo, fov),
		0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _passo_cam(v: float, p0: Vector3, a0: Vector3, f0: float, p1: Vector3, a1: Vector3, f1: float) -> void:
	var a := a0.lerp(a1, v)
	camera.position = p0.lerp(p1, v)
	camera.fov = lerpf(f0, f1, v)
	camera.look_at(a)
	cam_alvo = a

# a estrela voa até um ponto (e muda de tamanho); depois volta a flutuar
func _est_para(pos: Vector3, dur: float, esc := -1.0) -> Tween:
	flutua = false
	var t := create_tween().set_parallel(true)
	t.tween_property(estrela, "position", pos, dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if esc > 0.0:
		t.tween_property(estrela, "scale", Vector3.ONE * esc, dur)
	t.finished.connect(func():
		estrela_alvo = pos
		flutua = true
	)
	return t

func _estrela_pulsa() -> void:
	var t := create_tween()
	t.tween_property(luz, "light_energy", LUZ_PULSO, 0.4)
	t.tween_property(luz, "light_energy", LUZ_ESTRELA, 0.9)

func _mostrar_marca() -> void:
	create_tween().tween_property(marca, "modulate:a", 1.0, 1.6)

func _balancar_cabeca() -> void:
	var t := create_tween()
	t.tween_property(rig, "cab_yaw", 8.0, 0.45)
	t.tween_property(rig, "cab_yaw", -8.0, 0.8)
	t.tween_property(rig, "cab_yaw", 0.0, 0.45)

# fala com texto digitando, boca mexendo e clique para avançar
func _fala(texto: String, tom := "") -> void:
	var nome := NOME_DEUSA
	if MOSTRAR_TOM and tom != "":
		nome += " (" + tom + ")"
	nome_label.text = nome
	fala_label.text = texto
	fala_label.visible_ratio = 0.0
	caixa.visible = true
	rig.falar(true)
	clique = false
	var dur := maxf(0.6, texto.length() / CPS)
	var t := create_tween()
	t.tween_property(fala_label, "visible_ratio", 1.0, dur)
	while t.is_running():
		if clique:
			t.kill()
			fala_label.visible_ratio = 1.0
			break
		await get_tree().process_frame
	rig.falar(false)
	seta.visible = true
	await _esperar_avanco()
	seta.visible = false
	caixa.visible = false

func _esperar_avanco() -> void:
	clique = false
	var t0 := 0.0
	while not clique:
		await get_tree().process_frame
		t0 += get_process_delta_time()
		if AUTO_AVANCO > 0.0 and t0 >= AUTO_AVANCO:
			break

# ---------------------------------------------------------------- O ROTEIRO

func _roteiro() -> void:
	cam_ctrl = true
	_suavizar_brilho()
	_criar_particulas_ambiente()
	var y := YAW_PEDESTAL

	# ---------- foco na estrela, depois no rosto dela ----------
	_corte(Vector3(1.5, 1.55, PEDESTAL_Z + 1.1), Vector3(0.0, EST_Y, PEDESTAL_Z), 42.0)
	_mover_cam(Vector3(0.9, 1.5, PEDESTAL_Z + 0.55), Vector3(0.0, EST_Y, PEDESTAL_Z), 32.0, 3.6)
	await _esperar(3.8)

	_corte(_L(Vector3(0.75, 1.40, 0.95), y), _L(Vector3(0.0, 1.32, 0.0), y), 36.0)
	await _esperar(2.6)                                    # ainda ofegante, aflita
	rig.expressao("alivio", 1.0)
	create_tween().tween_property(self, "ofego", 0.3, 2.5)
	await _esperar(2.0)
	rig.expressao("sorriso", 1.2)                          # ela sorri
	await _esperar(2.6)

	# ================= ATO I — A PROTETORA =================
	_gerar_olhos(3)                                        # sombras ao longe, na entrada
	await _esperar(1.0)
	rig.expressao("neutra", 0.7)                           # o sorriso desaparece
	await _esperar(0.5)
	await rig.mover({"cab_yaw": 55.0}, 1.0).finished       # vira a cabeça...
	var giro := _girar(YAW_ENTRADA, 1.8)                   # ...e depois o corpo
	rig.mover({"cab_yaw": 0.0, "tronco_pitch": 0.0}, 1.8)
	rig.expressao("firme", 1.4)
	rig.pose_bracos("relaxado", 1.4)
	create_tween().tween_property(self, "ofego", 0.0, 1.6) # postura ereta e imponente
	await giro.finished
	y = YAW_ENTRADA
	# plano médio, aproximando-se lentamente do rosto
	_corte(_L(Vector3(0.5, 1.42, 3.2), y), _L(Vector3(0.0, 1.36, 0.0), y), 45.0)
	_mover_cam(_L(Vector3(0.3, 1.40, 1.25), y), _L(Vector3(0.0, 1.34, 0.0), y), 36.0, 7.0)
	await _fala("Vocês não deveriam ter entrado no MEU Santuário.", "voz firme, grave e autoritária")

	# por cima do ombro: ela ergue a mão e as estrelas afastam as sombras
	_corte(_L(Vector3(-0.45, 1.55, -0.9), y), _L(Vector3(0.0, 1.15, 20.0), y), 48.0)
	rig.pose_bracos("luz", 1.0)
	create_tween().tween_property(rig, "brilho_mao", 1.0, 1.4)
	await _esperar(1.2)
	create_tween().tween_property(self, "ceu_brilho", 1.0, 2.0)
	await _esperar(1.6)
	_apagar_olhos(0.9)
	await _esperar(2.4)
	_gerar_olhos(8)                                        # ... porém, mais estavam vindo
	await _esperar(2.8)
	_corte(_L(Vector3(0.3, 1.40, 1.2), y), _L(Vector3(0.0, 1.34, 0.0), y), 36.0)
	rig.pose_bracos("relaxado", 1.4)
	create_tween().tween_property(rig, "brilho_mao", 0.25, 1.4)
	create_tween().tween_property(self, "ceu_brilho", 0.35, 2.0)
	await _esperar(2.0)

	# ================= ATO II — MINHA ESTRELINHA =================
	_apagar_olhos(0.8)
	rig.expressao("ternura", 1.2)
	await _girar(YAW_PEDESTAL, 1.8).finished               # ela retorna até a estrela
	y = YAW_PEDESTAL
	# a estrela continua no pedestal; só se inclina um pouco na direção dela.
	# Ela fica em pé, inclina o corpo e levanta uma mão perto da estrela.
	var aprox := _est_para(_L(P_TOQUE, y), 2.0, 0.3)
	rig.mover({"tronco_pitch": 10.0, "cab_pitch": 14.0}, 2.0)
	rig.pose_bracos("tocar", 1.8)
	# plano de perfil: ela e a estrela lado a lado, uma não fica na frente da outra
	_corte(_L(Vector3(2.0, 1.25, 0.45), y), _L(Vector3(0.0, 1.2, 0.35), y), 40.0)
	_mover_cam(_L(Vector3(1.6, 1.25, 0.45), y), _L(Vector3(0.0, 1.2, 0.35), y), 38.0, 3.5)
	await aprox.finished
	await _esperar(0.8)
	_estrela_pulsa()
	_mover_cam(_L(CAM_ROSTO, y), _L(ALVO_ROSTO, y), 34.0, 1.8)   # 3/4: o rosto dela aparece
	await _fala("Shhh... Está tudo bem, minha estrelinha.", "voz suave, acolhedora")
	await _esperar(2.5)                                    # pausa: ela guarda aquele instante

	rig.expressao("nostalgia", 1.2)
	rig.mover({"cab_pitch": -22.0, "tronco_pitch": 0.0}, 1.4)   # olha o céu pela abertura do santuário
	rig.pose_bracos("apresentar", 1.4)                     # apresenta a imensidão do universo
	_mover_cam(_L(Vector3(0.9, 0.9, 1.0), y), _L(Vector3(0.0, 1.75, 0.0), y), 50.0, 2.4)
	await _fala("Eu sei... há tantas coisas que você ainda não conhece. Tantas estrelas que ainda não contemplou, tantos mundos que ainda não visitou...")

	rig.expressao("ternura", 1.0)
	rig.mover({"cab_pitch": 12.0, "tronco_pitch": 8.0}, 1.2)
	rig.pose_bracos("tocar", 1.2)
	_mover_cam(_L(CAM_ROSTO, y), _L(ALVO_ROSTO, y), 34.0, 2.0)
	await _fala("Mas, por enquanto, preciso que seja corajosa por mim. Há pessoas vindo, e não posso permitir que encontrem você aqui.")

	# aproxima a criança do peito e a envolve com os braços
	rig.pose_bracos("abracar", 1.3)
	rig.mover({"tronco_pitch": 14.0, "cab_pitch": 18.0}, 1.4)
	var peito := _est_para(_L(P_PEITO, y), 1.4, 0.26)
	_mover_cam(_L(Vector3(0.7, 0.75, 0.95), y), _L(Vector3(0.0, 0.6, 0.3), y), 34.0, 2.0)
	await peito.finished
	await _esperar(2.4)

	# ================= ATO III — O VALOR DE UMA ESTRELA =================
	rig.expressao("serena", 1.0)
	_estrela_pulsa()
	await _fala("Escute bem, meu pequeno tesouro: não tenha medo de brilhar. Nunca esconda sua luz, nem mesmo quando o universo parecer mergulhado na escuridão.", "voz maternal e delicada")

	rig.pose_bracos("estender", 1.2)                       # mãos sobre os ombros da criança
	_est_para(_L(P_AFASTADA, y), 1.4, 0.3)
	rig.mover({"tronco_pitch": 4.0, "cab_pitch": 6.0}, 1.2)
	rig.expressao("sorriso", 1.0)
	_mover_cam(_L(CAM_ROSTO, y), _L(ALVO_ROSTO, y), 36.0, 2.0)
	await _esperar(1.6)
	await _fala("Você não precisa ser a estrela mais brilhante, nem iluminar todos os caminhos. Não precisa provar seu valor a ninguém.")

	_balancar_cabeca()
	rig.expressao("ternura", 0.8)
	await _fala("Você já é precioso simplesmente por existir.", "com ternura")
	rig.expressao("sorriso", 1.6)                          # o sorriso fica mais evidente
	await _esperar(2.8)

	# ================= ATO IV — UMA PROMESSA =================
	rig.expressao("firme", 0.5)                            # um ruído distante
	await rig.mover({"cab_yaw": -55.0}, 0.9).finished
	await _esperar(1.0)
	rig.expressao("ternura", 0.8)
	await rig.mover({"cab_yaw": 0.0}, 0.9).finished
	await _fala("Eu tenho que resolver uma coisa antes... Mas não se preocupe, meu amor.", "voz baixa, mas decidida")

	rig.pose_bracos("acariciar", 1.0)                      # acaricia os cabelos
	await _esperar(1.4)
	rig.mover({"tronco_pitch": 22.0, "cab_pitch": 20.0, "palpebra": 0.9}, 1.4)   # beija a testa
	_est_para(_L(P_BEIJO, y), 1.2)
	_mover_cam(_L(CAM_PERFIL, y), _L(ALVO_PERFIL, y), 34.0, 1.6)   # perfil: o beijo aparece de lado
	await _esperar(1.8)
	_mostrar_marca()                                       # a marca lunar começa a brilhar
	await _esperar(1.6)
	rig.mover({"tronco_pitch": 8.0, "cab_pitch": 12.0, "palpebra": 0.0}, 1.2)
	rig.expressao("emocionada", 1.0)
	_est_para(_L(P_AFASTADA, y), 1.2)
	_mover_cam(_L(CAM_ROSTO, y), _L(ALVO_ROSTO, y), 34.0, 1.6)
	await _fala("Este será meu presente para você. Uma pequena lembrança de onde veio... e de quem sempre estará esperando por você.")

	await _esperar(1.2)                                    # passa o dedo perto da marca, sem apagá-la
	rig.expressao("serena", 1.0)
	await _fala("Eu te amo, minha estrelinha. Mais do que as palavras poderiam contar, mais do que todos os céus poderiam testemunhar.")

	rig.pose_bracos("abracar", 1.3)                        # abraço, de olhos fechados
	rig.expressao("olhos_fechados", 1.0)
	rig.mover({"tronco_pitch": 14.0, "cab_pitch": 18.0}, 1.4)
	_est_para(_L(P_PEITO, y), 1.4, 0.26)
	_mover_cam(_L(Vector3(0.7, 0.75, 0.95), y), _L(Vector3(0.0, 0.6, 0.3), y), 34.0, 2.0)
	await _esperar(3.6)

	# ================= ATO V — ATÉ NOSSO PRÓXIMO ENCONTRO =================
	# ao se afastar, começa a preparar o envio da criança
	_est_para(_L(P_AFASTADA + Vector3(0.0, 0.1, 0.1), y), 1.6, 0.3)
	rig.mover({"tronco_pitch": 2.0, "cab_pitch": 4.0, "palpebra": 0.15}, 1.6)
	rig.pose_bracos("coracao", 1.4)                        # uma mão no coração, outra para a criança
	rig.expressao("confianca", 1.2)
	_mover_cam(_L(Vector3(0.9, 1.1, 1.9), y), _L(Vector3(0.0, 1.0, 0.4), y), 40.0, 2.4)
	await _esperar(1.2)
	await _fala("Talvez o caminho seja longo. Talvez você encontre coisas que ainda não compreende. Mas, mesmo que se sinta pequenina diante da imensidão do universo, lembre-se: você nunca foi insignificante.", "voz suave, mas inspiradora")
	await _fala("Eu vou encontrar você. Não importa quanto tempo passe, nem quantas estrelas precisarei atravessar.")

	rig.mover({"tronco_pitch": 10.0, "cab_pitch": 8.0}, 1.0)   # se inclina
	rig.expressao("solene", 0.8)
	_mover_cam(_L(CAM_ROSTO, y), _L(ALVO_ROSTO, y), 34.0, 1.8)
	await _fala("Enquanto houver luz no firmamento, haverá uma mãe procurando por sua estrelinha.", "voz firme e solene")

	rig.expressao("sorriso", 1.2)
	await _esperar(2.4)
	await _fala("Agora vá, meu amor... Vá conhecer o universo que tanto esperei para mostrar a você.")

	rig.pose_bracos("acariciar", 1.2)                      # última carícia
	await _esperar(2.6)
	await _fala("Que as estrelas guiem seu caminho de volta para mim.", "quase num sussurro")

	rig.mover({"tronco_pitch": 22.0, "cab_pitch": 20.0}, 1.4)   # último beijo
	rig.expressao("olhos_fechados", 1.0)
	_est_para(_L(P_BEIJO, y), 1.2)
	_mover_cam(_L(CAM_PERFIL, y), _L(ALVO_PERFIL, y), 34.0, 1.6)
	await _esperar(2.8)
	rig.mover({"tronco_pitch": 6.0, "cab_pitch": 8.0, "palpebra": 0.25}, 1.0)
	rig.expressao("serena", 0.8)
	_mover_cam(_L(CAM_ROSTO, y), _L(ALVO_ROSTO, y), 34.0, 1.4)
	await _fala("Até nosso próximo encontro, minha estrelinha.")

	await _partida(y)
	await _terminar()

# a luz envolve a criança, que sobe e vira estrela cadente
func _partida(y: float) -> void:
	if _cam_tween != null:
		_cam_tween.kill()
	flutua = false
	rastro.emitting = true
	rig.pose_bracos("relaxado", 1.0)
	rig.mover({"tronco_pitch": 0.0, "cab_pitch": -8.0}, 2.2)

	var s0 := estrela.position
	var s1 := s0 + Vector3(-4.0, 40.0, -30.0)
	cam_seguir = true                                      # a câmera acompanha a criança subindo
	var t := create_tween().set_parallel(true)
	t.tween_method(_passo_subida.bind(s0, s1), 0.0, 1.0, 5.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(luz, "light_energy", 6.0, 1.5)
	t.tween_property(luz, "omni_range", 8.0, 1.5)
	t.tween_property(mat_estrela, "emission_energy_multiplier", 9.0, 1.5)
	t.tween_property(env, "glow_intensity", 1.0, 1.5)      # o brilho volta, agora é a estrela cadente
	t.tween_property(env, "glow_bloom", 0.15, 1.5)
	await _esperar(3.0)

	# a câmera retorna lentamente à deusa, que olha o céu com um sorriso delicado
	cam_seguir = false
	_mover_cam(_L(Vector3(0.9, 1.5, 2.0), y), _L(Vector3(0.0, 1.5, 0.0), y), 38.0, 3.0)
	rig.mover({"cab_pitch": -24.0}, 2.5)
	rig.expressao("serena", 1.5)
	await t.finished

	estrela.visible = false                                # a estrela some no horizonte
	rastro.emitting = false
	await _esperar(1.4)
	rig.expressao("triste", 1.8)                           # o sorriso diminui
	await _esperar(2.0)
	rig.mover({"palpebra": 1.0}, 0.9)                      # ela fecha os olhos por um instante
	await _esperar(2.2)

func _passo_subida(v: float, s0: Vector3, s1: Vector3) -> void:
	estrela.position = s0.lerp(s1, v)
	estrela.scale = Vector3.ONE * lerpf(0.3, 1.4, v)

func _terminar() -> void:
	Global.dados["cutscene3_vista"] = true
	Global.salvar()
	if musica != null and musica.stream != null:
		create_tween().tween_property(musica, "volume_db", -40.0, 1.8)
	await _fade(Color.BLACK, 0.0, 1.0, 1.8).finished
	get_tree().change_scene_to_file(PROXIMA)

extends Node3D

const PANORAMA := "res://assets/Galaxia.png"
const PROXIMA := "res://scenes/cutscene_2.tscn"
const TIPOS := ["feminino", "masculino"]
const POSE_FINAL_X := 6.0                      # inclinação final da câmera (graus)
const PALCO := Vector3(0, -1.0, -3.4)          # onde o modelo aparece
const RAIO_CLIQUE := 1.3

enum Estado { ENTRADA, ESCOLHENDO, SALTANDO, PREVIA, SAINDO }
var estado := Estado.ENTRADA

var camera: Camera3D
var estrelas: Array[MeshInstance3D] = []
var estrelas_raiz: Node3D
var modelo: Node3D = null
var tipo_atual := ""

var dica: Label
var botoes: HBoxContainer
var fade: ColorRect

func _ready() -> void:
	_montar_cenario()
	_montar_ui()
	_intro()

# ---------------------------------------------------------------- cenário

func _montar_cenario() -> void:
	var env := Environment.new()
	if ResourceLoader.exists(PANORAMA):
		var mat := PanoramaSkyMaterial.new()
		mat.panorama = load(PANORAMA)
		var sky := Sky.new()
		sky.sky_material = mat
		env.background_mode = Environment.BG_SKY
		env.sky = sky
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.02, 0.02, 0.08)
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-35, 25, 0)
	sol.light_color = Color(0.85, 0.9, 1.0)
	add_child(sol)

	camera = Camera3D.new()
	camera.far = 500.0
	add_child(camera)

	estrelas_raiz = Node3D.new()
	add_child(estrelas_raiz)
	_criar_estrela(Vector3(-5, 2.5, -14), Color(1.0, 0.55, 0.8))   # feminino
	_criar_estrela(Vector3(5, 2.5, -14), Color(0.5, 0.7, 1.0))     # masculino

func _criar_estrela(pos: Vector3, cor: Color) -> void:
	var m := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.6
	esf.height = 1.2
	m.mesh = esf
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor.darkened(0.5)
	mat.emission_enabled = true
	mat.emission = cor
	mat.emission_energy_multiplier = 4.0
	m.material_override = mat
	m.position = pos
	estrelas_raiz.add_child(m)

	var luz := OmniLight3D.new()
	luz.light_color = cor
	luz.omni_range = 8.0
	luz.light_energy = 2.0
	m.add_child(luz)

	# pulsa devagar
	var t := create_tween().set_loops()
	t.tween_property(m, "scale", Vector3.ONE * 1.15, 1.2).set_trans(Tween.TRANS_SINE)
	t.tween_property(m, "scale", Vector3.ONE, 1.2).set_trans(Tween.TRANS_SINE)

	estrelas.append(m)

# ---------------------------------------------------------------- interface

func _montar_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)

	dica = Label.new()
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dica.add_theme_font_size_override("font_size", 44)
	dica.add_theme_color_override("font_outline_color", Color.BLACK)
	dica.add_theme_constant_override("outline_size", 8)
	ui.add_child(dica)
	_ancorar(dica, 0.0, 40, -40, 60, 140)

	botoes = HBoxContainer.new()
	botoes.alignment = BoxContainer.ALIGNMENT_CENTER
	botoes.add_theme_constant_override("separation", 40)
	botoes.visible = false
	ui.add_child(botoes)
	_ancorar(botoes, 1.0, 80, -80, -230, -90)

	var b1 := Button.new()
	b1.text = "Escolher esse corpo"
	b1.custom_minimum_size = Vector2(520, 100)
	b1.add_theme_font_size_override("font_size", 36)
	b1.pressed.connect(_confirmar)
	botoes.add_child(b1)

	var b2 := Button.new()
	b2.text = "Voltar"
	b2.custom_minimum_size = Vector2(320, 100)
	b2.add_theme_font_size_override("font_size", 36)
	b2.pressed.connect(_voltar)
	botoes.add_child(b2)

	# camada do fade (por cima de tudo)
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

# ---------------------------------------------------------------- sequência

func _intro() -> void:
	camera.rotation_degrees = Vector3(-80, 0, 0)   # olhando para baixo
	_fade(Color.BLACK, 1.0, 0.0, 2.5)              # fade in do céu
	var t := create_tween()
	t.tween_property(camera, "rotation_degrees:x", POSE_FINAL_X, 7.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	estado = Estado.ESCOLHENDO
	dica.text = "Toque em uma estrela"

func _input(event: InputEvent) -> void:
	if estado != Estado.ESCOLHENDO:
		return
	if event is InputEventMouseMotion:
		var sobre := _estrela_em(event.position) >= 0
		Input.set_default_cursor_shape(
			Input.CURSOR_POINTING_HAND if sobre else Input.CURSOR_ARROW)
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _estrela_em(event.position)
		if i >= 0:
			_salto(i)

# devolve o índice da estrela sob o mouse (ou -1)
func _estrela_em(pos: Vector2) -> int:
	var origem := camera.project_ray_origin(pos)
	var dir := camera.project_ray_normal(pos)
	for i in estrelas.size():
		var oc := estrelas[i].global_position - origem
		var t := oc.dot(dir)
		if t < 0.0:
			continue
		if (oc - dir * t).length() <= RAIO_CLIQUE:
			return i
	return -1

func _salto(i: int) -> void:
	estado = Estado.SALTANDO
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	dica.text = ""

	var alvo := estrelas[i].position
	var inicio := camera.position
	var dir := (alvo - inicio).normalized()
	var fim := alvo - dir * 1.5
	var q_ini := camera.basis.get_rotation_quaternion()
	var q_fim := Basis.looking_at(dir).get_rotation_quaternion()

	# a câmera vira para a estrela
	var giro := create_tween()
	giro.tween_method(_passo_giro.bind(q_ini, q_fim), 0.0, 1.0, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# e dispara em direção a ela, com o campo de visão se abrindo
	var voo := create_tween().set_parallel(true)
	voo.tween_method(_passo_voo.bind(inicio, fim), 0.0, 1.0, 1.5) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	voo.tween_property(camera, "fov", 115.0, 1.5) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await voo.finished

	await _fade(Color.WHITE, 0.0, 1.0, 0.25).finished   # clarão
	_mostrar_modelo(i)
	await _fade(Color.WHITE, 1.0, 0.0, 0.8).finished
	estado = Estado.PREVIA
	botoes.visible = true

func _passo_giro(v: float, q_ini: Quaternion, q_fim: Quaternion) -> void:
	camera.basis = Basis(q_ini.slerp(q_fim, v))

func _passo_voo(v: float, inicio: Vector3, fim: Vector3) -> void:
	camera.position = inicio.lerp(fim, v)

func _mostrar_modelo(i: int) -> void:
	estrelas_raiz.visible = false
	camera.position = Vector3.ZERO
	camera.rotation_degrees = Vector3.ZERO
	camera.fov = 75.0

	tipo_atual = TIPOS[i]
	modelo = _criar_modelo(tipo_atual)
	modelo.position = PALCO
	modelo.scale = Vector3.ONE * 0.01
	add_child(modelo)
	create_tween().tween_property(modelo, "scale", Vector3.ONE, 0.9) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	dica.text = "Corpo " + tipo_atual

func _criar_modelo(tipo: String) -> Node3D:
	var caminho := "res://assets/models/%s.glb" % tipo
	if ResourceLoader.exists(caminho):
		var cena: PackedScene = load(caminho)
		return cena.instantiate()

	# boneco provisório
	var raiz := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.55, 0.75) if tipo == "feminino" else Color(0.45, 0.65, 1.0)

	var corpo := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.4
	cap.radial_segments = 8
	cap.rings = 2
	corpo.mesh = cap
	corpo.material_override = mat
	corpo.position.y = 0.7
	raiz.add_child(corpo)

	var cabeca := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.25
	esf.height = 0.5
	esf.radial_segments = 8
	esf.rings = 4
	cabeca.mesh = esf
	cabeca.material_override = mat
	cabeca.position.y = 1.65
	raiz.add_child(cabeca)
	return raiz

func _process(delta: float) -> void:
	if modelo != null and estado == Estado.PREVIA:
		modelo.rotate_y(delta * 0.6)

# ---------------------------------------------------------------- botões

func _voltar() -> void:
	if estado != Estado.PREVIA:
		return
	estado = Estado.SALTANDO   # bloqueia cliques durante a transição
	botoes.visible = false
	await _fade(Color.BLACK, 0.0, 1.0, 0.4).finished
	if modelo != null:
		modelo.queue_free()
		modelo = null
	camera.position = Vector3.ZERO
	camera.rotation_degrees = Vector3(POSE_FINAL_X, 0, 0)
	camera.fov = 75.0
	estrelas_raiz.visible = true
	dica.text = "Toque em uma estrela"
	await _fade(Color.BLACK, 1.0, 0.0, 0.6).finished
	estado = Estado.ESCOLHENDO

func _confirmar() -> void:
	if estado != Estado.PREVIA:
		return
	estado = Estado.SAINDO
	botoes.visible = false
	Global.dados["corpo"] = tipo_atual
	Global.salvar()
	await _fade(Color.BLACK, 0.0, 1.0, 1.0).finished
	# troca direta (sem tela de loading): a cutscene 2 já começa em preto
	get_tree().change_scene_to_file(PROXIMA)

extends Node3D

const PANORAMA := "res://assets/Galaxia.png"
const PROXIMA := "res://scenes/cutscene_3.tscn"     # depois vira a próxima cena
const PALCO := Vector3(0, -1.0, -3.4)          # onde o corpo aparece

# --- posição da deusa: ela já está na cena, só fora da tela, à esquerda ---
const DEUSA_ANGULO := 90.0     # graus à esquerda da câmera (use entre 70 e 100)
const DEUSA_DIST := 1.34       # distância da câmera até ela no enquadramento final
const ALTURA_OLHAR := 0.53     # altura da câmera em relação à base dela (sobe = mostra mais o rosto)
const MAOS := Vector3(0, 0.79, 0.30)   # onde a estrela fica, em relação à deusa
const VOO_DURACAO := 8.0       # duração do movimento da estrela + câmera (segundos)

const CPS := 35.0              # letras por segundo no diálogo

const CORES := {
	"feminino": Color(1.0, 0.55, 0.8),
	"masculino": Color(0.5, 0.7, 1.0),
}

# EDITE AQUI: as falas da deusa
const DIALOGO := [
	{"nome": "???", "texto": "Oh...?"},
	{"nome": "???", "texto": "Que luz tão pequenina..."},
	{"nome": "???", "texto": "Você consegue me ouvir, estrelinha?"},
	{"nome": "???", "texto": "Ah... que maravilha! Você é ainda mais brilhante do que imaginei."},
	{"nome": "???", "texto": "Venha cá, minha criança... quero mostrar-lhe o universo..."},
]

var camera: Camera3D
var modelo: Node3D
var estrela: Node3D
var bola: MeshInstance3D
var luz: OmniLight3D
var boca: MeshInstance3D = null
var tipo := "feminino"

var deusa_pos := Vector3.ZERO     # calculado em _calcular_posicoes()
var maos_mundo := Vector3.ZERO

var girando := true
var flutuando := false
var falando := false
var clique := false
var tempo := 0.0

var fade: ColorRect
var caixa: Control
var nome_label: Label
var fala: Label
var seta: Label

func _ready() -> void:
	tipo = str(Global.dados.get("corpo", "feminino"))
	if not CORES.has(tipo):
		tipo = "feminino"
	_calcular_posicoes()
	_montar_cenario()
	_criar_estrela(CORES[tipo])
	_criar_deusa()
	_montar_ui()
	modelo = _criar_modelo(tipo)
	modelo.position = PALCO
	add_child(modelo)
	_sequencia()

# a câmera fica na origem; a deusa fica DEUSA_DIST à frente dela, no ângulo escolhido
func _calcular_posicoes() -> void:
	var a := deg_to_rad(DEUSA_ANGULO)
	var dir := Vector3(-sin(a), 0.0, -cos(a))
	deusa_pos = dir * DEUSA_DIST + Vector3(0.0, -ALTURA_OLHAR, 0.0)
	maos_mundo = deusa_pos + Basis(Vector3.UP, a) * MAOS

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
	camera.fov = 60.0
	add_child(camera)

func _criar_estrela(cor: Color) -> void:
	estrela = Node3D.new()
	estrela.visible = false
	add_child(estrela)

	bola = MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.6
	esf.height = 1.2
	bola.mesh = esf
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor.darkened(0.5)
	mat.emission_enabled = true
	mat.emission = cor
	mat.emission_energy_multiplier = 4.0
	bola.material_override = mat
	estrela.add_child(bola)

	luz = OmniLight3D.new()
	luz.light_color = cor
	luz.omni_range = 8.0
	luz.light_energy = 2.0
	estrela.add_child(luz)

	var t := create_tween().set_loops()
	t.tween_property(bola, "scale", Vector3.ONE * 1.15, 1.2).set_trans(Tween.TRANS_SINE)
	t.tween_property(bola, "scale", Vector3.ONE, 1.2).set_trans(Tween.TRANS_SINE)

# ---------------------------------------------------------------- personagens

func _criar_modelo(t: String) -> Node3D:
	var caminho := "res://assets/models/%s.glb" % t
	if ResourceLoader.exists(caminho):
		var cena: PackedScene = load(caminho)
		return cena.instantiate()

	var raiz := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.55, 0.75) if t == "feminino" else Color(0.45, 0.65, 1.0)

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

func _criar_deusa() -> void:
	var deusa: Node3D
	var caminho := "res://assets/models/deusa.glb"
	if ResourceLoader.exists(caminho):
		var cena: PackedScene = load(caminho)
		deusa = cena.instantiate()
	else:
		deusa = _deusa_provisoria()
	deusa.position = deusa_pos
	deusa.rotation_degrees.y = DEUSA_ANGULO   # ela olha na direção da câmera
	add_child(deusa)

	# luz suave só para ela (a luz da estrela chega depois)
	var preenche := OmniLight3D.new()
	preenche.light_color = Color(0.9, 0.85, 1.0)
	preenche.omni_range = 3.0
	preenche.light_energy = 0.8
	preenche.position = deusa_pos + Basis(Vector3.UP, deg_to_rad(DEUSA_ANGULO)) * Vector3(0.0, 1.0, 1.2)
	add_child(preenche)

func _deusa_provisoria() -> Node3D:
	var raiz := Node3D.new()

	var roupa := StandardMaterial3D.new()
	roupa.albedo_color = Color(0.95, 0.93, 0.9)
	roupa.emission_enabled = true
	roupa.emission = Color(0.8, 0.75, 1.0)
	roupa.emission_energy_multiplier = 0.25

	var pele := StandardMaterial3D.new()
	pele.albedo_color = Color(0.96, 0.82, 0.72)

	# túnica
	var tun := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.2
	cil.bottom_radius = 0.55
	cil.height = 1.3
	cil.radial_segments = 8
	tun.mesh = cil
	tun.material_override = roupa
	tun.position = Vector3(0, 0.35, 0)
	raiz.add_child(tun)

	# pescoço
	var pescoco := MeshInstance3D.new()
	var cp := CylinderMesh.new()
	cp.top_radius = 0.05
	cp.bottom_radius = 0.06
	cp.height = 0.14
	pescoco.mesh = cp
	pescoco.material_override = pele
	pescoco.position = Vector3(0, 1.05, 0)
	raiz.add_child(pescoco)

	# cabeça (o enquadramento corta acima da boca)
	var cabeca := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.14
	esf.height = 0.28
	esf.radial_segments = 12
	esf.rings = 6
	cabeca.mesh = esf
	cabeca.material_override = pele
	cabeca.position = Vector3(0, 1.32, 0)
	raiz.add_child(cabeca)

	# boca
	boca = MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.07, 0.012, 0.02)
	boca.mesh = bx
	var mb := StandardMaterial3D.new()
	mb.albedo_color = Color(0.85, 0.3, 0.4)
	boca.material_override = mb
	boca.position = Vector3(0, 1.24, 0.112)
	raiz.add_child(boca)

	# braços e mãos em concha
	for lado in [-1.0, 1.0]:
		_membro(raiz, Vector3(0.26 * lado, 0.95, 0.0), Vector3(0.07 * lado, 0.76, 0.28), 0.045, roupa)
		var mao := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = 0.06
		m.height = 0.12
		m.radial_segments = 8
		m.rings = 4
		mao.mesh = m
		mao.material_override = pele
		mao.position = Vector3(0.07 * lado, 0.75, 0.30)
		mao.scale = Vector3(1.0, 0.55, 1.3)
		raiz.add_child(mao)
	return raiz

func _membro(pai: Node3D, a: Vector3, b: Vector3, raio: float, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = raio * 0.7
	cil.bottom_radius = raio
	cil.height = a.distance_to(b)
	cil.radial_segments = 8
	m.mesh = cil
	m.material_override = mat
	var dir := (b - a).normalized()
	m.basis = Basis.looking_at(dir) * Basis(Vector3.RIGHT, deg_to_rad(-90.0))
	m.position = (a + b) * 0.5
	pai.add_child(m)

# ---------------------------------------------------------------- interface

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

	fala = Label.new()
	fala.add_theme_font_size_override("font_size", 42)
	fala.add_theme_color_override("font_outline_color", Color.BLACK)
	fala.add_theme_constant_override("outline_size", 6)
	fala.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caixa.add_child(fala)
	_ancorar(fala, 1.0, 160, -160, -235, -105)

	seta = Label.new()
	seta.text = "Clique para continuar"
	seta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	seta.add_theme_font_size_override("font_size", 26)
	seta.modulate = Color(1, 1, 1, 0.7)
	seta.visible = false
	caixa.add_child(seta)
	_ancorar(seta, 1.0, 160, -160, -105, -65)

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

func _sequencia() -> void:
	# 1. fade in no corpo girando
	await _fade(Color.BLACK, 1.0, 0.0, 1.5).finished
	await get_tree().create_timer(1.5).timeout

	# 2. clarão: o corpo vira estrela
	await _fade(Color.WHITE, 0.0, 1.0, 0.2).finished
	girando = false
	modelo.visible = false
	estrela.position = PALCO + Vector3(0, 0.95, 0)
	estrela.scale = Vector3.ONE * 0.05
	estrela.visible = true
	create_tween().tween_property(estrela, "scale", Vector3.ONE * 0.5, 0.8) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _fade(Color.WHITE, 1.0, 0.0, 0.7).finished
	await get_tree().create_timer(1.0).timeout

	# 3. a estrela flutua para a esquerda; a câmera acompanha e enquadra a deusa
	await _voar_ate_deusa()

	# 4. diálogo
	await _dialogo()

	# 5. fim
	Global.dados["cutscene2_vista"] = true
	Global.salvar()
	await _fade(Color.BLACK, 0.0, 1.0, 1.2).finished
	get_tree().change_scene_to_file(PROXIMA)

func _voar_ate_deusa() -> void:
	# a estrela se move em arco ao redor da câmera (que está na origem)
	var r_ini := Vector2(estrela.position.x, estrela.position.z).length()
	var y_ini := estrela.position.y
	var r_fim := Vector2(maos_mundo.x, maos_mundo.z).length()
	var y_fim := maos_mundo.y
	var phi_fim := deg_to_rad(DEUSA_ANGULO)

	var t := create_tween()
	t.tween_method(_passo_voo.bind(r_ini, y_ini, r_fim, y_fim, phi_fim), 0.0, 1.0, VOO_DURACAO) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished

	flutuando = true
	create_tween().tween_property(luz, "light_energy", 2.5, 1.0)
	await get_tree().create_timer(1.5).timeout

func _passo_voo(v: float, r_ini: float, y_ini: float, r_fim: float, y_fim: float, phi_fim: float) -> void:
	var phi := phi_fim * v
	var r := lerpf(r_ini, r_fim, v)
	var y := lerpf(y_ini, y_fim, v) + sin(v * PI) * 0.4
	estrela.position = Vector3(-r * sin(phi), y, -r * cos(phi))
	estrela.scale = Vector3.ONE * lerpf(0.5, 0.12, v)
	luz.omni_range = lerpf(8.0, 3.0, v)
	camera.rotation = Vector3(0.0, phi, 0.0)   # só vira para a esquerda, sem inclinar

# ---------------------------------------------------------------- diálogo

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		clique = true
	elif event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
		clique = true

func _esperar_clique() -> void:
	clique = false
	while not clique:
		await get_tree().process_frame

func _dialogo() -> void:
	caixa.visible = true
	for linha in DIALOGO:
		nome_label.text = linha["nome"]
		fala.text = linha["texto"]
		fala.visible_ratio = 0.0
		falando = true
		clique = false
		var dur := maxf(0.5, fala.text.length() / CPS)
		var t := create_tween()
		t.tween_property(fala, "visible_ratio", 1.0, dur)
		while t.is_running():
			if clique:          # clicar durante a digitação mostra tudo de uma vez
				t.kill()
				fala.visible_ratio = 1.0
				break
			await get_tree().process_frame
		falando = false
		seta.visible = true
		await _esperar_clique()
		seta.visible = false
	caixa.visible = false

# ---------------------------------------------------------------- por quadro

func _process(delta: float) -> void:
	tempo += delta
	if girando and modelo != null:
		modelo.rotate_y(delta * 0.6)
	if flutuando:
		estrela.position.y = maos_mundo.y + sin(tempo * 2.0) * 0.012
	if boca != null:
		boca.scale.y = 1.0 + (1.5 * absf(sin(tempo * 14.0)) if falando else 0.0)

extends Node3D
# Protagonista provisório: boneco articulado com animações feitas por código.
# Quando existir o modelo final (feminino.glb / masculino.glb), trocamos por animações reais.

var tipo := "feminino"          # defina ANTES de adicionar à cena

const BASE := {
	"q_y": 0.905, "q_rx": 0.0,
	"t_rx": 0.0, "t_ry": 0.0,
	"c_rx": 0.0, "c_ry": 0.0,
	"be_rx": 0.0, "be_rz": 6.0, "bd_rx": 0.0, "bd_rz": -6.0,
	"ce_rx": -8.0, "cd_rx": -8.0,
	"pe_rx": 0.0, "pd_rx": 0.0, "pe_rz": 2.0, "pd_rz": -2.0,
	"je_rx": 0.0, "jd_rx": 0.0,
}

const POSES := {
	"em_pe": {},
	"deitado": {
		"q_y": 0.17, "q_rx": -90.0, "c_rx": 8.0,
		"be_rz": 12.0, "bd_rz": -12.0, "ce_rx": -4.0, "cd_rx": -4.0,
		"pe_rz": 5.0, "pd_rz": -5.0,
	},
	"sentado": {
		"q_y": 0.17, "t_rx": 12.0, "c_rx": 8.0,
		"be_rx": -28.0, "bd_rx": -28.0, "be_rz": 16.0, "bd_rz": -16.0,
		"ce_rx": -75.0, "cd_rx": -75.0,
		"pe_rx": -86.0, "pd_rx": -86.0, "pe_rz": 8.0, "pd_rz": -8.0,
		"je_rx": 6.0, "jd_rx": 6.0,
	},
	"alcancar": {
		"t_rx": 8.0, "c_rx": 6.0,
		"be_rx": 10.0, "bd_rx": -78.0, "bd_rz": -4.0, "cd_rx": -14.0,
	},
	"agachado": {
		"q_y": 0.55, "t_rx": 28.0, "c_rx": -16.0,
		"be_rx": -35.0, "bd_rx": -35.0, "ce_rx": -40.0, "cd_rx": -40.0,
		"pe_rx": -75.0, "pd_rx": -75.0, "je_rx": 105.0, "jd_rx": 105.0,
		"pe_rz": 6.0, "pd_rz": -6.0,
	},
	"curvado": {
		"q_y": 0.85, "t_rx": 32.0, "c_rx": -14.0,
		"be_rx": 22.0, "bd_rx": 22.0, "ce_rx": -10.0, "cd_rx": -10.0,
		"pe_rx": -12.0, "pd_rx": -12.0, "je_rx": 22.0, "jd_rx": 22.0,
	},
	"adagas": {
		"q_y": 0.87, "t_rx": 14.0, "c_rx": -6.0,
		"be_rx": -85.0, "bd_rx": -85.0, "be_rz": 8.0, "bd_rz": -8.0,
		"ce_rx": -12.0, "cd_rx": -12.0,
		"pe_rx": -22.0, "pd_rx": 14.0, "je_rx": 25.0,
	},
	"paz": {
		"t_rx": -4.0, "c_rx": -4.0,
		"be_rx": -55.0, "bd_rx": -55.0, "be_rz": 14.0, "bd_rz": -14.0,
		"ce_rx": -80.0, "cd_rx": -80.0,
	},
	"tocar": {
		"t_rx": 6.0, "be_rx": -70.0, "ce_rx": -18.0,
	},
	"furioso": {
		"t_rx": 16.0, "c_rx": -10.0,
		"be_rx": -35.0, "bd_rx": -35.0, "be_rz": 20.0, "bd_rz": -20.0,
		"ce_rx": -70.0, "cd_rx": -70.0, "pe_rz": 6.0, "pd_rz": -6.0,
	},
	"risada": {
		"t_rx": 6.0, "c_rx": 10.0, "bd_rx": -45.0, "cd_rx": -105.0,
	},
	"duvida": {
		"c_rx": 8.0, "bd_rx": -140.0, "cd_rx": -110.0, "bd_rz": -10.0,
	},
	"reverencia": {
		"t_rx": 38.0, "c_rx": 10.0,
		"be_rx": 14.0, "bd_rx": -55.0, "cd_rx": -100.0,
	},
}

var val: Dictionary = {}
var _tw: Tween = null
var tempo := 0.0

# controle pelo jogo
var modo_loco := false        # true = anima andar/correr/pular/atacar
var vel_h := 0.0
var correndo := false
var no_ar := false
var fase := 0.0
var ataque_t := -1.0          # -1 = sem ataque; 0..1 = progresso do golpe
var ofegante := 0.0           # 0..1: respiração pesada
var olhar_yaw := 0.0          # a cabeça gira (graus)
var olhar_pitch := 0.0
var tremor := 0.0             # 0..1: o corpo treme de medo
var loco_bracos := true       # false = o andar/correr não mexe nos braços (mantém a pose)
var adagas: Array = []

var quadril: Node3D
var tronco: Node3D
var cabeca: Node3D
var ombro_e: Node3D
var ombro_d: Node3D
var cotovelo_e: Node3D
var cotovelo_d: Node3D
var coxa_e: Node3D
var coxa_d: Node3D
var joelho_e: Node3D
var joelho_d: Node3D

func _ready() -> void:
	_montar()
	val = _pose_completa("em_pe")

# ---------------------------------------------------------------- poses

func _pose_completa(nome: String) -> Dictionary:
	var d: Dictionary = BASE.duplicate()
	d.merge(POSES.get(nome, {}), true)
	return d

# muda de pose suavemente (brusco = true: movimento rápido, de sobressalto)
func pose(nome: String, dur := 0.5, brusco := false) -> Tween:
	var alvo := _pose_completa(nome)
	var de: Dictionary = val.duplicate()
	if _tw != null:
		_tw.kill()
	_tw = create_tween()
	if dur <= 0.0:
		_aplicar_pose(1.0, de, alvo)
		_tw.tween_interval(0.01)
	elif brusco:
		_tw.tween_method(_aplicar_pose.bind(de, alvo), 0.0, 1.0, dur) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	else:
		_tw.tween_method(_aplicar_pose.bind(de, alvo), 0.0, 1.0, dur) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return _tw

func _aplicar_pose(v: float, de: Dictionary, alvo: Dictionary) -> void:
	for k in alvo:
		val[k] = lerpf(float(de[k]), float(alvo[k]), v)

# golpe com a mão direita e um rastro de luz
func golpear() -> void:
	if ataque_t >= 0.0:
		return
	ataque_t = 0.0
	var t := create_tween()
	t.tween_property(self, "ataque_t", 1.0, 0.45)
	t.tween_callback(func(): ataque_t = -1.0)
	get_tree().create_timer(0.16).timeout.connect(_swoosh)

# adagas nas duas mãos (lâmina para a frente quando o braço aponta)
func empunhar(sim := true) -> void:
	for a in adagas:
		a.queue_free()
	adagas.clear()
	if not sim:
		return
	var aco := _mat(Color(0.82, 0.86, 0.92))
	aco.metallic = 0.8
	aco.roughness = 0.3
	var cabo := _mat(Color(0.25, 0.12, 0.08))
	for cot in [cotovelo_e, cotovelo_d]:
		var lamina := _malha(BoxMesh.new(), aco, Vector3(0.0, -0.5, 0.0), cot)
		lamina.scale = Vector3(0.025, 0.34, 0.012)
		var guarda := _malha(BoxMesh.new(), cabo, Vector3(0.0, -0.34, 0.0), cot)
		guarda.scale = Vector3(0.1, 0.02, 0.03)
		adagas.append(lamina)
		adagas.append(guarda)

func _swoosh() -> void:
	var m := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.7
	esf.height = 1.4
	esf.radial_segments = 12
	esf.rings = 6
	m.mesh = esf
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.95, 0.75, 0.85)
	m.material_override = mat
	m.position = Vector3(0.0, 1.1, 0.9)
	m.scale = Vector3(0.2, 0.05, 1.0)
	m.rotation_degrees = Vector3(0, 0, -25)
	add_child(m)
	var t := create_tween().set_parallel(true)
	t.tween_property(m, "scale", Vector3(1.9, 0.07, 1.1), 0.16)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.2)
	t.chain().tween_callback(m.queue_free)

# ---------------------------------------------------------------- animação por quadro

func _process(delta: float) -> void:
	tempo += delta
	if val.is_empty():
		return
	var v: Dictionary = val.duplicate()
	if modo_loco:
		_loco(delta, v)

	var freq := 2.2 + 5.0 * ofegante
	var amp := 0.5 + 3.5 * ofegante
	var resp := sin(tempo * freq) * amp

	quadril.position.y = v["q_y"]
	quadril.rotation_degrees.x = v["q_rx"]
	tronco.rotation_degrees = Vector3(v["t_rx"] + resp, v["t_ry"], 0.0)
	tronco.scale = Vector3(1.0, 1.0 + sin(tempo * freq) * 0.012 * (1.0 + 2.0 * ofegante), 1.0)
	cabeca.rotation_degrees = Vector3(v["c_rx"] + olhar_pitch - resp * 0.4, v["c_ry"] + olhar_yaw, 0.0)
	ombro_e.rotation_degrees = Vector3(v["be_rx"], 0.0, v["be_rz"])
	ombro_d.rotation_degrees = Vector3(v["bd_rx"], 0.0, v["bd_rz"])
	cotovelo_e.rotation_degrees.x = v["ce_rx"]
	cotovelo_d.rotation_degrees.x = v["cd_rx"]
	coxa_e.rotation_degrees = Vector3(v["pe_rx"], 0.0, v["pe_rz"])
	coxa_d.rotation_degrees = Vector3(v["pd_rx"], 0.0, v["pd_rz"])
	joelho_e.rotation_degrees.x = v["je_rx"]
	joelho_d.rotation_degrees.x = v["jd_rx"]

	if tremor > 0.0:
		var tt := tempo * 42.0
		ombro_e.rotation_degrees.z += sin(tt) * 2.5 * tremor
		ombro_d.rotation_degrees.z += sin(tt + 1.7) * 2.5 * tremor
		tronco.rotation_degrees.z = sin(tt * 0.8) * 1.5 * tremor
		coxa_e.rotation_degrees.x += sin(tt + 0.6) * 2.0 * tremor
		coxa_d.rotation_degrees.x += sin(tt + 2.1) * 2.0 * tremor

func _loco(delta: float, v: Dictionary) -> void:
	var amp := clampf(vel_h / 4.0, 0.0, 1.0)
	var run := 1.0 if correndo else 0.0
	if not no_ar and vel_h > 0.3:
		fase += delta * (9.0 + 4.0 * run)
	var s := sin(fase)
	var c := cos(fase)
	var passo := (26.0 + 30.0 * run) * amp

	v["q_y"] = 0.905 + absf(c) * (0.025 + 0.035 * run) * amp
	v["t_rx"] = (3.0 + 11.0 * run) * amp
	v["pe_rx"] = -s * passo
	v["pd_rx"] = s * passo
	v["je_rx"] = maxf(0.0, c) * (30.0 + 50.0 * run) * amp
	v["jd_rx"] = maxf(0.0, -c) * (30.0 + 50.0 * run) * amp
	var balanco := (22.0 + 25.0 * run) * amp
	v["be_rx"] = s * balanco
	v["bd_rx"] = -s * balanco
	v["ce_rx"] = -8.0 - (12.0 + 60.0 * run) * amp
	v["cd_rx"] = v["ce_rx"]

	if no_ar:
		v["pe_rx"] = -28.0
		v["pd_rx"] = -6.0
		v["je_rx"] = 55.0
		v["jd_rx"] = 22.0
		v["be_rx"] = -110.0
		v["bd_rx"] = -110.0
		v["be_rz"] = 24.0
		v["bd_rz"] = -24.0
		v["t_rx"] = 6.0

	if ataque_t >= 0.0:
		var p := ataque_t
		var k := 0.0
		if p < 0.3:
			k = p / 0.3
		elif p < 0.55:
			k = lerpf(1.0, -1.0, (p - 0.3) / 0.25)
		else:
			k = lerpf(-1.0, 0.0, (p - 0.55) / 0.45)
		var prep := maxf(k, 0.0)
		var gol := maxf(-k, 0.0)
		v["bd_rx"] = 55.0 * prep - 140.0 * gol
		v["cd_rx"] = -60.0 * prep - 10.0 * gol - 8.0 * (1.0 - absf(k))
		v["t_ry"] = -28.0 * prep + 30.0 * gol
		v["t_rx"] = float(v["t_rx"]) + 8.0 * gol
		v["pe_rx"] = float(v["pe_rx"]) - 20.0 * absf(k)
		v["pd_rx"] = float(v["pd_rx"]) + 10.0 * absf(k)

	if not loco_bracos:
		for k in ["be_rx", "bd_rx", "be_rz", "bd_rz", "ce_rx", "cd_rx", "t_rx"]:
			v[k] = val[k]

# ---------------------------------------------------------------- boneco provisório

func _mat(cor: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = 0.9
	return m

func _malha(mesh: Mesh, mat: Material, pos: Vector3, pai: Node3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	pai.add_child(m)
	return m

func _capsula(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 8
	c.rings = 3
	return c

func _esfera(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 10
	s.rings = 5
	return s

func _no(pai: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	pai.add_child(n)
	return n

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

func _montar() -> void:
	var suporte := tipo == "suporte"
	var fem := tipo != "masculino" and not suporte   # "feminino" e "laranja" usam o corpo feminino
	var laranja := tipo == "laranja"
	var jolene := tipo == "jolene"                   # enfermeira da cidade (corpo feminino, com avental)
	var dolly := tipo == "dolly"                     # filha da enfermeira (usa o corpo feminino)
	var roupa := _mat(Color(0.72, 0.80, 0.92) if jolene else Color(0.93, 0.96, 0.90) if dolly else Color(1.0, 0.55, 0.12) if laranja else (Color(0.25, 0.72, 0.55) if suporte else (Color(0.95, 0.55, 0.75) if fem else Color(0.45, 0.65, 1.0))))
	var calca := _mat(Color(0.22, 0.22, 0.32))
	var pele := _mat(Color(0.96, 0.80, 0.68))
	var cabelo := _mat(Color(0.66, 0.46, 0.26) if jolene else Color(0.45, 0.28, 0.15) if dolly else Color(0.95, 0.38, 0.08) if laranja else (Color(0.88, 0.88, 0.80) if suporte else (Color(0.50, 0.28, 0.60) if fem else Color(0.14, 0.20, 0.36))))
	var escuro := _mat(Color(0.07, 0.05, 0.08))
	var bota := _mat(Color(0.28, 0.20, 0.15))

	quadril = _no(self, Vector3(0, 0.905, 0))
	tronco = _no(quadril, Vector3.ZERO)

	# tronco
	var tm := _malha(_capsula(0.2, 0.66), roupa, Vector3(0, 0.33, 0), tronco)
	tm.scale = Vector3(1.0, 1.0, 0.7)
	if fem:
		_malha(_cilindro(0.2, 0.32, 0.26), roupa, Vector3(0, -0.07, 0), quadril)   # saia curta
	if jolene:
		var avental := _malha(BoxMesh.new(), _mat(Color(0.97, 0.97, 0.95)), Vector3(0, 0.22, 0.15), tronco)
		avental.scale = Vector3(0.34, 0.55, 0.02)

	# cabeça
	cabeca = _no(tronco, Vector3(0, 0.66, 0))
	_malha(_esfera(0.14), pele, Vector3(0, 0.17, 0), cabeca)
	var cab := _malha(_esfera(0.15), cabelo, Vector3(0, 0.24, -0.05), cabeca)
	cab.scale = Vector3(1.0, 0.85, 1.05)
	if fem:
		var rabo := _malha(_capsula(0.05, 0.3), cabelo, Vector3(0, 0.14, -0.2), cabeca)
		rabo.rotation_degrees.x = 25.0
	for lado in [-1.0, 1.0]:
		_malha(_esfera(0.02), escuro, Vector3(0.05 * lado, 0.185, 0.125), cabeca)
	var boca := _malha(BoxMesh.new(), escuro, Vector3(0, 0.105, 0.133), cabeca)
	boca.scale = Vector3(0.05, 0.01, 0.01)

	# marca lunar na testa
	var marca := Sprite3D.new()
	marca.texture = _textura_lua()
	marca.pixel_size = 0.0009
	marca.shaded = false
	marca.modulate = Color(2.0, 1.8, 1.0, 1.0)
	marca.position = Vector3(0, 0.225, 0.134)
	cabeca.add_child(marca)

	# braços
	for lado in [1.0, -1.0]:
		var ombro := _no(tronco, Vector3(0.27 * lado, 0.58, 0))
		_malha(_capsula(0.055, 0.36), roupa, Vector3(0, -0.17, 0), ombro)
		var cot := _no(ombro, Vector3(0, -0.34, 0))
		_malha(_capsula(0.05, 0.3), pele, Vector3(0, -0.15, 0), cot)
		_malha(_esfera(0.06), pele, Vector3(0, -0.31, 0), cot)
		if lado > 0.0:
			ombro_e = ombro
			cotovelo_e = cot
		else:
			ombro_d = ombro
			cotovelo_d = cot

	# pernas
	for lado in [1.0, -1.0]:
		var coxa := _no(quadril, Vector3(0.1 * lado, 0, 0))
		_malha(_capsula(0.085, 0.46), calca, Vector3(0, -0.22, 0), coxa)
		var joe := _no(coxa, Vector3(0, -0.44, 0))
		_malha(_capsula(0.07, 0.44), calca, Vector3(0, -0.21, 0), joe)
		var pe := _malha(BoxMesh.new(), bota, Vector3(0, -0.43, 0.06), joe)
		pe.scale = Vector3(0.13, 0.07, 0.27)
		if lado > 0.0:
			coxa_e = coxa
			joelho_e = joe
		else:
			coxa_d = coxa
			joelho_d = joe

func _cilindro(rt: float, rb: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = 8
	return c

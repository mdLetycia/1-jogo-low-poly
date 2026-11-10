extends Node3D
# Deusa provisória (boneca com juntas) para as cutscenes.
# O que a cutscene usa:
#   expressao(nome, dur)      -> muda o rosto
#   pose_bracos(nome, dur)    -> posição dos braços
#   mover({prop: valor}, dur) -> ajoelhar, tronco_pitch, cab_yaw, cab_pitch, palpebra, brilho_mao...
#   falar(true/false)         -> boca mexendo
# Com o modelo final (assets/models/deusa.glb) ligamos estes mesmos nomes às animações dele.

const MODELO_FINAL := "res://assets/models/deusa.glb"

const EXPRESSOES := {
	"neutra":         {"sob_ang": 0.0,   "sob_y": 0.0,    "palpebra": 0.0,  "olhos_escala": 1.0,  "sorriso": 0.0,  "abertura": 0.0},
	"desespero":      {"sob_ang": 24.0,  "sob_y": 0.010,  "palpebra": 0.0,  "olhos_escala": 1.25, "sorriso": -0.7, "abertura": 0.45},
	"alivio":         {"sob_ang": 10.0,  "sob_y": 0.004,  "palpebra": 0.25, "olhos_escala": 1.0,  "sorriso": 0.1,  "abertura": 0.12},
	"sorriso":        {"sob_ang": 4.0,   "sob_y": 0.0,    "palpebra": 0.18, "olhos_escala": 1.0,  "sorriso": 0.9,  "abertura": 0.0},
	"firme":          {"sob_ang": -18.0, "sob_y": -0.004, "palpebra": 0.12, "olhos_escala": 1.0,  "sorriso": -0.2, "abertura": 0.0},
	"ternura":        {"sob_ang": 12.0,  "sob_y": 0.004,  "palpebra": 0.3,  "olhos_escala": 1.0,  "sorriso": 0.55, "abertura": 0.0},
	"nostalgia":      {"sob_ang": 10.0,  "sob_y": 0.003,  "palpebra": 0.35, "olhos_escala": 1.0,  "sorriso": 0.5,  "abertura": 0.0},
	"serena":         {"sob_ang": 2.0,   "sob_y": 0.0,    "palpebra": 0.3,  "olhos_escala": 1.0,  "sorriso": 0.5,  "abertura": 0.0},
	"emocionada":     {"sob_ang": 18.0,  "sob_y": 0.006,  "palpebra": 0.35, "olhos_escala": 1.05, "sorriso": 0.45, "abertura": 0.0},
	"confianca":      {"sob_ang": -3.0,  "sob_y": 0.0,    "palpebra": 0.15, "olhos_escala": 1.0,  "sorriso": 0.8,  "abertura": 0.0},
	"solene":         {"sob_ang": -8.0,  "sob_y": 0.0,    "palpebra": 0.15, "olhos_escala": 1.0,  "sorriso": 0.05, "abertura": 0.0},
	"olhos_fechados": {"sob_ang": 8.0,   "sob_y": 0.002,  "palpebra": 1.0,  "olhos_escala": 1.0,  "sorriso": 0.4,  "abertura": 0.0},
	"triste":         {"sob_ang": 16.0,  "sob_y": 0.004,  "palpebra": 0.45, "olhos_escala": 1.0,  "sorriso": 0.0,  "abertura": 0.0},
}

# rotação de cada ombro: [esquerdo, direito], em graus (x = erguer, z = abrir/fechar)
const BRACOS := {
	"concha":     [Vector3(-56, 0, -29), Vector3(-56, 0, 29)],
	"relaxado":   [Vector3(3, 0, 7), Vector3(3, 0, -7)],
	"luz":        [Vector3(3, 0, 7), Vector3(-115, 0, -12)],
	"tocar":      [Vector3(3, 0, 7), Vector3(-118, 0, -3)],
	"acariciar":  [Vector3(-56, 0, -29), Vector3(-80, 0, 10)],
	"apresentar": [Vector3(3, 0, 7), Vector3(-120, 0, -35)],
	"acolher":    [Vector3(-55, 0, -12), Vector3(-55, 0, 12)],
	"estender":   [Vector3(-75, 0, -6), Vector3(-75, 0, 6)],
	"abracar":    [Vector3(-81, 0, -40), Vector3(-81, 0, 40)],
	"coracao":    [Vector3(-80, 0, -8), Vector3(-52, 0, 46)],
}

var _pronto := false
var _t := 0.0
var _externo: Node3D = null
var _anim: AnimationPlayer = null

var raiz_corpo: Node3D
var tronco: Node3D
var cabeca_pivo: Node3D
var ombros: Array[Node3D] = []            # [esquerdo (+X), direito (-X)]
var sobrancelhas: Array[Node3D] = []
var palpebras: Array[Node3D] = []
var olhos: Array[Node3D] = []
var labios: Array[MeshInstance3D] = []
var boca_dentro: MeshInstance3D
var luz_mao: OmniLight3D
var mat_mao: StandardMaterial3D

# propriedades animáveis (use mover({...}, tempo))
var ajoelhar := 0.0: set = _set_ajoelhar
var tronco_pitch := 0.0: set = _set_tronco_pitch
var cab_yaw := 0.0: set = _set_cab_yaw
var cab_pitch := 0.0: set = _set_cab_pitch
var sob_ang := 0.0: set = _set_sob_ang
var sob_y := 0.0: set = _set_sob_y
var palpebra := 0.0: set = _set_palpebra
var olhos_escala := 1.0: set = _set_olhos_escala
var sorriso := 0.0: set = _set_sorriso
var brilho_mao := 0.0: set = _set_brilho_mao
var abertura := 0.0
var arfar := 0.0            # 0 a 1: boca ofegante
var falando := false

func _ready() -> void:
	if ResourceLoader.exists(MODELO_FINAL):
		var cena: PackedScene = load(MODELO_FINAL)
		_externo = cena.instantiate()
		add_child(_externo)
		var achados := _externo.find_children("*", "AnimationPlayer", true, false)
		if achados.size() > 0:
			_anim = achados[0]
	else:
		_montar_provisoria()
	_pronto = true
	_set_sorriso(sorriso)
	_aplicar_sobrancelhas()
	pose_bracos("concha", 0.0)

# ---------------------------------------------------------------- funções públicas

func expressao(nome: String, dur := 0.4) -> Tween:
	if _externo != null:
		_tocar_externa("expr_" + nome)
		var t0 := create_tween()
		t0.tween_interval(0.01)
		return t0
	var p: Dictionary = EXPRESSOES.get(nome, EXPRESSOES["neutra"])
	return mover(p, dur)

func mover(props: Dictionary, dur := 0.5) -> Tween:
	var t := create_tween().set_parallel(true)
	for k in props:
		if dur <= 0.0:
			set(k, props[k])
		else:
			t.tween_property(self, str(k), props[k], dur) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if dur <= 0.0:
		t.tween_interval(0.01)
	return t

func pose_bracos(nome: String, dur := 0.8) -> Tween:
	var t := create_tween().set_parallel(true)
	if _externo != null:
		_tocar_externa(nome)
		t.tween_interval(0.01)
		return t
	var alvo: Array = BRACOS.get(nome, BRACOS["relaxado"])
	for i in ombros.size():
		if dur <= 0.0:
			ombros[i].rotation_degrees = alvo[i]
		else:
			t.tween_property(ombros[i], "rotation_degrees", alvo[i], dur) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if dur <= 0.0 or ombros.is_empty():
		t.tween_interval(0.01)
	return t

func falar(v: bool) -> void:
	falando = v

func rosto() -> Vector3:
	if cabeca_pivo:
		return cabeca_pivo.to_global(Vector3(0, 0.12, 0.05))
	return to_global(Vector3(0, 1.3, 0))

func _tocar_externa(nome: String) -> void:
	if _anim != null and _anim.has_animation(nome):
		_anim.play(nome)

# ---------------------------------------------------------------- setters

func _set_ajoelhar(v: float) -> void:
	ajoelhar = v
	if raiz_corpo:
		raiz_corpo.position.y = -0.52 * v

func _set_tronco_pitch(v: float) -> void:
	tronco_pitch = v
	if tronco:
		tronco.rotation_degrees.x = v

func _set_cab_yaw(v: float) -> void:
	cab_yaw = v
	if cabeca_pivo:
		cabeca_pivo.rotation_degrees.y = v

func _set_cab_pitch(v: float) -> void:
	cab_pitch = v
	if cabeca_pivo:
		cabeca_pivo.rotation_degrees.x = v

func _set_sob_ang(v: float) -> void:
	sob_ang = v
	_aplicar_sobrancelhas()

func _set_sob_y(v: float) -> void:
	sob_y = v
	_aplicar_sobrancelhas()

func _aplicar_sobrancelhas() -> void:
	for i in sobrancelhas.size():
		var lado := 1.0 if i == 0 else -1.0
		sobrancelhas[i].rotation_degrees.z = -sob_ang * lado
		sobrancelhas[i].position.y = 0.205 + sob_y

func _set_palpebra(v: float) -> void:
	palpebra = v
	for p in palpebras:
		p.visible = v > 0.04
		p.scale.y = maxf(v, 0.02)

func _set_olhos_escala(v: float) -> void:
	olhos_escala = v
	for o in olhos:
		o.scale = Vector3.ONE * v

func _set_sorriso(v: float) -> void:
	sorriso = v
	if labios.size() >= 2:
		labios[0].rotation_degrees.z = v * 32.0
		labios[1].rotation_degrees.z = -v * 32.0

func _set_brilho_mao(v: float) -> void:
	brilho_mao = v
	if luz_mao:
		luz_mao.light_energy = v * 3.0
	if mat_mao:
		mat_mao.emission_energy_multiplier = v * 3.0

func _process(delta: float) -> void:
	_t += delta
	if boca_dentro == null:
		return
	var ab := abertura
	if falando:
		ab = maxf(ab, 0.25 + 0.5 * absf(sin(_t * 13.0)))
	if arfar > 0.0:
		ab = maxf(ab, arfar * (0.35 + 0.35 * sin(_t * 8.0)))
	boca_dentro.visible = ab > 0.03
	boca_dentro.scale.y = 0.3 + ab * 3.5

# ---------------------------------------------------------------- boneca provisória

func _malha(mesh: Mesh, mat: Material, pos: Vector3, pai: Node3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	pai.add_child(m)
	return m

func _cil(rt: float, rb: float, h: float, seg := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = seg
	return c

func _esf(r: float, seg := 12, rings := 6) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = rings
	return s

func _cx(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b

func _montar_provisoria() -> void:
	var roupa := StandardMaterial3D.new()
	roupa.albedo_color = Color(0.95, 0.93, 0.9)
	roupa.emission_enabled = true
	roupa.emission = Color(0.8, 0.75, 1.0)
	roupa.emission_energy_multiplier = 0.25

	var pele := StandardMaterial3D.new()
	pele.albedo_color = Color(0.96, 0.82, 0.72)

	mat_mao = StandardMaterial3D.new()            # mão direita (a que brilha)
	mat_mao.albedo_color = Color(0.96, 0.82, 0.72)
	mat_mao.emission_enabled = true
	mat_mao.emission = Color(1.0, 0.85, 0.5)
	mat_mao.emission_energy_multiplier = 0.0

	var branco := StandardMaterial3D.new()
	branco.albedo_color = Color.WHITE
	var preto := StandardMaterial3D.new()
	preto.albedo_color = Color(0.05, 0.03, 0.05)
	var vermelho := StandardMaterial3D.new()
	vermelho.albedo_color = Color(0.8, 0.35, 0.42)
	var interior := StandardMaterial3D.new()
	interior.albedo_color = Color(0.2, 0.02, 0.04)

	raiz_corpo = Node3D.new()
	add_child(raiz_corpo)
	tronco = Node3D.new()
	tronco.position = Vector3(0, 0.3, 0)
	raiz_corpo.add_child(tronco)

	# túnica e pescoço
	_malha(_cil(0.2, 0.55, 1.3), roupa, Vector3(0, 0.05, 0), tronco)
	_malha(_cil(0.05, 0.06, 0.14), pele, Vector3(0, 0.75, 0), tronco)

	# cabeça
	cabeca_pivo = Node3D.new()
	cabeca_pivo.position = Vector3(0, 0.9, 0)
	tronco.add_child(cabeca_pivo)
	_malha(_esf(0.14), pele, Vector3(0, 0.12, 0), cabeca_pivo)

	# olhos, pálpebras, sobrancelhas e lábios (esquerdo = +X primeiro)
	for lado in [1.0, -1.0]:
		var olho := Node3D.new()
		olho.position = Vector3(0.05 * lado, 0.15, 0.122)
		cabeca_pivo.add_child(olho)
		_malha(_esf(0.024, 8, 4), branco, Vector3.ZERO, olho)
		_malha(_esf(0.011, 6, 3), preto, Vector3(0, 0, 0.022), olho)
		olhos.append(olho)

		var palp := Node3D.new()
		palp.position = Vector3(0.05 * lado, 0.176, 0.152)
		palp.scale = Vector3(1, 0.02, 1)
		palp.visible = false
		cabeca_pivo.add_child(palp)
		_malha(_cx(0.056, 0.052, 0.012), pele, Vector3(0, -0.026, 0), palp)
		palpebras.append(palp)

		var sob := Node3D.new()
		sob.position = Vector3(0.05 * lado, 0.205, 0.105)
		cabeca_pivo.add_child(sob)
		_malha(_cx(0.05, 0.008, 0.008), preto, Vector3.ZERO, sob)
		sobrancelhas.append(sob)

		var lab := _malha(_cx(0.025, 0.008, 0.012), vermelho, Vector3(0.0125 * lado, 0.04, 0.116), cabeca_pivo)
		labios.append(lab)

	# interior da boca (abre quando fala ou ofega)
	boca_dentro = _malha(_cx(0.045, 0.012, 0.012), interior, Vector3(0, 0.04, 0.113), cabeca_pivo)
	boca_dentro.visible = false

	# braços: o ombro é a junta; o braço aponta para baixo e as poses giram o ombro
	for lado in [1.0, -1.0]:
		var ombro := Node3D.new()
		ombro.position = Vector3(0.26 * lado, 0.65, 0.0)
		tronco.add_child(ombro)
		_malha(_cil(0.045, 0.032, 0.39), roupa, Vector3(0, -0.195, 0), ombro)
		_malha(_esf(0.058, 8, 4), (pele if lado > 0.0 else mat_mao), Vector3(0, -0.42, 0), ombro)
		ombros.append(ombro)
		if lado < 0.0:
			luz_mao = OmniLight3D.new()
			luz_mao.light_color = Color(1.0, 0.85, 0.5)
			luz_mao.omni_range = 4.0
			luz_mao.light_energy = 0.0
			luz_mao.position = Vector3(0, -0.45, 0.05)
			ombro.add_child(luz_mao)

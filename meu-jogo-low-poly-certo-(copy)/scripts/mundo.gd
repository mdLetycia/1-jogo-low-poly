extends Node3D

const HumanoScript := preload("res://scripts/humano.gd")
const PilarScript := preload("res://scripts/pilar.gd")
const InimigoScript := preload("res://scripts/inimigo.gd")
const ChefeScript := preload("res://scripts/chefe.gd")

const PANORAMA_DIA := "res://assets/CeuDia.png"     # opcional: panorama do dia (senão usa um céu gerado)
const MUSICAS := [
	"res://assets/audio/musica_mundo.ogg",
	"res://assets/audio/musica_mundo.mp3",
	"res://assets/audio/musica_mundo.wav",
]
const AMBIENTES := [
	"res://assets/audio/ambiente_praia.ogg",
	"res://assets/audio/ambiente_praia.mp3",
	"res://assets/audio/ambiente_praia.wav",
]
const FORCAR_TOQUE := false     # true = mostra os controles de celular no PC (para testar)
const PULAR_INTRO := false      # true = pula a cena do despertar (para testar o jogo)
const CARREGAR_NO_PILAR := false  # true = ao carregar o save, volta no último pilar ativado
const DIST_PILAR := 85.0        # distância da praia até o pilar
const DIST_SOMBRAS := 36.0      # distância do pilar até o grupo de sombras

# batalha
const VIDA_JOGADOR := 100
const DANO_MIN := 9             # dano do golpe do protagonista
const DANO_MAX := 13
const ALCANCE_GOLPE := 2.7      # alcance do golpe (metros)
const RAIO_CURA := 4.5          # perto do pilar ativado, a vida se recupera
const CURA_POR_SEG := 25.0
const NOME_ALIADA := "Lys"   # nome mostrado no diálogo da personagem laranja
const NOME_DOLLY := "Dolly"   # filha da enfermeira
const CENA_ENFERMARIA := "res://scenes/enfermaria.tscn"   # interior da enfermaria (ainda não existe)
const NOME_SUPORTE := "Kael"  # nome do personagem masculino de suporte
const DANO_SUPORTE_MIN := 7
const DANO_SUPORTE_MAX := 10
const DANO_ALIADA_MIN := 12
const DANO_ALIADA_MAX := 17
const DIST_CHEFE := 16.0        # distância do grupo de sombras até onde o chefe surge
const KNOCKBACK_JOGADOR := 5.0   # quanto o protagonista é empurrado ao apanhar (menor = menos)
const INVULNERAVEL := 0.7

# movimento ágil
const VEL_ESCOLTA := 6.0          # velocidade da Lys e do Kael correndo até a cidade
const DASH_VEL := 30.0           # dash: arrancada rápida em linha reta
const DASH_DUR := 0.22
const CARGAS_DASH := 2           # dá para encadear 2 dashes
const RECARGA_DASH := 1.3
const ESQ_VEL := 14.0            # esquiva: rolamento com invulnerabilidade
const ESQ_DUR := 0.42
const ESQ_INVUL := 0.32
const ESQ_RECARGA := 0.25
const LUNGE_DUR := 0.12          # o golpe dá um passo em direção ao inimigo       # segundos sem levar dano depois de ser atingido

# terreno
const N := 128                  # células por lado
const CELULA := 3.2
const R_ILHA := 190.0
const ALTURA_MAX := 46.0
const SEMENTE := 1234

# jogador
const VEL_ANDAR := 4.5
const VEL_TROTE := 6.3          # Tab liga/desliga o trote (corrida lenta)
const VEL_CORRER := 8.5         # Shift segurado: corrida rápida (sem gastar fôlego)
const TEMPO_SEGURAR := 0.2      # Shift apertado por menos que isso = só dash
const DASH_AO_APERTAR := false  # true = o dash sai assim que aperta Shift (e segurar continua correndo)
const VEL_PULO := 7.0
const GRAVIDADE := 22.0
const DIST_CAMERA := 5.2
const PITCH_INICIAL := -0.2
const SENS_MOUSE := 0.0025
const SENS_TOQUE := 0.006
const JOY_RAIO := 110.0
const NOME_PROTAGONISTA := ""   # vazio = usa o nome salvo (se houver); senão fica sem nome
const CPS := 32.0               # letras por segundo no diálogo

# passos do tutorial
const PASSOS := [
	{"pc": ["W", "A", "S", "D"], "toque": ["Joystick"],
	 "txt_pc": "Mover", "txt_toque": "Arraste no lado esquerdo da tela"},
	{"pc": ["Tab"], "toque": ["Trote"],
	 "txt_pc": "Alterna entre andar e trotar", "txt_toque": "Alterna entre andar e trotar"},
	{"pc": ["Shift"], "toque": ["Dash"],
	 "txt_pc": "Segure para correr rápido (sem gastar fôlego)", "txt_toque": "Segure para correr rápido"},
	{"pc": ["Shift"], "toque": ["Dash"],
	 "txt_pc": "Aperte rápido para dar um dash", "txt_toque": "Toque rápido para dar um dash"},
	{"pc": ["Espaço"], "toque": ["Pular"],
	 "txt_pc": "Pular", "txt_toque": "Pular"},
	{"pc": ["X"], "toque": ["Atacar"],
	 "txt_pc": "Atacar", "txt_toque": "Atacar"},
]

signal combate_comecou
signal combate_vencido
signal chefe_vencido

enum Modo { CINE, JOGO }
var modo := Modo.CINE

var tipo := "feminino"
var env: Environment
var sol: DirectionalLight3D
var camera: Camera3D
var ruido_a: FastNoiseLite
var ruido_b: FastNoiseLite
var mat_mar: StandardMaterial3D
var spawn := Vector3.ZERO
var pilar_pos := Vector3.ZERO
var sombras_pos := Vector3.ZERO
var pilares: Array = []
var inimigos: Array = []
var cena_pilar := false
var combate_iniciado := false
var vida := VIDA_JOGADOR
var vida_ate := 0.0
var jogador_vivo := true
var chefe_pos := Vector3.ZERO
var chefe: Node3D = null
var cena_combate := false          # true durante as cutscenes do chefe e da aliada
var congelar_inimigos := false     # true = inimigos ficam parados (cutscenes)
var membros: Array = []            # time: um dicionário por personagem
var idx_ativo := 0
var troca_ate := 0.0
var hud_time: Control
var dica_time: Label
var dash_ate := 0.0
var dash_dir := Vector3.ZERO
var dash_invul_ate := 0.0
var cargas_dash := CARGAS_DASH
var recarga_dash := 0.0
var esq_ate := 0.0
var esq_ini := 0.0
var esq_dir := Vector3.ZERO
var esq_invul_ate := 0.0
var esq_cd_ate := 0.0
var perfeita_cd := 0.0
var lunge_ate := 0.0
var lunge_vel := Vector3.ZERO
var atk_buf_ate := 0.0
var pulo_buf_ate := 0.0
var coyote_ate := 0.0
var deslize_fim := false
var fant_prox := 0.0
var dash_pedido := false
var esq_pedido := false
var tween_rolo: Tween = null
var ts_base := 1.0
var lento_ativo := false
var lento_id := 0
var empurrao := Vector3.ZERO
var cura_acum := 0.0
var cura_pulso := 0.0
var curando := false
var hud_vida: Control
var hud_fill: ColorRect
var hud_txt: Label
var flash_dano: ColorRect

var jogador: CharacterBody3D
var visual: Node3D
var humano
var cam_pivot: Node3D
var spring: SpringArm3D

var tempo := 0.0
var cam_yaw := 0.0
var cam_pitch := PITCH_INICIAL
var cine_pos := Vector3.ZERO
var cine_look := Vector3.ZERO
var shake := 0.0
var atacando_ate := 0.0
var clique := false
var cidade_pos := Vector3.ZERO       # onde fica Vindemia (fim da estrada, mais adiante)
var estrada: Array[Vector3] = []     # pontos do caminho até a cidade
var escolta: Array = []              # Lys e Kael correndo como NPCs temporários
var escolta_i := 0
var escolta_on := false
var escolta_fala := false
var escolta_espera := false
var conversa_fim := true             # false enquanto a conversa da corrida está rolando
var escolha_res := -1               # resultado do menu de escolha (-1 = aguardando)
var escolha_n := 0                  # quantas opções o menu atual tem (0 = menu fechado)
var painel_escolha: Control
var escolha_box: VBoxContainer
var painel_nome: Control
var nome_edit: LineEdit
var nome_ok: Button
var nome_res := ""
var nome_pronto := false
var evt_pulou := false
var evt_atacou := false
var evt_trote := false
var evt_dashou := false
var trote_on := false              # Tab: true = trote em vez de andar
var shift_ant := false
var shift_t := 0.0
var shift_corrida := false         # Shift segurado: corrida rápida

# interface
var fade: ColorRect
var controles: Control
var caixa: Control
var nome_label: Label
var fala_label: Label
var seta: Label
var painel_tut: PanelContainer
var titulo_tut: Label
var linhas_box: VBoxContainer
var tut_rows: Array[HBoxContainer] = []
var tut_labels: Array[Label] = []
var tut_ativo := false
var tut_passo := 0
var tut_acum := 0.0

# toque
var modo_toque := false
var t_joy := -1
var t_cam := -1
var joy_centro := Vector2.ZERO
var joy_pos := Vector2.ZERO
var joy_vec := Vector2.ZERO
var t_botoes := {"pular": -1, "atacar": -1, "correr": -1, "trocar": -1, "dash": -1, "esquivar": -1}
var correr_toque := false
var pular_pedido := false
var atacar_pedido := false

func _ready() -> void:
	tipo = str(Global.dados.get("corpo", "feminino"))
	if tipo != "masculino":
		tipo = "feminino"
	modo_toque = FORCAR_TOQUE or OS.has_feature("mobile")
	_montar_entradas()
	_iniciar_ruido()
	spawn = _achar_praia()
	pilar_pos = _achar_plano(Vector2(spawn.x, spawn.z - DIST_PILAR))
	sombras_pos = _achar_plano(Vector2(pilar_pos.x, pilar_pos.z - DIST_SOMBRAS))
	chefe_pos = _achar_plano(Vector2(sombras_pos.x, sombras_pos.z - DIST_CHEFE), sombras_pos, DIST_CHEFE * 0.75)
	_tracar_estrada()
	_montar_ambiente()
	_montar_terreno()
	_montar_mar()
	_montar_ilhas_distantes()
	_plantar()
	_criar_jogador(spawn)
	_criar_pilar()
	_montar_ui()
	_tocar_loop(MUSICAS, -10.0)
	_tocar_loop(AMBIENTES, -8.0)
	_iniciar_autosave()
	_iniciar_time()
	combate_vencido.connect(_apos_sombras)
	combate_comecou.connect(_dica_combate)
	chefe_vencido.connect(_apos_chefe)

	var ja_viu := bool(Global.dados.get("cutscene5_vista", false)) or PULAR_INTRO
	if ja_viu:
		_restaurar_posicao()
		if Global.pilar_ativado("fecundia"):
			var et := _etapa()
			if et == 0:
				_criar_inimigos()
			elif et < 3:
				_criar_chefe()
		_fade(Color.BLACK, 1.0, 0.0, 0.8)
		_comecar_jogo()
		if _etapa() == 4:
			_retomar_escolta()
		elif _etapa() == 6 and not bool(Global.dados.get("cutscene_enfermaria_vista", false)):
			_cena_enfermaria()
		elif _etapa() == 5 and not bool(Global.dados.get("cutscene_fecundia_vista", false)):
			_retomar_escolta()
			_fim_escolta()
		if _etapa() >= 3:
			_apos_chefe()      # chefe já caiu; a função só toca a cena se ela ainda não foi vista
	else:
		_intro()

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if lento_ativo:
		Engine.time_scale = ts_base
	if modo == Modo.JOGO and jogador_vivo and jogador != null and jogador.is_inside_tree():
		_autosalvar()

# ---------------------------------------------------------------- entradas

func _montar_entradas() -> void:
	var mapa := {
		"mover_frente": [KEY_W, KEY_UP],
		"mover_tras": [KEY_S, KEY_DOWN],
		"mover_esq": [KEY_A, KEY_LEFT],
		"mover_dir": [KEY_D, KEY_RIGHT],
		"trote": [KEY_TAB],
		"pular": [KEY_SPACE],
		"atacar": [KEY_X],
		"dash": [KEY_SHIFT],
		"esquivar": [KEY_CTRL],
	}
	for acao in mapa:
		if InputMap.has_action(acao):
			continue
		InputMap.add_action(acao)
		for tecla in mapa[acao]:
			var e := InputEventKey.new()
			e.physical_keycode = tecla
			InputMap.action_add_event(acao, e)
	var mb := InputEventMouseButton.new()          # esquiva também no botão direito do mouse
	mb.button_index = MOUSE_BUTTON_RIGHT
	if not InputMap.action_has_event("esquivar", mb):
		InputMap.action_add_event("esquivar", mb)

# ---------------------------------------------------------------- terreno

func _iniciar_ruido() -> void:
	ruido_a = FastNoiseLite.new()
	ruido_a.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido_a.frequency = 0.008
	ruido_a.fractal_octaves = 4
	ruido_a.seed = SEMENTE
	ruido_b = FastNoiseLite.new()
	ruido_b.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido_b.frequency = 0.0045
	ruido_b.fractal_octaves = 3
	ruido_b.seed = SEMENTE + 99

# altura do terreno em (x, z): praia suave na costa e relevo no interior
func _altura(x: float, z: float) -> float:
	var d := Vector2(x, z).length() / R_ILHA
	var rampa := clampf((d - 0.80) / 0.20, 0.0, 1.0)
	var costa := 1.2 - rampa * 4.2                     # +1.2 m na areia, -3 m no fundo do mar
	var t := clampf((0.80 - d) / 0.35, 0.0, 1.0)
	var interior := t * t * (3.0 - 2.0 * t)
	var a := ruido_a.get_noise_2d(x, z) * 0.5 + 0.5
	var b := ruido_b.get_noise_2d(x, z) * 0.5 + 0.5
	var terra := (pow(a, 1.5) * 0.7 + pow(b, 2.2) * 0.8) * ALTURA_MAX
	return costa + terra * interior

# o protagonista acorda na praia do sul da ilha
func _achar_praia() -> Vector3:
	var z := R_ILHA * 1.05
	while z > 0.0:
		if _altura(0.0, z) > 0.9:
			break
		z -= 0.5
	return Vector3(0.0, _altura(0.0, z), z)

func _cor_terreno(h: float, ny: float, rnd: float) -> Color:
	var c: Color
	if h < -1.2:
		c = Color(0.16, 0.38, 0.46)
	elif h < 0.5:
		c = Color(0.80, 0.74, 0.55)
	elif h < 2.0:
		c = Color(0.89, 0.82, 0.60)
	elif ny < 0.72 or h > 34.0:
		c = Color(0.46, 0.44, 0.44)
	elif h > 22.0:
		c = Color(0.42, 0.50, 0.32)
	else:
		c = Color(0.30, 0.56, 0.27)
	var k := 0.9 + rnd * 0.2
	return Color(c.r * k, c.g * k, c.b * k)

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, rnd: float) -> void:
	var n := (c - a).cross(b - a).normalized()
	var cor := _cor_terreno((a.y + b.y + c.y) / 3.0, n.y, rnd)
	for p in [a, b, c]:
		st.set_color(cor)
		st.set_normal(n)
		st.add_vertex(p)

func _montar_terreno() -> void:
	var lado := N * CELULA
	var ini := -lado * 0.5
	var w := N + 1
	var hs := PackedFloat32Array()
	hs.resize(w * w)
	for j in w:
		for i in w:
			hs[j * w + i] = _altura(ini + i * CELULA, ini + j * CELULA)

	var rng := RandomNumberGenerator.new()
	rng.seed = SEMENTE
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in N:
		for i in N:
			var x0 := ini + i * CELULA
			var z0 := ini + j * CELULA
			var p00 := Vector3(x0, hs[j * w + i], z0)
			var p10 := Vector3(x0 + CELULA, hs[j * w + i + 1], z0)
			var p01 := Vector3(x0, hs[(j + 1) * w + i], z0 + CELULA)
			var p11 := Vector3(x0 + CELULA, hs[(j + 1) * w + i + 1], z0 + CELULA)
			_tri(st, p00, p10, p01, rng.randf())
			_tri(st, p10, p11, p01, rng.randf())
	var malha := st.commit()

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	malha.surface_set_material(0, mat)

	var corpo := StaticBody3D.new()
	add_child(corpo)
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	corpo.add_child(mi)
	var col := CollisionShape3D.new()
	col.shape = malha.create_trimesh_shape()
	corpo.add_child(col)

func _montar_mar() -> void:
	mat_mar = StandardMaterial3D.new()
	mat_mar.albedo_color = Color(0.10, 0.48, 0.62, 0.70)
	mat_mar.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_mar.roughness = 0.08
	mat_mar.metallic = 0.15
	var rr := FastNoiseLite.new()
	rr.frequency = 0.02
	var nt := NoiseTexture2D.new()
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 6.0
	nt.noise = rr
	mat_mar.normal_enabled = true
	mat_mar.normal_texture = nt
	mat_mar.normal_scale = 0.6
	mat_mar.uv1_scale = Vector3(220, 220, 1)

	var mar := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(6000, 6000)
	mar.mesh = pl
	mar.material_override = mat_mar
	mar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mar)

	# fundo profundo (além da borda do terreno)
	var fundo := MeshInstance3D.new()
	var pf := PlaneMesh.new()
	pf.size = Vector2(6000, 6000)
	fundo.mesh = pf
	var mf := StandardMaterial3D.new()
	mf.albedo_color = Color(0.04, 0.16, 0.26)
	mf.roughness = 1.0
	fundo.material_override = mf
	fundo.position.y = -3.2
	fundo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fundo)

func _montar_ilhas_distantes() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.40, 0.38)
	mat.roughness = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = SEMENTE + 3
	for i in 14:
		var a := rng.randf() * TAU
		var d := rng.randf_range(650.0, 1300.0)
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = rng.randf_range(60.0, 160.0)
		c.height = rng.randf_range(50.0, 160.0)
		c.radial_segments = 7
		var m := MeshInstance3D.new()
		m.mesh = c
		m.material_override = mat
		m.position = Vector3(cos(a) * d, c.height * 0.4 - 3.0, sin(a) * d)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)

# ---------------------------------------------------------------- vegetação

func _multimesh(malha: Mesh, mat: Material, trs: Array[Transform3D]) -> void:
	if trs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = malha
	mm.instance_count = trs.size()
	for i in trs.size():
		mm.set_instance_transform(i, trs[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = mat
	add_child(inst)

func _plantar() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEMENTE + 5
	var t_tronco: Array[Transform3D] = []
	var t_palma: Array[Transform3D] = []
	var t_copa: Array[Transform3D] = []
	var t_pinho: Array[Transform3D] = []
	var t_pedra: Array[Transform3D] = []

	var feitas := 0
	var tentativas := 0
	while feitas < 380 and tentativas < 5000:
		tentativas += 1
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * R_ILHA * 0.92
		var x := cos(a) * r
		var z := sin(a) * r
		var h := _altura(x, z)
		if h < 0.9:
			continue
		if Vector2(x, z).distance_to(Vector2(spawn.x, spawn.z)) < 10.0 or _perto_de_marcos(x, z, 8.0):
			continue
		var inc := absf(_altura(x + 1.5, z) - h) + absf(_altura(x, z + 1.5) - h)
		if inc > 3.2:
			continue
		var pos := Vector3(x, h, z)
		feitas += 1

		if h < 3.5:
			# palmeira
			var ht := rng.randf_range(4.5, 7.5)
			var lean := deg_to_rad(rng.randf_range(2.0, 9.0))
			var al := rng.randf() * TAU
			var b := Basis(Vector3(cos(al), 0.0, sin(al)), lean)
			t_tronco.append(Transform3D(b * Basis.from_scale(Vector3(1.0, ht, 1.0)),
				pos + b * Vector3(0.0, ht * 0.5, 0.0)))
			var topo := pos + b * Vector3(0.0, ht, 0.0)
			for k in 6:
				var th := k * TAU / 6.0 + rng.randf_range(-0.2, 0.2)
				var rot := b * Basis(Vector3.UP, th) * Basis(Vector3.BACK, deg_to_rad(-24.0 + rng.randf_range(-6.0, 6.0)))
				t_palma.append(Transform3D(rot, topo + rot * Vector3(1.15, 0.0, 0.0)))
		elif h < 20.0:
			# árvore de copa redonda
			var ht2 := rng.randf_range(2.4, 4.0)
			t_tronco.append(Transform3D(Basis.from_scale(Vector3(1.3, ht2, 1.3)), pos + Vector3(0.0, ht2 * 0.5, 0.0)))
			var s := rng.randf_range(1.8, 2.8)
			t_copa.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s, s * 0.85, s)),
				pos + Vector3(0.0, ht2 + s * 0.5, 0.0)))
		elif h < 30.0:
			# pinheiro
			var hp := rng.randf_range(5.0, 9.0)
			t_tronco.append(Transform3D(Basis.from_scale(Vector3(1.0, 1.5, 1.0)), pos + Vector3(0.0, 0.75, 0.0)))
			t_pinho.append(Transform3D(Basis.from_scale(Vector3(hp * 0.28, hp, hp * 0.28)),
				pos + Vector3(0.0, 1.0 + hp * 0.5, 0.0)))
		else:
			feitas -= 1

	# pedras
	for i in 70:
		var a2 := rng.randf() * TAU
		var r2 := sqrt(rng.randf()) * R_ILHA * 0.95
		var x2 := cos(a2) * r2
		var z2 := sin(a2) * r2
		var h2 := _altura(x2, z2)
		if h2 < 0.4 or Vector2(x2, z2).distance_to(Vector2(spawn.x, spawn.z)) < 8.0 or _perto_de_marcos(x2, z2, 8.0):
			continue
		var e := rng.randf_range(0.6, 2.2)
		t_pedra.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(e, e * rng.randf_range(0.4, 0.9), e)),
			Vector3(x2, h2 - 0.1, z2)))

	var mat_tronco := StandardMaterial3D.new()
	mat_tronco.albedo_color = Color(0.40, 0.28, 0.18)
	mat_tronco.roughness = 1.0
	var mat_folha := StandardMaterial3D.new()
	mat_folha.albedo_color = Color(0.20, 0.55, 0.25)
	mat_folha.roughness = 1.0
	mat_folha.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mat_copa := StandardMaterial3D.new()
	mat_copa.albedo_color = Color(0.18, 0.46, 0.20)
	mat_copa.roughness = 1.0
	var mat_pinho := StandardMaterial3D.new()
	mat_pinho.albedo_color = Color(0.10, 0.32, 0.20)
	mat_pinho.roughness = 1.0
	var mat_pedra := StandardMaterial3D.new()
	mat_pedra.albedo_color = Color(0.48, 0.47, 0.50)
	mat_pedra.roughness = 1.0

	var m_tronco := CylinderMesh.new()
	m_tronco.top_radius = 0.13
	m_tronco.bottom_radius = 0.2
	m_tronco.height = 1.0
	m_tronco.radial_segments = 6
	var m_folha := BoxMesh.new()
	m_folha.size = Vector3(2.3, 0.04, 0.55)
	var m_copa := SphereMesh.new()
	m_copa.radius = 1.0
	m_copa.height = 2.0
	m_copa.radial_segments = 7
	m_copa.rings = 4
	var m_pinho := CylinderMesh.new()
	m_pinho.top_radius = 0.0
	m_pinho.bottom_radius = 1.0
	m_pinho.height = 1.0
	m_pinho.radial_segments = 7
	var m_pedra := SphereMesh.new()
	m_pedra.radius = 1.0
	m_pedra.height = 2.0
	m_pedra.radial_segments = 6
	m_pedra.rings = 3

	_multimesh(m_tronco, mat_tronco, t_tronco)
	_multimesh(m_folha, mat_folha, t_palma)
	_multimesh(m_copa, mat_copa, t_copa)
	_multimesh(m_pinho, mat_pinho, t_pinho)
	_multimesh(m_pedra, mat_pedra, t_pedra)

# ---------------------------------------------------------------- ambiente e jogador

func _montar_ambiente() -> void:
	var sky := Sky.new()
	if ResourceLoader.exists(PANORAMA_DIA):
		var pm := PanoramaSkyMaterial.new()
		pm.panorama = load(PANORAMA_DIA)
		sky.sky_material = pm
	else:
		var p := ProceduralSkyMaterial.new()
		p.sky_top_color = Color(0.22, 0.42, 0.78)
		p.sky_horizon_color = Color(0.95, 0.74, 0.58)
		p.sky_curve = 0.18
		p.ground_horizon_color = Color(0.95, 0.74, 0.58)
		p.ground_bottom_color = Color(0.25, 0.30, 0.40)
		sky.sky_material = p

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.86, 0.76, 0.68)
	env.fog_density = 0.0016
	env.fog_sky_affect = 0.4
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sol = DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-17.0, -32.0, 0.0)
	sol.light_color = Color(1.0, 0.84, 0.66)
	sol.light_energy = 1.4
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 140.0
	add_child(sol)

	camera = Camera3D.new()
	camera.far = 3000.0
	camera.fov = 65.0
	add_child(camera)

func _criar_jogador(p: Vector3) -> void:
	jogador = CharacterBody3D.new()
	jogador.collision_layer = 2
	jogador.collision_mask = 1
	jogador.floor_max_angle = deg_to_rad(52.0)
	jogador.floor_snap_length = 0.45
	jogador.position = p
	add_child(jogador)

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.8
	col.shape = cap
	col.position = Vector3(0, 0.9, 0)
	jogador.add_child(col)

	visual = Node3D.new()
	jogador.add_child(visual)
	humano = HumanoScript.new()
	humano.tipo = tipo
	visual.add_child(humano)

	# câmera de terceira pessoa (SpringArm evita atravessar o chão)
	cam_pivot = Node3D.new()
	add_child(cam_pivot)
	spring = SpringArm3D.new()
	spring.spring_length = DIST_CAMERA
	spring.margin = 0.3
	spring.collision_mask = 1
	var esf := SphereShape3D.new()
	esf.radius = 0.3
	spring.shape = esf
	cam_pivot.add_child(spring)

func _restaurar_posicao() -> void:
	var p = Global.dados.get("pos", null)
	if CARREGAR_NO_PILAR and Global.pilar_ativado(str(Global.dados.get("spawn_id", ""))):
		respawnar()
	elif p is Array and p.size() == 3:
		var v := Vector3(float(p[0]), float(p[1]), float(p[2]))
		if Vector2(v.x, v.z).length() < R_ILHA * 1.02:
			jogador.global_position = v + Vector3(0.0, 0.5, 0.0)
	visual.rotation_degrees.y = 180.0

func _iniciar_autosave() -> void:
	var t := Timer.new()
	t.wait_time = 15.0
	t.autostart = true
	t.timeout.connect(_autosalvar)
	add_child(t)

func _autosalvar() -> void:
	if modo != Modo.JOGO:
		return
	var p := jogador.global_position
	Global.dados["pos"] = [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)]
	Global.salvar()

func _tocar_loop(lista: Array, volume: float) -> void:
	var p := AudioStreamPlayer.new()
	add_child(p)
	for caminho in lista:
		if ResourceLoader.exists(caminho):
			p.stream = load(caminho)
			break
	if p.stream == null:
		return
	p.finished.connect(p.play)
	p.volume_db = -60.0
	p.play()
	create_tween().tween_property(p, "volume_db", volume, 3.0)

# ---------------------------------------------------------------- interface

func _montar_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)

	# controles de celular (desenhados por código)
	controles = Control.new()
	controles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controles.visible = false
	ui.add_child(controles)
	controles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controles.draw.connect(_desenhar_toque)

	# quadro do tutorial
	painel_tut = PanelContainer.new()
	var sbp := StyleBoxFlat.new()
	sbp.bg_color = Color(0, 0, 0, 0.55)
	sbp.set_corner_radius_all(16)
	sbp.content_margin_left = 24
	sbp.content_margin_right = 24
	sbp.content_margin_top = 18
	sbp.content_margin_bottom = 18
	painel_tut.add_theme_stylebox_override("panel", sbp)
	painel_tut.position = Vector2(40, 40)
	painel_tut.visible = false
	painel_tut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(painel_tut)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	painel_tut.add_child(v)
	titulo_tut = Label.new()
	titulo_tut.text = "Como jogar"
	titulo_tut.add_theme_font_size_override("font_size", 34)
	titulo_tut.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	v.add_child(titulo_tut)
	linhas_box = VBoxContainer.new()
	linhas_box.add_theme_constant_override("separation", 12)
	v.add_child(linhas_box)

	# caixa de diálogo
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

	# barra de vida do protagonista (topo, centro)
	hud_vida = Control.new()
	hud_vida.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_vida.visible = false
	ui.add_child(hud_vida)
	hud_vida.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hv_fundo := ColorRect.new()
	hv_fundo.color = Color(0, 0, 0, 0.6)
	hv_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_vida.add_child(hv_fundo)
	_ancorar(hv_fundo, 0.0, 520, -520, 28, 52)
	hud_fill = ColorRect.new()
	hud_fill.color = Color(0.9, 0.25, 0.3)
	hud_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hv_fundo.add_child(hud_fill)
	hud_fill.anchor_left = 0.0
	hud_fill.anchor_top = 0.0
	hud_fill.anchor_bottom = 1.0
	hud_fill.anchor_right = 1.0
	hud_fill.offset_left = 3
	hud_fill.offset_top = 3
	hud_fill.offset_bottom = -3
	hud_fill.offset_right = -3
	hud_txt = Label.new()
	hud_txt.add_theme_font_size_override("font_size", 20)
	hud_txt.add_theme_color_override("font_outline_color", Color.BLACK)
	hud_txt.add_theme_constant_override("outline_size", 5)
	hud_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_vida.add_child(hud_txt)
	_ancorar(hud_txt, 0.0, 520, -520, 26, 54)
	hud_time = Control.new()
	hud_time.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_vida.add_child(hud_time)
	hud_time.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_time.draw.connect(_desenhar_time)
	dica_time = Label.new()
	dica_time.add_theme_font_size_override("font_size", 28)
	dica_time.add_theme_color_override("font_outline_color", Color.BLACK)
	dica_time.add_theme_constant_override("outline_size", 6)
	dica_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dica_time.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dica_time.modulate = Color(1, 1, 1, 0)
	ui.add_child(dica_time)
	_ancorar(dica_time, 0.0, 300, -300, 70, 110)

	# clarão vermelho ao apanhar
	flash_dano = ColorRect.new()
	flash_dano.color = Color(0.9, 0.05, 0.1, 0.0)
	flash_dano.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(flash_dano)
	flash_dano.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# fade
	var camada := CanvasLayer.new()
	camada.layer = 10
	add_child(camada)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_montar_escolha_e_nome(ui)
	_reconstruir_tutorial()
	_atualizar_vida()

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

func _esperar(s: float) -> void:
	await get_tree().create_timer(s).timeout

# ---------------------------------------------------------------- pilares e sombras

# terreno razoavelmente plano (bom para o pilar e para o grupo de sombras)
func _plano_ok(x: float, z: float) -> bool:
	var h := _altura(x, z)
	if h < 2.0 or h > 16.0:
		return false
	for k in 8:
		var a := k * TAU / 8.0
		if absf(_altura(x + cos(a) * 3.0, z + sin(a) * 3.0) - h) > 0.9:
			return false
	return true

func _achar_plano(alvo: Vector2, evitar := Vector3.ZERO, dist_min := 0.0) -> Vector3:
	for r in range(0, 60, 3):
		var passos := 1 if r == 0 else 12
		for k in passos:
			var a := k * TAU / passos
			var x := alvo.x + cos(a) * r
			var z := alvo.y + sin(a) * r
			if dist_min > 0.0 and Vector2(x - evitar.x, z - evitar.z).length() < dist_min:
				continue
			if _plano_ok(x, z):
				return Vector3(x, _altura(x, z), z)
	return Vector3(alvo.x, _altura(alvo.x, alvo.y), alvo.y)

# usado pela vegetação: não plantar em cima do pilar nem das sombras
func _perto_de_marcos(x: float, z: float, raio: float) -> bool:
	var p := Vector2(x, z)
	for q in estrada:
		if p.distance_to(Vector2(q.x, q.z)) < 5.0:
			return true
	if p.distance_to(Vector2(cidade_pos.x, cidade_pos.z)) < 24.0:     # área da cidade sem árvores
		return true
	return p.distance_to(Vector2(pilar_pos.x, pilar_pos.z)) < raio \
		or p.distance_to(Vector2(sombras_pos.x, sombras_pos.z)) < raio + 2.0 \
		or p.distance_to(Vector2(chefe_pos.x, chefe_pos.z)) < raio + 4.0

func _criar_pilar() -> void:
	var p := PilarScript.new()
	p.id = "fecundia"
	p.nome_nacao = "Fecúndia"
	p.position = pilar_pos
	add_child(p)
	pilares.append(p)

# onde o protagonista reaparece ao voltar para este pilar
func _ponto_renascer(p) -> Vector3:
	var x: float = p.position.x
	var z: float = p.position.z + 2.6
	return Vector3(x, _altura(x, z), z)

# volta ao último pilar ativado (ou à praia, se nenhum). Também serve para derrota.
func respawnar() -> void:
	jogador.global_position = Global.posicao_spawn(spawn) + Vector3(0.0, 1.0, 0.0)
	jogador.velocity = Vector3.ZERO

func _verificar_pilares() -> void:
	if cena_pilar or modo != Modo.JOGO or not jogador.is_on_floor():
		return
	for p in pilares:
		if p.ativado or Global.pilar_ativado(p.id):
			continue
		var d: float = Vector2(jogador.global_position.x - p.global_position.x,
			jogador.global_position.z - p.global_position.z).length()
		if d < p.raio_gatilho:
			_cena_pilar(p)
			return

func _travar_controle() -> void:
	modo = Modo.CINE
	joy_vec = Vector2.ZERO
	t_joy = -1
	t_cam = -1
	correr_toque = false
	shift_ant = false
	shift_corrida = false
	shift_t = 0.0
	pular_pedido = false
	atacar_pedido = false
	for n in t_botoes:
		t_botoes[n] = -1
	controles.visible = false
	controles.queue_redraw()
	jogador.velocity = Vector3.ZERO
	atacando_ate = 0.0
	dash_ate = 0.0
	esq_ate = 0.0
	lunge_ate = 0.0
	atk_buf_ate = 0.0
	pulo_buf_ate = 0.0
	dash_pedido = false
	esq_pedido = false
	if tween_rolo != null:
		tween_rolo.kill()
	humano.transform = Transform3D.IDENTITY
	humano.vel_h = 0.0
	humano.correndo = false
	humano.no_ar = false

func _devolver_controle(yaw: float) -> void:
	shift_ant = false
	shift_corrida = false
	shift_t = 0.0
	cam_yaw = yaw
	cam_pitch = PITCH_INICIAL
	cam_pivot.global_position = jogador.global_position + Vector3(0.0, 1.55, 0.0)
	jogador.velocity = Vector3.ZERO
	humano.modo_loco = true
	humano.vel_h = 0.0
	humano.olhar_yaw = 0.0
	humano.olhar_pitch = 0.0
	humano.ofegante = 0.0
	shake = 0.0
	camera.fov = 65.0
	clique = false
	controles.visible = modo_toque
	if not modo_toque:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	modo = Modo.JOGO

func _chao_y(x: float, z: float, padrao: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, padrao + 3.0, z), Vector3(x, padrao - 6.0, z), 1)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return padrao
	return r["position"].y

func _passo_andar(v: float, de: Vector3, destino: Vector3, dir: Vector3) -> void:
	var x := lerpf(de.x, destino.x, v)
	var z := lerpf(de.z, destino.z, v)
	jogador.global_position = Vector3(x, _chao_y(x, z, jogador.global_position.y), z)
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(dir.x, dir.z), 0.12)

func _andar_ate(destino: Vector3, vel: float, dir: Vector3) -> void:
	var de := jogador.global_position
	var dist := Vector2(destino.x - de.x, destino.z - de.z).length()
	if dist < 0.05:
		return
	humano.modo_loco = true
	humano.vel_h = vel
	var t := create_tween()
	t.tween_method(_passo_andar.bind(de, destino, dir), 0.0, 1.0, dist / vel)
	await t.finished
	humano.vel_h = 0.0

func _orbita_pilar(v: float, centro: Vector3, ang0: float, r0: float, h0: float) -> void:
	var ang := ang0 + v * 1.15
	var r := lerpf(r0, 4.8, v)
	cine_pos = centro + Vector3(sin(ang) * r, lerpf(h0, 2.7, v), cos(ang) * r)
	cine_look = centro + Vector3(0.0, 1.7, 0.0)

# Primeiro contato com um pilar: o protagonista se aproxima, toca, o pilar desperta.
# Só roda uma vez por pilar (o estado fica salvo em Global).
func _cena_pilar(p) -> void:
	cena_pilar = true
	var tut_visivel := painel_tut.visible
	painel_tut.visible = false
	_travar_controle()

	# a câmera de cinema parte exatamente da câmera do jogo (sem salto)
	camera.fov = 65.0
	cine_pos = camera.global_position
	cine_look = cam_pivot.global_position + Vector3(0.0, 0.15, 0.0)

	var A: Vector3 = p.global_position
	var P0 := jogador.global_position
	var dist0 := Vector2(A.x - P0.x, A.z - P0.z).length()
	var dir := Vector3(A.x - P0.x, 0.0, A.z - P0.z).normalized()
	var lado := Vector3(-dir.z, 0.0, dir.x)
	var d_parada := minf(1.05, dist0)
	var d_pausa := clampf(dist0 - 0.5, d_parada, 4.5)
	var pausa := A - dir * d_pausa
	var parada := A - dir * d_parada
	pausa.y = P0.y
	parada.y = P0.y

	# 1) anda com cuidado até uma distância segura
	var t1 := maxf(2.5, (dist0 - d_pausa) / 1.9)
	var cam1 := create_tween().set_parallel(true)
	cam1.tween_property(self, "cine_pos", pausa - dir * 2.8 + lado * 2.6 + Vector3(0.0, 1.7, 0.0), t1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cam1.tween_property(self, "cine_look", (pausa + A) * 0.5 + Vector3(0.0, 1.6, 0.0), t1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _andar_ate(pausa, 1.9, dir)
	await cam1.finished

	# 2) observa, sem entender o que é aquilo
	var olha := create_tween()
	olha.tween_property(humano, "olhar_pitch", -16.0, 1.1).set_trans(Tween.TRANS_SINE)
	olha.tween_interval(0.5)
	olha.tween_property(humano, "olhar_yaw", -14.0, 0.7).set_trans(Tween.TRANS_SINE)
	olha.tween_property(humano, "olhar_yaw", 12.0, 1.0).set_trans(Tween.TRANS_SINE)
	olha.tween_property(humano, "olhar_yaw", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	olha.tween_property(humano, "olhar_pitch", -3.0, 0.8).set_trans(Tween.TRANS_SINE)
	var m := (pausa + A) * 0.5
	var cam2 := create_tween().set_parallel(true)
	cam2.tween_property(self, "cine_pos", m + lado * 3.6 + Vector3(0.0, 1.5, 0.0), 4.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cam2.tween_property(self, "cine_look", m + Vector3(0.0, 1.9, 0.0), 4.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await olha.finished

	# 3) chega mais perto, devagar
	var cam3 := create_tween().set_parallel(true)
	var m2 := (parada + A) * 0.5
	cam3.tween_property(self, "cine_pos", m2 + lado * 2.7 - dir * 0.4 + Vector3(0.0, 1.4, 0.0), 3.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cam3.tween_property(self, "cine_look", m2 + Vector3(0.0, 1.4, 0.0), 3.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _andar_ate(parada, 1.0, dir)
	await _esperar(0.3)

	# 4) estende a mão e toca o pilar
	humano.modo_loco = false
	humano.pose("em_pe", 0.0)
	await humano.pose("alcancar", 1.5).finished
	await _esperar(0.45)

	# 5) o pilar desperta: luz e partículas giram em volta dos dois
	Global.ativar_pilar(p.id, _ponto_renascer(p))
	p.ativar()
	var auras: Array = []
	for cfg in [[Color(1.0, 0.88, 0.55), 30, 0.9], [Color(0.65, 1.0, 0.9), 14, 1.2]]:
		var aura := PilarScript.criar_motes(cfg[0], cfg[1], cfg[2], 1.7)
		aura.position = Vector3(0.0, 0.4, 0.0)
		jogador.add_child(aura)
		aura.emitting = true
		auras.append(aura)

	var centro := m2
	var d0 := Vector3(cine_pos.x - centro.x, 0.0, cine_pos.z - centro.z)
	var orb := create_tween()
	orb.tween_method(_orbita_pilar.bind(centro, atan2(d0.x, d0.z), d0.length(), cine_pos.y - centro.y + 1.4),
		0.0, 1.0, 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	get_tree().create_timer(2.4).timeout.connect(func(): humano.pose("em_pe", 1.8))
	await _esperar(4.6)
	for a in auras:
		a.emitting = false
		get_tree().create_timer(5.0).timeout.connect(a.queue_free)
	await orb.finished

	# 6) a câmera volta suavemente para trás do protagonista e o controle é devolvido
	var yaw := atan2(-dir.x, -dir.z)
	var pivot := jogador.global_position + Vector3(0.0, 1.55, 0.0)
	var cam_fim := pivot + Vector3(sin(yaw) * cos(PITCH_INICIAL), -sin(PITCH_INICIAL),
		cos(yaw) * cos(PITCH_INICIAL)) * DIST_CAMERA
	var volta := create_tween().set_parallel(true)
	volta.tween_property(self, "cine_pos", cam_fim, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	volta.tween_property(self, "cine_look", pivot + Vector3(0.0, 0.15, 0.0), 2.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	volta.tween_property(camera, "fov", 65.0, 2.4)
	await volta.finished

	_devolver_controle(yaw)
	painel_tut.visible = tut_visivel
	cena_pilar = false
	_criar_inimigos()

# grupo de 3 sombras perto do pilar; só aparecem depois que ele é ativado
func _criar_inimigos() -> void:
	if not inimigos.is_empty():
		return
	for i in 3:
		var a := i * TAU / 3.0 + 0.6
		var x := sombras_pos.x + cos(a) * 3.2
		var z := sombras_pos.z + sin(a) * 3.2
		var e := InimigoScript.new()
		e.position = Vector3(x, _altura(x, z) + 0.2, z)
		e.slot = i * TAU / 3.0 + PI * 0.5
		e.alvo = jogador
		e.mundo = self
		e.contato.connect(_ao_contato_sombra)
		e.morreu.connect(_inimigo_morreu)
		add_child(e)
		inimigos.append(e)

# a primeira sombra que alcança o protagonista dá início ao combate
func _ao_contato_sombra() -> void:
	if combate_iniciado:
		return
	combate_iniciado = true
	combate_comecou.emit()

# ---------------------------------------------------------------- batalha

# as sombras só enxergam o protagonista se ele estiver vivo e no controle do jogador
func alvo_valido() -> bool:
	return jogador_vivo and modo == Modo.JOGO

func _inimigo_perto(raio: float) -> Node3D:
	var melhor: Node3D = null
	var d_min := raio
	for e in get_tree().get_nodes_in_group("inimigos"):
		var d: float = e.global_position.distance_to(jogador.global_position)
		if d < d_min:
			d_min = d
			melhor = e
	return melhor

# o golpe do protagonista acerta (chamado 0,18 s depois de apertar o botão)
func _golpe_acerta() -> void:
	if modo != Modo.JOGO or not jogador_vivo:
		return
	var origem := jogador.global_position
	var frente := Vector3(sin(visual.rotation.y), 0.0, cos(visual.rotation.y))
	var acertou := false
	for e in get_tree().get_nodes_in_group("inimigos"):
		var v: Vector3 = e.global_position - origem
		v.y = 0.0
		var d := v.length()
		if d > ALCANCE_GOLPE:
			continue
		if d > 1.0 and frente.dot(v / d) < 0.25:
			continue
		e.levar_dano(randi_range(int(membros[idx_ativo]["dmin"]), int(membros[idx_ativo]["dmax"])), origem)
		acertou = true
	if acertou:
		_tempo_lento(0.06, 0.05)             # micro-pausa no impacto
		tremer(0.25)

# perto de um pilar ativado a vida volta aos poucos (e o pilar pulsa)
func _curar_no_pilar(delta: float) -> void:
	var perto = null
	if modo == Modo.JOGO and jogador_vivo and _time_ferido():
		for p in pilares:
			if not p.ativado:
				continue
			var d: float = Vector2(jogador.global_position.x - p.global_position.x,
				jogador.global_position.z - p.global_position.z).length()
			if d < RAIO_CURA:
				perto = p
				break
	if perto == null:
		curando = false
		cura_acum = 0.0
		return
	if not curando:
		curando = true
		cura_pulso = 0.0
	cura_pulso -= delta
	if cura_pulso <= 0.0:
		cura_pulso = 1.2
		perto._onda(0.0)
	cura_acum += CURA_POR_SEG * delta
	var n := int(cura_acum)
	if n >= 1:
		cura_acum -= n
		vida = mini(vida + n, VIDA_JOGADOR)
		for k in membros.size():
			if k != idx_ativo:
				membros[k]["vida"] = mini(int(membros[k]["vida"]) + n, VIDA_JOGADOR)
		_atualizar_vida()
		if int(tempo * 2.0) != int((tempo - delta) * 2.0):
			numero_dano(jogador.global_position + Vector3(0.0, 2.3, 0.0), "+", Color(0.55, 1.0, 0.65))

func _time_ferido() -> bool:
	if vida < VIDA_JOGADOR:
		return true
	for mb in membros:
		if int(mb["vida"]) < VIDA_JOGADOR:
			return true
	return false

# uma sombra acertou o protagonista
func dano_no_jogador(valor: int, de: Vector3) -> void:
	if not alvo_valido() or tempo < vida_ate:
		return
	if tempo < esq_invul_ate:                # a esquiva evitou o golpe
		_esquiva_perfeita()
		return
	if tempo < dash_invul_ate:
		return
	vida = maxi(vida - valor, 1 if _etapa() == 1 else 0)    # antes da aliada chegar, não morre
	vida_ate = tempo + INVULNERAVEL
	var d := jogador.global_position - de
	d.y = 0.0
	if d.length() > 0.01:
		empurrao = d.normalized() * KNOCKBACK_JOGADOR
	numero_dano(jogador.global_position + Vector3(0.0, 2.3, 0.0), str(valor), Color(1.0, 0.35, 0.35))
	flash_dano.color = Color(0.9, 0.05, 0.1, 0.35)
	create_tween().tween_property(flash_dano, "color:a", 0.0, 0.45)
	_atualizar_vida()
	if vida <= 0:
		membros[idx_ativo]["vida"] = 0
		var prox := _proximo_vivo()
		if prox >= 0:
			_trocar(prox, true)          # quem caiu sai de campo; o próximo assume
		else:
			_derrota()
	elif _etapa() == 1 and not cena_combate and vida <= VIDA_JOGADOR * 0.4:
		_cena_aliada()

func _atualizar_vida() -> void:
	if not membros.is_empty():
		membros[idx_ativo]["vida"] = vida
	if hud_time != null:
		hud_time.queue_redraw()
	hud_fill.anchor_right = clampf(float(vida) / VIDA_JOGADOR, 0.0, 1.0)
	hud_txt.text = "%d / %d" % [vida, VIDA_JOGADOR]

# número flutuante (dano)
func numero_dano(pos: Vector3, texto: String, cor: Color) -> void:
	var l := Label3D.new()
	l.text = texto
	l.font_size = 96
	l.pixel_size = 0.007
	l.modulate = cor
	l.outline_modulate = Color.BLACK
	l.outline_size = 16
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos
	add_child(l)
	var t := create_tween().set_parallel(true)
	t.tween_property(l, "position:y", pos.y + 1.1, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	t.chain().tween_callback(l.queue_free)

func _inimigo_morreu(_e) -> void:
	for x in inimigos:
		if is_instance_valid(x) and x.estado != 7:      # 7 = MORTO
			return
	combate_vencido.emit()

# vida zerada: desmaia, escurece, volta ao último pilar com a vida cheia
func _derrota() -> void:
	jogador_vivo = false
	_travar_controle()
	cine_pos = camera.global_position
	cine_look = jogador.global_position + Vector3(0.0, 0.9, 0.0)
	humano.modo_loco = false
	humano.pose("deitado", 0.7)
	await _esperar(0.9)
	await _fade(Color.BLACK, 0.0, 1.0, 1.0).finished
	await _esperar(0.4)
	respawnar()
	visual.rotation.y = PI                       # olha para o pilar
	humano.pose("em_pe", 0.0)
	vida = VIDA_JOGADOR
	for mb in membros:
		mb["vida"] = VIDA_JOGADOR
	_atualizar_vida()
	empurrao = Vector3.ZERO
	await _esperar(0.3)
	_devolver_controle(0.0)
	jogador_vivo = true
	vida_ate = tempo + 1.5
	await _fade(Color.BLACK, 1.0, 0.0, 1.0).finished

# ---------------------------------------------------------------- time (troca de personagem)

func _etapa() -> int:
	return int(Global.dados.get("etapa", 0))

func _cor_membro(t: String) -> Color:
	if t == "laranja":
		return Color(1.0, 0.55, 0.15)
	if t == "suporte":
		return Color(0.35, 0.85, 0.6)
	if t == "masculino":
		return Color(0.45, 0.65, 1.0)
	return Color(0.95, 0.55, 0.75)

func _registrar_membro(nome: String, t: String, h: Node3D, dmin: int, dmax: int) -> void:
	membros.append({"nome": nome, "tipo": t, "humano": h, "vida": VIDA_JOGADOR,
		"dmin": dmin, "dmax": dmax, "cor": _cor_membro(t)})

func _iniciar_time() -> void:
	membros.clear()
	idx_ativo = 0
	_registrar_membro("Protagonista", tipo, humano, DANO_MIN, DANO_MAX)
	if _etapa() == 2 or _etapa() == 3:      # a aliada já entrou no time (save carregado); depois da escolta eles saem
		var a := HumanoScript.new()
		a.tipo = "laranja"
		visual.add_child(a)
		a.visible = false
		_registrar_membro(NOME_ALIADA, "laranja", a, DANO_ALIADA_MIN, DANO_ALIADA_MAX)
		var su := HumanoScript.new()
		su.tipo = "suporte"
		visual.add_child(su)
		su.visible = false
		_registrar_membro(NOME_SUPORTE, "suporte", su, DANO_SUPORTE_MIN, DANO_SUPORTE_MAX)
	_atualizar_vida()

func _proximo_vivo() -> int:
	for i in range(1, membros.size()):
		var j := (idx_ativo + i) % membros.size()
		if int(membros[j]["vida"]) > 0:
			return j
	return -1

func _trocar_proximo() -> void:
	if membros.size() < 2:
		return
	_trocar((idx_ativo + 1) % membros.size())

func _trocar(idx: int, forcado := false) -> void:
	if idx == idx_ativo or idx < 0 or idx >= membros.size():
		return
	if not forcado and (modo != Modo.JOGO or not jogador_vivo or tempo < troca_ate or tempo < atacando_ate):
		return
	if int(membros[idx]["vida"]) <= 0:
		return
	membros[idx_ativo]["vida"] = vida
	_puff(jogador.global_position, membros[idx]["cor"])
	var velho = humano
	velho.visible = false
	velho.vel_h = 0.0
	velho.correndo = false
	humano = membros[idx]["humano"]
	humano.visible = true
	humano.modo_loco = true
	humano.ofegante = 0.0
	idx_ativo = idx
	vida = int(membros[idx]["vida"])
	troca_ate = tempo + 1.0
	if forcado:
		vida_ate = tempo + 1.2
	_atualizar_vida()

func _puff(pos: Vector3, cor: Color) -> void:
	var p := PilarScript.criar_motes(cor, 24, 0.5, 1.4)
	p.position = pos + Vector3(0.0, 0.5, 0.0)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(0.5).timeout.connect(func(): p.emitting = false)
	get_tree().create_timer(5.0).timeout.connect(p.queue_free)

# retratos do time no canto direito (desenhados por código)
func _desenhar_time() -> void:
	var tela := get_viewport().get_visible_rect().size
	for i in CARGAS_DASH:                       # cargas do dash, logo abaixo da barra de vida
		var pc := Vector2(tela.x * 0.5 - 14.0 + i * 28.0, 70.0)
		hud_time.draw_circle(pc, 8.0, Color(0.4, 0.9, 1.0, 0.95) if i < cargas_dash else Color(0.4, 0.4, 0.45, 0.5))
	if membros.size() < 2:
		return
	var fonte := ThemeDB.fallback_font
	var s := get_viewport().get_visible_rect().size
	for i in membros.size():
		var mb: Dictionary = membros[i]
		var c := Vector2(s.x - 70.0, 110.0 + i * 86.0)
		var vivo := int(mb["vida"]) > 0
		var cor: Color = mb["cor"] if vivo else Color(0.35, 0.35, 0.38)
		var frac := clampf(float(mb["vida"]) / VIDA_JOGADOR, 0.0, 1.0)
		hud_time.draw_rect(Rect2(c.x - 190.0, c.y - 6.0, 150.0, 12.0), Color(0, 0, 0, 0.6))
		hud_time.draw_rect(Rect2(c.x - 188.0, c.y - 4.0, 146.0 * frac, 8.0), Color(0.9, 0.25, 0.3) if vivo else Color(0.4, 0.4, 0.4))
		hud_time.draw_circle(c, 30.0, Color(cor.r, cor.g, cor.b, 0.9))
		hud_time.draw_arc(c, 30.0, 0.0, TAU, 40, Color.WHITE if i == idx_ativo else Color(1, 1, 1, 0.35), 5.0 if i == idx_ativo else 2.0)
		hud_time.draw_string(fonte, c + Vector2(-30.0, 10.0), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 60.0, 30, Color.WHITE)

func _dica_combate() -> void:
	if bool(Global.dados.get("dica_esquiva", false)):
		return
	Global.dados["dica_esquiva"] = true
	Global.salvar()
	_mostrar_dica("Dash: toque rápido / segure para correr   |   Esquiva e Trote nos botões" if modo_toque else "Shift = dash (toque) ou corrida (segurando)   |   Ctrl ou botão direito = esquiva   |   Tab = trote")

func _mostrar_dica(texto: String) -> void:
	dica_time.text = texto
	var t := create_tween()
	t.tween_property(dica_time, "modulate:a", 1.0, 0.5)
	t.tween_interval(6.0)
	t.tween_property(dica_time, "modulate:a", 0.0, 1.0)

# tremor curto de câmera durante o jogo
func tremer(forca: float) -> void:
	var t := create_tween()
	t.tween_method(_passo_tremor.bind(forca), 1.0, 0.0, 0.4)

func _passo_tremor(v: float, forca: float) -> void:
	camera.h_offset = randf_range(-1.0, 1.0) * forca * 0.2 * v
	camera.v_offset = randf_range(-1.0, 1.0) * forca * 0.2 * v

# ---------------------------------------------------------------- chefe e aliada

func _cam_inicio() -> void:
	camera.fov = 65.0
	cine_pos = camera.global_position
	cine_look = cam_pivot.global_position + Vector3(0.0, 0.15, 0.0)

func _cam_para(pos: Vector3, look: Vector3, dur: float) -> Tween:
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "cine_pos", pos, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "cine_look", look, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return t

# a câmera de cinema termina exatamente onde a câmera do jogo ficará (sem salto)
func _cam_voltar_jogo(yaw: float, dur: float) -> void:
	var pivot := jogador.global_position + Vector3(0.0, 1.55, 0.0)
	var cam_fim := pivot + Vector3(sin(yaw) * cos(PITCH_INICIAL), -sin(PITCH_INICIAL),
		cos(yaw) * cos(PITCH_INICIAL)) * DIST_CAMERA
	var t := _cam_para(cam_fim, pivot + Vector3(0.0, 0.15, 0.0), dur)
	t.tween_property(camera, "fov", 65.0, dur)
	await t.finished

func _criar_chefe() -> void:
	if chefe != null and is_instance_valid(chefe):
		return
	var e := ChefeScript.new()
	e.position = Vector3(chefe_pos.x, _altura(chefe_pos.x, chefe_pos.z) + 0.2, chefe_pos.z)
	e.alvo = jogador
	e.mundo = self
	e.morreu.connect(_chefe_morreu)
	add_child(e)
	chefe = e

func _chefe_morreu(_e) -> void:
	Global.dados["etapa"] = 3
	Global.salvar()
	chefe_vencido.emit()

# todas as sombras caíram: o chefe surge
func _apos_sombras() -> void:
	if _etapa() >= 1:
		return
	await _esperar(1.8)
	_cena_chefe()

func _cena_chefe() -> void:
	while not alvo_valido() or cena_combate:
		await get_tree().process_frame
	cena_combate = true
	congelar_inimigos = true
	Global.dados["etapa"] = 1
	Global.salvar()
	var tut_visivel := painel_tut.visible
	painel_tut.visible = false
	_travar_controle()
	_cam_inicio()

	var P := jogador.global_position
	var B := chefe_pos
	var d := Vector3(B.x - P.x, 0.0, B.z - P.z)
	if d.length() < 0.1:
		d = Vector3(0.0, 0.0, -1.0)
	var dist := d.length()
	d = d.normalized()
	var lado := Vector3(-d.z, 0.0, d.x)
	visual.rotation.y = atan2(d.x, d.z)

	# o chão se abre e o chefe se ergue
	_criar_chefe()
	var fenda := PilarScript.criar_motes(Color(0.7, 0.15, 0.9), 46, 2.4, 0.4)
	fenda.position = B + Vector3(0.0, 0.3, 0.0)
	add_child(fenda)
	fenda.emitting = true
	get_tree().create_timer(4.5).timeout.connect(func(): fenda.emitting = false)
	get_tree().create_timer(10.0).timeout.connect(fenda.queue_free)
	shake = 0.9
	create_tween().tween_property(self, "shake", 0.0, 6.0)

	# plano 1: visto de longe, a câmera avança devagar
	await _cam_para(P + lado * 4.0 - d * 3.0 + Vector3(0.0, 2.5, 0.0), B + Vector3(0.0, 1.5, 0.0), 1.2).finished
	await _cam_para(P + lado * 3.0 + d * (dist * 0.45) + Vector3(0.0, 1.3, 0.0), B + Vector3(0.0, 2.6, 0.0), 3.4).finished
	# plano 2: de baixo para cima, para mostrar o tamanho
	await _cam_para(B - d * 7.0 + lado * 3.5 + Vector3(0.0, 0.5, 0.0), B + Vector3(0.0, 3.4, 0.0), 2.4).finished
	await _esperar(0.7)
	# plano 3: o protagonista, de frente, vendo aquilo
	humano.ofegante = 0.5
	cine_pos = P + d * 2.0 + lado * 0.8 + Vector3(0.0, 1.45, 0.0)
	cine_look = P + Vector3(0.0, 1.5, 0.0)
	await _esperar(1.5)

	var yaw := atan2(-d.x, -d.z)
	await _cam_voltar_jogo(yaw, 1.8)
	_devolver_controle(yaw)
	painel_tut.visible = tut_visivel
	congelar_inimigos = false
	cena_combate = false

func _passo_no(v: float, no: Node3D, de: Vector3, para: Vector3) -> void:
	var x := lerpf(de.x, para.x, v)
	var z := lerpf(de.z, para.z, v)
	no.global_position = Vector3(x, _chao_y(x, z, no.global_position.y), z)

# câmera baixa seguindo os pés da aliada correndo (ela vem na direção da câmera)
func _passo_pes(v: float, no: Node3D, de: Vector3, para: Vector3, d: Vector3, lado: Vector3) -> void:
	_passo_no(v, no, de, para)
	var p := no.global_position
	cine_pos = p + lado * 1.6 + d * lerpf(3.0, -0.8, v) + Vector3(0.0, 0.3, 0.0)
	cine_look = p + Vector3(0.0, 0.15, 0.0)

# salto em arco por cima do protagonista; a câmera de lado acompanha
func _passo_salto(v: float, no: Node3D, de: Vector3, para: Vector3, centro: Vector3, lado: Vector3) -> void:
	var x := lerpf(de.x, para.x, v)
	var z := lerpf(de.z, para.z, v)
	var y := lerpf(de.y, para.y, v) + 4.0 * v * (1.0 - v) * 2.9
	no.global_position = Vector3(x, y, z)
	var foco := centro + Vector3(0.0, 1.4, 0.0)
	cine_look = foco.lerp(no.global_position + Vector3(0.0, 0.8, 0.0), 0.55)
	cine_pos = centro + lado * (5.2 - 0.8 * v) + Vector3(0.0, 1.2 + 0.2 * v, 0.0)

func _dias_chao(p: Vector3, ref: float) -> Vector3:
	p.y = _chao_y(p.x, p.z, ref)
	return p

# a vida caiu para ~40%: a aliada salta por cima do protagonista e o suporte chega
func _cena_aliada() -> void:
	cena_combate = true
	congelar_inimigos = true
	var tut_visivel := painel_tut.visible
	painel_tut.visible = false
	if chefe != null and is_instance_valid(chefe):
		chefe.acalmar()
	_travar_controle()
	_cam_inicio()

	var P := jogador.global_position
	var B := P + Vector3(0.0, 0.0, -3.0)
	if chefe != null and is_instance_valid(chefe):
		B = chefe.global_position
	var d := Vector3(B.x - P.x, 0.0, B.z - P.z)
	var dist := d.length()
	if dist < 0.1:
		d = Vector3(0.0, 0.0, -1.0)
		dist = 3.0
	d = d.normalized()
	var lado := Vector3(-d.z, 0.0, d.x)
	visual.rotation.y = atan2(d.x, d.z)
	humano.modo_loco = false
	humano.ofegante = 1.0
	humano.pose("agachado", 0.6)

	# plano 1: o protagonista enfraquecido
	await _cam_para(P + d * 1.9 + lado * 0.6 + Vector3(0.0, 1.0, 0.0), P + Vector3(0.0, 0.7, 0.0), 2.2).finished
	await _esperar(1.6)

	# plano 2 (corte): os pés da aliada correndo, câmera rente ao chão
	var ali := HumanoScript.new()
	ali.tipo = "laranja"
	add_child(ali)
	var J := _dias_chao(P - d * 3.0, P.y)
	var A0 := _dias_chao(J - d * 17.0, P.y)
	ali.global_position = A0
	ali.rotation.y = atan2(d.x, d.z)
	ali.modo_loco = true
	ali.vel_h = 9.0
	ali.correndo = true
	_passo_pes(0.0, ali, A0, J, d, lado)
	var corre := create_tween()
	corre.tween_method(_passo_pes.bind(ali, A0, J, d, lado), 0.0, 1.0, A0.distance_to(J) / 11.0)
	await corre.finished

	# plano 3 (corte): salto em câmera lenta por cima do protagonista
	var L := _dias_chao(P + d * minf(2.2, maxf(dist * 0.6, 1.4)) + lado * 0.5, P.y)
	ali.vel_h = 0.0
	ali.correndo = false
	ali.no_ar = true
	var salto := create_tween()
	salto.tween_method(_passo_salto.bind(ali, J, L, P, lado), 0.0, 1.0, 1.8)
	await salto.finished

	# pouso entre o protagonista e o chefe; a onda do impacto empurra o chefe para trás
	ali.global_position = L
	ali.no_ar = false
	ali.modo_loco = false
	ali.pose("agachado", 0.0)
	_puff(L, Color(1.0, 0.6, 0.2))
	shake = 0.7
	create_tween().tween_property(self, "shake", 0.0, 0.6)
	cine_pos = L - d * 3.0 + lado * 2.4 + Vector3(0.0, 0.6, 0.0)
	cine_look = L + d * 1.0 + Vector3(0.0, 1.1, 0.0)
	if chefe != null and is_instance_valid(chefe):
		var recuo := create_tween()
		recuo.tween_method(_passo_no.bind(chefe, B, P + d * maxf(dist + 3.5, 8.0)), 0.0, 1.0, 0.5)
	await _esperar(0.7)
	ali.pose("em_pe", 0.5)
	await _esperar(0.5)

	# plano 4: ela, de perfil, e a fala
	await _cam_para(L + lado * 3.0 + Vector3(0.0, 1.45, 0.0), L + Vector3(0.0, 1.35, 0.0), 0.9).finished
	await _fala("Relaxa, cheguei pra salvar o dia.", NOME_ALIADA)

	# plano 5 (corte): de frente para o grupo; o suporte chega correndo
	var A := _dias_chao(P + d * 2.7 + lado * 1.5, P.y)       # aliada: na frente, no canto, perto da câmera
	var Sp := _dias_chao(P + d * 1.4 - lado * 1.6, P.y)      # suporte: do lado oposto, mais atrás
	var S0 := _dias_chao(P - d * 12.0 - lado * 2.0, P.y)
	var sup := HumanoScript.new()
	sup.tipo = "suporte"
	add_child(sup)
	sup.global_position = S0
	sup.rotation.y = atan2(d.x, d.z)
	sup.modo_loco = true
	sup.vel_h = 7.0
	sup.correndo = true
	camera.fov = 55.0
	cine_pos = P + d * 5.0 + Vector3(0.0, 1.3, 0.0)
	cine_look = P + d * 0.9 + Vector3(0.0, 1.1, 0.0)
	ali.modo_loco = true
	ali.vel_h = 2.0
	var passo_ali := create_tween()
	passo_ali.tween_method(_passo_no.bind(ali, L, A), 0.0, 1.0, 0.7)
	var chega := create_tween()
	chega.tween_method(_passo_no.bind(sup, S0, Sp), 0.0, 1.0, S0.distance_to(Sp) / 8.0)
	await chega.finished
	sup.vel_h = 0.0
	sup.correndo = false
	ali.vel_h = 0.0
	ali.rotation.y = atan2(d.x, d.z)
	sup.rotation.y = atan2(d.x, d.z)
	await _esperar(0.3)
	await _fala("Estamos aqui, está tudo bem.", NOME_SUPORTE)
	await _esperar(0.6)

	# volta à batalha: corte rápido, a aliada assume e os outros saem de campo (nasce o time)
	await _fade(Color.BLACK, 0.0, 1.0, 0.25).finished
	membros[idx_ativo]["vida"] = vida
	var velho = humano
	velho.pose("em_pe", 0.0)
	velho.ofegante = 0.0
	velho.visible = false
	jogador.global_position = A + Vector3(0.0, 0.05, 0.0)
	jogador.velocity = Vector3.ZERO
	visual.rotation.y = atan2(d.x, d.z)
	ali.reparent(visual, false)
	ali.position = Vector3.ZERO
	ali.rotation = Vector3.ZERO
	sup.reparent(visual, false)
	sup.position = Vector3.ZERO
	sup.rotation = Vector3.ZERO
	sup.visible = false
	_registrar_membro(NOME_ALIADA, "laranja", ali, DANO_ALIADA_MIN, DANO_ALIADA_MAX)
	_registrar_membro(NOME_SUPORTE, "suporte", sup, DANO_SUPORTE_MIN, DANO_SUPORTE_MAX)
	idx_ativo = 1
	humano = ali
	ali.modo_loco = true
	vida = VIDA_JOGADOR
	_atualizar_vida()
	controles.queue_redraw()

	var yaw := atan2(-d.x, -d.z)
	var pivot := jogador.global_position + Vector3(0.0, 1.55, 0.0)
	cine_pos = pivot + Vector3(sin(yaw) * cos(PITCH_INICIAL), -sin(PITCH_INICIAL), cos(yaw) * cos(PITCH_INICIAL)) * DIST_CAMERA
	cine_look = pivot + Vector3(0.0, 0.15, 0.0)
	camera.fov = 65.0
	_devolver_controle(yaw)
	_fade(Color.BLACK, 1.0, 0.0, 0.4)
	if chefe != null and is_instance_valid(chefe):
		chefe.recarga_ate = chefe.tempo + 1.5
	Global.dados["etapa"] = 2
	Global.salvar()
	painel_tut.visible = tut_visivel
	congelar_inimigos = false
	cena_combate = false
	_mostrar_dica("Toque em Trocar para mudar de personagem" if modo_toque else "Troque de personagem:  1 / 2 / 3")

# ---------------------------------------------------------------- cena: adagas na cara

func _apos_chefe() -> void:
	if bool(Global.dados.get("cutscene_adagas_vista", false)) or membros.size() < 3:
		return
	await _esperar(2.5)                      # deixa o chefe terminar de cair
	_cena_adagas()

func _criar_figurante(t: String, pos: Vector3, yaw: float):
	var h := HumanoScript.new()
	h.tipo = t
	add_child(h)
	h.global_position = pos
	h.rotation.y = yaw
	return h

func _passo_virar(v: float, no: Node3D, de: float, para: float) -> void:
	no.rotation.y = lerp_angle(de, para, v)

func _virar(no: Node3D, ang: float, dur: float) -> Tween:
	var t := create_tween()
	t.tween_method(_passo_virar.bind(no, no.rotation.y, ang), 0.0, 1.0, dur)
	return t

# vira só a cabeça (yaw: graus; pitch positivo = olha para baixo)
func _cabeca(h, yaw: float, dur := 0.4, pitch := 0.0) -> Tween:
	var t := create_tween().set_parallel(true)
	t.tween_property(h, "olhar_yaw", yaw, dur).set_trans(Tween.TRANS_SINE)
	t.tween_property(h, "olhar_pitch", pitch, dur).set_trans(Tween.TRANS_SINE)
	return t

# câmera de frente (um pouco de lado) para o rosto de quem está olhando na direção -d
func _cam_rosto(alvo: Vector3, d: Vector3, lado: Vector3, desloc: float, dur: float) -> Tween:
	return _cam_para(alvo - d * 2.2 + lado * desloc + Vector3(0.0, 1.45, 0.0), alvo + Vector3(0.0, 1.4, 0.0), dur)

func _cena_adagas() -> void:
	while not alvo_valido() or cena_combate:
		await get_tree().process_frame
	cena_combate = true
	congelar_inimigos = true
	var tut_visivel := painel_tut.visible
	painel_tut.visible = false
	_travar_controle()
	_cam_inicio()

	var ele := "ela" if tipo == "feminino" else "ele"
	var dele := "dela" if tipo == "feminino" else "dele"

	var P := jogador.global_position
	var B := chefe_pos
	if chefe != null and is_instance_valid(chefe):
		B = chefe.global_position
	var d := Vector3(B.x - P.x, 0.0, B.z - P.z)
	if d.length() < 0.1:
		d = Vector3(0.0, 0.0, -1.0)
	d = d.normalized()
	var lado := Vector3(-d.z, 0.0, d.x)
	var ang_d := atan2(d.x, d.z)

	# os três aparecem como figurantes (o time normal fica escondido)
	for mb in membros:
		mb["humano"].visible = false
	var pro = _criar_figurante(tipo, P, ang_d)
	var ali = _criar_figurante("laranja", _dias_chao(P + d * 2.4 + lado * 1.2, P.y), ang_d)
	var S0 := _dias_chao(P + d * 0.9 - lado * 1.9, P.y)
	var sup = _criar_figurante("suporte", S0, ang_d)
	pro.ofegante = 1.0
	pro.pose("curvado", 0.0)
	ali.ofegante = 0.5
	sup.ofegante = 0.5
	_puff(ali.global_position, _cor_membro("laranja"))
	_puff(sup.global_position, _cor_membro("suporte"))

	# plano 1: por trás do protagonista, o chefe caído ao fundo; ele respira aliviado
	cine_pos = P - d * 3.6 + lado * 1.9 + Vector3(0.0, 1.5, 0.0)
	cine_look = P + d * 2.0 + Vector3(0.0, 1.0, 0.0)
	_cam_para(P - d * 2.8 + lado * 1.5 + Vector3(0.0, 1.4, 0.0), P + d * 1.4 + Vector3(0.0, 1.0, 0.0), 4.0)
	await _esperar(1.8)
	pro.pose("em_pe", 1.8)
	create_tween().tween_property(pro, "ofegante", 0.15, 3.0)
	ali.ofegante = 0.0
	sup.ofegante = 0.0
	await _esperar(2.4)

	# plano 2 (corte): de lado, os dois no quadro. Ela se vira, saca as adagas e avança
	var A := _dias_chao(P + d * 1.3 + lado * 0.2, P.y)
	cine_pos = P + d * 1.2 + lado * 4.4 + Vector3(0.0, 1.4, 0.0)
	cine_look = P + d * 1.3 + Vector3(0.0, 1.2, 0.0)
	await _virar(ali, ang_d + PI, 0.3).finished
	await _esperar(0.15)
	ali.empunhar(true)
	ali.pose("adagas", 0.18, true)
	var L0: Vector3 = ali.global_position
	ali.loco_bracos = false                  # corre sem balançar os braços (mantém a mira)
	ali.modo_loco = true
	ali.vel_h = 7.0
	ali.correndo = true
	var avanca := create_tween()
	avanca.tween_method(_passo_no.bind(ali, L0, A), 0.0, 1.0, 0.3)
	await avanca.finished
	ali.vel_h = 0.0
	ali.correndo = false
	ali.modo_loco = false
	# susto: o protagonista congela com as mãos na frente
	pro.pose("paz", 0.2, true)
	pro.ofegante = 0.9
	pro.tremor = 1.0
	shake = 0.6
	create_tween().tween_property(self, "shake", 0.0, 0.7)
	_cam_para(P + d * 0.9 + lado * 3.6 + Vector3(0.0, 1.4, 0.0), P + d * 0.7 + Vector3(0.0, 1.25, 0.0), 1.6)
	await _esperar(0.6)
	await _fala("Parado aí! Fala agora, quem é você?!", NOME_ALIADA, true)

	# plano 3: ele treme e recua alguns passos, mãos em sinal de paz
	var P2 := _dias_chao(P - d * 1.6, P.y)
	_cam_para(P - d * 0.3 + lado * 4.6 + Vector3(0.0, 1.4, 0.0), P + d * 0.1 + Vector3(0.0, 1.2, 0.0), 1.4)
	pro.loco_bracos = false
	pro.modo_loco = true
	pro.vel_h = 1.6
	var recua := create_tween()
	recua.tween_method(_passo_no.bind(pro, P, P2), 0.0, 1.0, 1.3)
	await recua.finished
	pro.vel_h = 0.0
	pro.modo_loco = false
	await _esperar(0.4)

	# plano 4: o suporte chega e toca o braço dela
	var S1 := _dias_chao(A - lado * 0.72, P.y)
	var dir_s := Vector3(S1.x - S0.x, 0.0, S1.z - S0.z).normalized()
	cine_pos = P2 - d * 0.3 + lado * 2.8 + Vector3(0.0, 1.5, 0.0)
	cine_look = A + Vector3(0.0, 1.2, 0.0)
	await _virar(sup, atan2(dir_s.x, dir_s.z), 0.2).finished
	sup.modo_loco = true
	sup.vel_h = 2.8
	var vai := create_tween()
	vai.tween_method(_passo_no.bind(sup, S0, S1), 0.0, 1.0, S0.distance_to(S1) / 2.8)
	await vai.finished
	sup.vel_h = 0.0
	sup.modo_loco = false
	await _virar(sup, atan2(lado.x, lado.z), 0.25).finished
	sup.pose("tocar", 0.4)
	await _esperar(0.5)
	await _fala("Minha amiga, pare, está assustando %s." % ele, NOME_SUPORTE)

	# plano 5: ela se vira, indignada, e grita
	cine_pos = A + d * 3.2 + Vector3(0.0, 1.4, 0.0)
	cine_look = A - lado * 0.3 + Vector3(0.0, 1.3, 0.0)
	sup.pose("em_pe", 0.4)
	await _virar(ali, atan2(-lado.x, -lado.z), 0.25).finished
	ali.pose("furioso", 0.2, true)
	await _esperar(0.35)
	shake = 0.5
	create_tween().tween_property(self, "shake", 0.0, 0.5)
	await _fala("NÃO SEJA GENTIL COM O INIMIGO!", NOME_ALIADA, true)

	# plano 6: o suporte ri de leve e explica
	cine_pos = A + d * 2.6 + lado * 0.6 + Vector3(0.0, 1.3, 0.0)
	cine_look = S1 + lado * 0.3 + Vector3(0.0, 1.35, 0.0)
	sup.pose("risada", 0.3)
	sup.ofegante = 0.7
	create_tween().tween_property(sup, "ofegante", 0.0, 1.4)
	await _esperar(0.7)
	await _fala("Ele não é um inimigo, estávamos lutando ao lado %s agora, bobinha." % dele, NOME_SUPORTE)
	sup.pose("em_pe", 0.5)

	# plano 7: os dois olham para o protagonista, que não sabe o que fazer
	var dir_p := Vector3(P2.x - S1.x, 0.0, P2.z - S1.z).normalized()
	_virar(ali, ang_d + PI, 0.5)
	_virar(sup, atan2(dir_p.x, dir_p.z), 0.5)
	ali.pose("em_pe", 0.5)
	cine_pos = P + d * 0.2 + lado * 1.8 + Vector3(0.0, 1.45, 0.0)
	cine_look = P2 + Vector3(0.0, 1.35, 0.0)
	_cam_para(P2 + d * 1.2 + lado * 1.0 + Vector3(0.0, 1.5, 0.0), P2 + Vector3(0.0, 1.4, 0.0), 3.2)
	create_tween().tween_property(pro, "tremor", 0.25, 1.5)
	pro.pose("duvida", 0.6)
	var olha := create_tween()
	olha.tween_interval(0.5)
	olha.tween_property(pro, "olhar_yaw", -35.0, 0.6).set_trans(Tween.TRANS_SINE)
	olha.tween_property(pro, "olhar_yaw", 35.0, 1.0).set_trans(Tween.TRANS_SINE)
	olha.tween_property(pro, "olhar_yaw", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	await olha.finished
	await _esperar(1.0)

	# =========== continuação: Lys, Kael e as apresentações ===========
	var lo := "la" if tipo == "feminino" else "lo"

	# plano 8: Lys fica sem resposta (adagas ainda apontadas); olha Kael, o protagonista e Kael de novo
	ali.pose("adagas", 0.4)
	_cam_para(P2 - d * 0.5 + lado * 0.9 + Vector3(0.0, 1.5, 0.0), (A + S1) * 0.5 + Vector3(0.0, 1.3, 0.0), 1.4)
	await _esperar(1.2)
	await _cabeca(ali, -40.0).finished           # olha para Kael (que está à direita dela)
	await _esperar(0.5)
	await _cabeca(ali, 0.0).finished             # olha para o protagonista
	await _esperar(0.5)
	await _cabeca(ali, -40.0).finished           # e de novo para Kael
	await _esperar(0.3)
	await _fala("...Isso não prova nada!", NOME_ALIADA)

	# plano 9: a troca de provocações
	_cam_rosto(S1, d, lado, 0.5, 0.9)
	await _cabeca(sup, 40.0).finished            # Kael olha para Lys
	await _fala("Não?", NOME_SUPORTE)
	_cam_rosto(A, d, lado, 1.0, 0.9)
	await _fala("E se %s estiver esperando a gente baixar a guarda?!" % ele, NOME_ALIADA)
	_cam_rosto(S1, d, lado, 0.5, 0.9)
	await _fala("Naturalmente. Afinal, derrotar aqueles monstros ao nosso lado deve fazer parte de um plano extremamente elaborado.", NOME_SUPORTE)
	await _cabeca(sup, 40.0, 0.25, 8.0).finished     # sorri discretamente: leve aceno de cabeça
	await _cabeca(sup, 40.0, 0.35, 0.0).finished
	await _esperar(0.3)
	_cam_rosto(A, d, lado, 1.0, 0.7)
	await _esperar(0.5)                              # Lys percebe a provocação
	ali.pose("furioso", 0.2, true)
	await _fala("Você está debochando de mim?!", NOME_ALIADA)
	ali.pose("adagas", 0.3)
	_cam_rosto(S1, d, lado, 0.5, 0.7)
	await _fala("Jamais ousaria.", NOME_SUPORTE)

	# Kael se vira para o protagonista
	await _cabeca(sup, 0.0).finished
	await _fala("Perdoe minha amiga. Ela costuma desconfiar antes de perguntar.", NOME_SUPORTE)
	_cam_rosto(A, d, lado, 1.0, 0.7)
	ali.pose("furioso", 0.15, true)
	shake = 0.5
	create_tween().tween_property(self, "shake", 0.0, 0.5)
	await _fala("EU ESTOU OUVINDO!", NOME_ALIADA, true)
	ali.pose("adagas", 0.3)
	_cam_rosto(S1, d, lado, 0.5, 0.8)
	await _fala("Está tudo bem? Você parece ter passado por bastante coisa.", NOME_SUPORTE)

	# plano 10: Lys percebe as adagas apontadas, abaixa e guarda
	_cam_rosto(A, d, lado, 1.0, 0.8)
	await _cabeca(ali, 0.0, 0.3, 28.0).finished      # olha para as próprias mãos
	await _esperar(0.5)
	ali.pose("em_pe", 0.5)
	await _esperar(0.35)
	ali.empunhar(false)                              # guarda as adagas
	await _cabeca(ali, 0.0, 0.4, 0.0).finished
	await _esperar(0.3)
	await _fala("Enfim! Não pense que isso significa que confio em você!", NOME_ALIADA)
	await _esperar(0.8)
	await _fala("Espera aí! Você apareceu do nada, lutou com aqueles monstros e agora está aqui... Aliás, quem é você?", NOME_ALIADA)

	# plano 11: as apresentações
	_cam_rosto(S1, d, lado, 0.5, 0.8)
	await _cabeca(sup, 40.0).finished
	await _fala("Lys, talvez devêssemos começar nos apresentando primeiro, não acha?", NOME_SUPORTE)
	_cam_rosto(A, d, lado, 1.0, 0.8)
	await _fala("Ah! É... verdade.", NOME_ALIADA)
	var aponta := create_tween()                     # na segunda frase ela olha para o Kael
	aponta.tween_interval(1.1)
	aponta.tween_callback(func(): _cabeca(ali, -35.0, 0.3))
	await _fala("Meu nome é Lys! E aquele ali é o Kael.", NOME_ALIADA)
	_cabeca(ali, 0.0, 0.4)
	await _cabeca(sup, 0.0, 0.3).finished
	_cam_rosto(S1, d, lado, 0.5, 0.8)
	sup.pose("reverencia", 0.6)                      # pequena reverência
	await _esperar(0.6)
	await _fala("É um prazer conhecê-%s." % lo, NOME_SUPORTE)
	sup.pose("em_pe", 0.5)

	# plano 12: os dois olham para o protagonista, esperando
	_cam_para(P2 + d * 1.4 + lado * 0.8 + Vector3(0.0, 1.5, 0.0), P2 + Vector3(0.0, 1.4, 0.0), 1.4)
	await _esperar(1.8)

	# ETAPA 4: escolha do jogador (os dois esperam a resposta)
	_cam_rosto(A, d, lado, 1.0, 0.8)
	await _fala("E você é?", NOME_ALIADA)
	_cam_para(P2 + d * 1.6 + lado * 0.35 + Vector3(0.0, 1.55, 0.0), P2 + Vector3(0.0, 1.5, 0.0), 0.9)
	await _esperar(0.5)
	var resp := await _escolher(["1. Não sei", "2. Eu... Não me lembro"])
	await _fala("Não sei." if resp == 0 else "Eu... Não me lembro.")
	_cam_rosto(A, d, lado, 1.0, 0.8)
	await _fala("Como não sabe?!", NOME_ALIADA)
	_cam_rosto(S1, d, lado, 0.5, 0.8)
	await _fala("Calma, Lys, talvez %s realmente só não se lembre." % ele, NOME_SUPORTE)

	# ETAPA 5: o nome
	await _cabeca(sup, 0.0, 0.3).finished
	await _fala("E seu nome? Você sabe?", NOME_SUPORTE)
	var meu_nome := await _pedir_nome()
	await _fala("Me chamo %s." % meu_nome)
	_cam_rosto(A, d, lado, 1.0, 0.8)
	await _fala("%s, é? Tá bom, %s." % [meu_nome, meu_nome], NOME_ALIADA)
	_cam_rosto(S1, d, lado, 0.5, 0.8)
	sup.pose("reverencia", 0.6)
	await _esperar(0.6)
	await _fala("Seja bem-vind%s, %s." % ["a" if tipo == "feminino" else "o", meu_nome], NOME_SUPORTE)
	sup.pose("em_pe", 0.5)
	await _esperar(0.4)

	# o cansaço da batalha cobra: o protagonista fraqueja
	var ao := "a" if tipo == "feminino" else "o"
	pro.modo_loco = false
	pro.vel_h = 0.0
	pro.loco_bracos = true
	pro.pose("curvado", 1.2)
	pro.ofegante = 1.0
	pro.tremor = 0.4
	_cam_para(P2 + d * 2.3 + lado * 1.0 + Vector3(0.0, 1.3, 0.0), P2 + Vector3(0.0, 1.0, 0.0), 1.4)
	await _esperar(1.6)
	_cam_rosto(S1, d, lado, 0.5, 0.8)
	sup.pose("duvida", 0.3)
	await _fala("Oh, céus! Você está péssim%s. Você precisa de cuidados depois de tudo que passou." % ao, NOME_SUPORTE)
	await _fala("Venha, vamos te levar para a enfermaria da nossa cidade.", NOME_SUPORTE)
	sup.pose("em_pe", 0.4)
	_cam_rosto(A, d, lado, 1.0, 0.8)
	ali.pose("furioso", 0.25, true)
	await _fala("O QUÊ?! Você vai levar um desconhecid%s para a nossa cidade?!" % ao, NOME_ALIADA, true)
	_cam_rosto(S1, d, lado, 0.5, 0.8)
	await _fala("Lys... %s precisa de ajuda." % ele, NOME_SUPORTE)
	_cam_rosto(A, d, lado, 1.0, 0.8)
	ali.pose("em_pe", 0.6)
	await _cabeca(ali, 0.0, 0.5, 25.0).finished       # solta o ar, derrotada
	await _esperar(0.4)
	await _fala("Aff... tá. Mas se %s for encrenca, a culpa é sua." % ele, NOME_ALIADA)
	await _cabeca(ali, 0.0, 0.3, 0.0).finished

	Global.dados["cutscene_adagas_vista"] = true
	Global.salvar()

	# volta ao jogo: o time normal reassume, protagonista ativo
	await _fade(Color.BLACK, 0.0, 1.0, 0.4).finished
	var fim: Vector3 = pro.global_position
	pro.queue_free()
	# Lys e Kael saem do time: viram NPCs temporários
	for i in range(1, membros.size()):
		membros[i]["humano"].queue_free()
	membros.resize(1)
	membros[0]["humano"].visible = true
	membros[0]["vida"] = VIDA_JOGADOR
	idx_ativo = 0
	humano = membros[0]["humano"]
	humano.pose("em_pe", 0.0)
	vida = VIDA_JOGADOR
	_atualizar_vida()
	jogador.global_position = fim + Vector3(0.0, 0.05, 0.0)
	jogador.velocity = Vector3.ZERO
	visual.rotation.y = ang_d
	controles.queue_redraw()
	Global.dados["etapa"] = 4
	Global.salvar()
	ali.global_position = _dias_chao(fim + lado * 1.6 + d * 0.6, fim.y)
	sup.global_position = _dias_chao(fim - lado * 1.6 + d * 0.6, fim.y)

	var yaw := atan2(-d.x, -d.z)
	var pivot := jogador.global_position + Vector3(0.0, 1.55, 0.0)
	cine_pos = pivot + Vector3(sin(yaw) * cos(PITCH_INICIAL), -sin(PITCH_INICIAL), cos(yaw) * cos(PITCH_INICIAL)) * DIST_CAMERA
	cine_look = pivot + Vector3(0.0, 0.15, 0.0)
	camera.fov = 65.0
	_devolver_controle(yaw)
	_fade(Color.BLACK, 1.0, 0.0, 0.5)
	painel_tut.visible = tut_visivel
	congelar_inimigos = false
	cena_combate = false
	_iniciar_escolta(ali, sup, 0)

# ---------------------------------------------------------------- escolta até a cidade

# traça o caminho de pontos que vai da luta até a cidade (norte, para dentro da ilha)
func _tracar_estrada() -> void:
	estrada.clear()
	var alvo3 := _achar_plano(Vector2(chefe_pos.x, chefe_pos.z - 100.0))
	var alvo := Vector2(alvo3.x, alvo3.z)
	var p := Vector2(chefe_pos.x, chefe_pos.z)
	for i in 20:
		if p.distance_to(alvo) < 14.0:
			break
		var q := p + (alvo - p).normalized() * 14.0
		var r := _achar_plano(q)
		var rr := Vector2(r.x, r.z)
		if rr.distance_to(alvo) < p.distance_to(alvo):
			q = rr
		estrada.append(Vector3(q.x, _altura(q.x, q.y), q.y))
		p = q
	estrada.append(alvo3)
	var ult := estrada[estrada.size() - 1]
	var dd := Vector3.ZERO
	if estrada.size() >= 2:
		dd = ult - estrada[estrada.size() - 2]
	dd.y = 0.0
	dd = dd.normalized() if dd.length() > 0.1 else Vector3(0.0, 0.0, -1.0)
	cidade_pos = _achar_plano(Vector2(ult.x + dd.x * 95.0, ult.z + dd.z * 95.0))

func _iniciar_escolta(ali, sup, de: int) -> void:
	escolta = [ali, sup]
	escolta_i = de
	escolta_on = true
	escolta_fala = de > 0
	escolta_espera = false
	for h in escolta:
		h.ofegante = 0.0
		h.tremor = 0.0
		h.loco_bracos = true
		h.modo_loco = true
		h.vel_h = 0.0
		h.pose("em_pe", 0.2)
	_mostrar_dica("Siga a Lys e o Kael")

func _retomar_escolta() -> void:
	var ali = _criar_figurante("laranja", Vector3.ZERO, 0.0)
	var sup = _criar_figurante("suporte", Vector3.ZERO, 0.0)
	var mais_perto := 0
	var dmin := 1.0e9
	for i in estrada.size():
		var dd := Vector2(estrada[i].x - jogador.global_position.x, estrada[i].z - jogador.global_position.z).length()
		if dd < dmin:
			dmin = dd
			mais_perto = i
	var base := estrada[mais_perto]
	ali.global_position = _dias_chao(base + Vector3(1.4, 0.0, 0.0), base.y)
	sup.global_position = _dias_chao(base + Vector3(-1.4, 0.0, 0.0), base.y)
	_iniciar_escolta(ali, sup, mais_perto)

func _tick_escolta(delta: float) -> void:
	if not escolta_on or escolta.is_empty() or estrada.is_empty():
		return
	var lider = escolta[0]
	var dist_j := Vector2(lider.global_position.x - jogador.global_position.x,
			lider.global_position.z - jogador.global_position.z).length()
	if dist_j > 16.0:
		escolta_espera = true
	elif dist_j < 9.0:
		escolta_espera = false
	var alvo: Vector3 = estrada[escolta_i]
	var chegou_ponto := Vector2(alvo.x - lider.global_position.x, alvo.z - lider.global_position.z).length() < 2.0
	if chegou_ponto and not escolta_espera:
		if escolta_i < estrada.size() - 1:
			escolta_i += 1
			alvo = estrada[escolta_i]
		else:
			if conversa_fim:
				_fim_escolta()
				return
	if escolta_i >= 1 and not escolta_fala:
		escolta_fala = true
		_conversa_corrida()
	var dir_est := Vector3(alvo.x - lider.global_position.x, 0.0, alvo.z - lider.global_position.z).normalized()
	var lado_est := Vector3(-dir_est.z, 0.0, dir_est.x)
	if not conversa_fim:                  # conversa rolando: os dois ficam parados, virados para o protagonista
		for h in escolta:
			h.vel_h = 0.0
			h.correndo = false
			var ol := Vector3(jogador.global_position.x - h.global_position.x, 0.0, jogador.global_position.z - h.global_position.z)
			if ol.length() > 1.5:
				h.rotation.y = lerp_angle(h.rotation.y, atan2(ol.x, ol.z), minf(1.0, delta * 6.0))
		return
	for i in escolta.size():
		var h = escolta[i]
		var meta: Vector3 = alvo + lado_est * (1.3 if i == 0 else -1.3)
		var v := Vector3(meta.x - h.global_position.x, 0.0, meta.z - h.global_position.z)
		var olhar := v
		if escolta_espera:
			olhar = Vector3(jogador.global_position.x - h.global_position.x, 0.0, jogador.global_position.z - h.global_position.z)
		if olhar.length() > 0.2:
			h.rotation.y = lerp_angle(h.rotation.y, atan2(olhar.x, olhar.z), minf(1.0, delta * 8.0))
		if escolta_espera or v.length() < 0.4:
			h.vel_h = 0.0
			h.correndo = false
		else:
			var passo := v.normalized() * VEL_ESCOLTA * delta
			h.global_position.x += passo.x
			h.global_position.z += passo.z
			h.vel_h = VEL_ESCOLTA
			h.correndo = true
		h.global_position.y = _chao_y(h.global_position.x, h.global_position.z, h.global_position.y)

func _fim_escolta() -> void:
	escolta_on = false
	for h in escolta:
		h.vel_h = 0.0
		h.correndo = false
	Global.dados["etapa"] = 5
	Global.salvar()
	if not bool(Global.dados.get("cutscene_fecundia_vista", false)):
		_cena_fecundia()

# conversa durante a corrida (não trava o jogador); cada fala dura conforme o tamanho do texto
func _conversa_corrida() -> void:
	await _rodar_falas([
		[NOME_ALIADA, "Vou ficar de olho em você."],
		[NOME_ALIADA, "Ei, Kael. Descobriu alguma coisa sobre aquele tremor de ontem à noite?"],
		[NOME_SUPORTE, "Nada conclusivo. Não encontrei sinais de deslizamento ou qualquer outra coisa que pudesse explicá-lo."],
		[NOME_ALIADA, "Hm... Foi forte demais para ser uma tremidinha qualquer."],
		[NOME_SUPORTE, "Talvez tenha sido um pequeno abalo sísmico."],
		["@heroi", "Do que vocês estão falando?"],
		[NOME_SUPORTE, "Ontem à noite houve um tremor bastante incomum por aqui. Chegou a assustar alguns moradores."],
		[NOME_ALIADA, "E ninguém descobriu o que aconteceu até agora."],
		[NOME_SUPORTE, "Talvez tenha sido apenas um fenômeno natural."],
		[NOME_ALIADA, "Espero que sim. Não precisamos de mais problemas."],
	])

# Roda uma lista de falas [quem, texto] sem travar o jogador; o balão fica na tela e só troca nome/texto.
# "@heroi" = nome do protagonista. ["@olhar", "chave"] = a câmera gira suavemente para esse ponto de `marcos`.
func _rodar_falas(falas: Array, marcos := {}) -> void:
	conversa_fim = false
	var heroi := str(Global.dados.get("nome_heroi", ""))
	for i in falas.size():
		var f = falas[i]
		if str(f[0]) == "@olhar":
			_guiar_para(marcos[str(f[1])], 1.8)
			continue
		var quem := heroi if str(f[0]) == "@heroi" else str(f[0])
		var dur := 1.6 + str(f[1]).length() * 0.045
		await _fala_corrida(str(f[1]), quem, dur, i == falas.size() - 1)   # o balão só some na última
	conversa_fim = true

# fala curta durante a gameplay (não trava o jogador)
func _fala_corrida(texto: String, quem: String, dur := 3.2, esconder := true) -> void:
	nome_label.text = quem
	nome_label.visible = quem != ""
	fala_label.text = texto
	fala_label.add_theme_font_size_override("font_size", 42)
	fala_label.visible_ratio = 1.0
	seta.visible = false
	caixa.visible = true
	await _esperar(dur)
	if esconder and fala_label.text == texto:
		caixa.visible = false

# ---------------------------------------------------------------- apresentação de Fecúndia

func _passo_guia(k: float, y0: float, y1: float, p0: float, p1: float) -> void:
	cam_yaw = lerp_angle(y0, y1, k)
	cam_pitch = lerpf(p0, p1, k)

# gira a câmera do jogo (suave) para olhar um ponto distante
func _guiar_para(ponto: Vector3, dur := 1.8) -> void:
	var pivot := jogador.global_position + Vector3(0.0, 1.55, 0.0)
	var v := ponto - pivot
	var yaw := atan2(-v.x, -v.z)
	var pit := clampf(atan2(v.y, Vector2(v.x, v.z).length()), -0.08, 0.35)
	var t := create_tween()
	t.tween_method(_passo_guia.bind(cam_yaw, yaw, cam_pitch, pit), 0.0, 1.0, dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _ponto_em(P: Vector3, dir: Vector3, graus: float, dist: float, plano := true) -> Vector3:
	var q := P + dir.rotated(Vector3.UP, deg_to_rad(graus)) * dist
	if plano:
		return _achar_plano(Vector2(q.x, q.z))
	return Vector3(q.x, _altura(q.x, q.z), q.z)

# pontos de referência da paisagem (a ilha é gerada por ruído; quando houver cenário de verdade, troque por posições reais)
func _marcos_fecundia(P: Vector3, dir: Vector3) -> Dictionary:
	var m := {}
	var alto1 := -1.0
	var mont := Vector3.ZERO
	for x in range(-150, 151, 10):
		for z in range(-150, 151, 10):
			var h := _altura(x, z)
			if h > alto1 and Vector2(x - P.x, z - P.z).length() > 40.0:
				alto1 = h
				mont = Vector3(x, h, z)
	var alto2 := -1.0
	var colinas := Vector3.ZERO
	for x in range(-150, 151, 10):
		for z in range(-150, 151, 10):
			var h2 := _altura(x, z)
			if h2 > alto2 and Vector2(x - mont.x, z - mont.z).length() > 70.0 and Vector2(x - P.x, z - P.z).length() > 40.0:
				alto2 = h2
				colinas = Vector3(x, h2, z)
	m["montanhas"] = mont
	m["colinas"] = colinas
	m["vindemia"] = cidade_pos
	m["trigo"] = _ponto_em(P, dir, 35.0, 70.0)
	m["vinhedos"] = _ponto_em(P, dir, -35.0, 85.0)
	m["floresta"] = _ponto_em(P, dir, 80.0, 75.0, false)
	m["flores"] = _ponto_em(P, dir, 180.0, 70.0)
	m["ruinas"] = _ponto_em(P, dir, 150.0, 90.0)
	m["praia"] = spawn
	return m

func _cena_fecundia() -> void:
	while not alvo_valido():
		await get_tree().process_frame
	var ali = escolta[0]
	var sup = escolta[1]
	var P := jogador.global_position
	var dir := Vector3.ZERO
	if estrada.size() >= 2:
		dir = estrada[estrada.size() - 1] - estrada[estrada.size() - 2]
	dir.y = 0.0
	if dir.length() < 0.1:
		dir = Vector3(0.0, 0.0, -1.0)
	dir = dir.normalized()
	var lado := Vector3(-dir.z, 0.0, dir.x)
	var ang := atan2(dir.x, dir.z)
	var up := Vector3(0.0, 1.0, 0.0)
	var marcos := _marcos_fecundia(P, dir)
	var tut_visivel := painel_tut.visible
	painel_tut.visible = false
	_travar_controle()
	_cam_inicio()
	visual.rotation.y = ang
	ali.global_position = _dias_chao(P + dir * 0.4 + lado * 1.7, P.y)
	sup.global_position = _dias_chao(P + dir * 0.4 - lado * 1.7, P.y)
	ali.rotation.y = ang
	sup.rotation.y = ang
	for h in escolta:
		h.vel_h = 0.0
		h.correndo = false
		h.pose("em_pe", 0.2)

	# cena 1: a câmera se aproxima do protagonista e desliza para o lado, revelando Fecúndia
	await _cam_para(P - dir * 8.0 + up * 2.4, P + up * 1.4, 0.8).finished
	await _cam_para(P - dir * 3.2 + lado * 0.4 + up * 1.7, P + up * 1.5, 2.4).finished
	_cam_para(P + lado * 4.2 - dir * 0.8 + up * 1.6, P + dir * 40.0 + up * 5.0, 3.4)
	await _esperar(1.2)
	await _fala("Bem-vindo a Fecúndia! É daqui que viemos.", NOME_SUPORTE)
	# a câmera percorre a paisagem
	for chave in ["trigo", "montanhas", "vindemia"]:
		await _cam_para(P + lado * 4.2 - dir * 0.8 + up * 1.6, marcos[chave] + up * 4.0, 1.5).finished
		await _esperar(0.5)
	# e volta aos personagens
	await _cam_para(P + dir * 5.0 + lado * 0.3 + up * 1.6, P + dir * 0.3 + up * 1.2, 1.6).finished
	await _fala("Tá, já apresentou o lugar. Vamos logo!", NOME_ALIADA)
	await _fala("Você poderia demonstrar um pouco mais de entusiasmo, sabia?", NOME_SUPORTE)
	await _fala("Eu demonstraria se não estivéssemos perdendo tempo parados aqui!", NOME_ALIADA)
	await _fala("Naturalmente...", NOME_SUPORTE)

	# o controle volta; os dois ficam parados enquanto as outras falas rolam
	var yaw := atan2(-dir.x, -dir.z)
	await _cam_voltar_jogo(yaw, 1.4)
	_devolver_controle(yaw)
	painel_tut.visible = tut_visivel

	await _rodar_falas([
		# cena 2: as terras
		[NOME_SUPORTE, "Como pode ver, temos bastante espaço verde por aqui. Fecúndia é conhecida principalmente por suas colheitas e pela variedade de recursos que produz."],
		[NOME_ALIADA, "É daqui que sai boa parte dos alimentos que chegam a outras regiões. Pode até parecer uma cidadezinha tranquila, mas temos bastante responsabilidade!"],
		[NOME_SUPORTE, "Essa abundância também é atribuída à bênção de Ceres, nossa deusa. Segundo as histórias, ela protege estas terras há muitas gerações."],
		["@heroi", "Ceres...?"],
		[NOME_SUPORTE, "A divindade que representa a natureza, as colheitas e tudo aquilo que floresce. O povo daqui tem um carinho especial por ela."],
		[NOME_ALIADA, "E com razão! Afinal, olha só para esse lugar!"],
		# cena 3: montanhas e minas
		["@olhar", "montanhas"],
		[NOME_SUPORTE, "Aquelas montanhas abrigam algumas das nossas principais minas. De lá vêm os minerais usados para construir edifícios, fabricar ferramentas e produzir diversos materiais."],
		[NOME_ALIADA, "Embora eu não recomende uma visita se você não gostar de poeira e trabalho pesado."],
		[NOME_SUPORTE, "Não é tão ruim quanto ela faz parecer."],
		[NOME_ALIADA, "Fácil falar quando não é você quem precisa carregar as pedras!"],
		# cena 4: campos de trigo
		["@olhar", "trigo"],
		[NOME_SUPORTE, "E aqueles campos são responsáveis por boa parte do nosso trigo. Os moinhos aproveitam o vento para transformar os grãos em farinha."],
		[NOME_ALIADA, "Que depois vira pão! Não podemos esquecer a parte mais importante."],
		[NOME_SUPORTE, "Naturalmente. Sabia que você diria isso."],
		# cena 5: vinhedos
		["@olhar", "vinhedos"],
		[NOME_SUPORTE, "Mais adiante ficam os vinhedos e outras propriedades agrícolas. Algumas famílias cuidam dessas terras há gerações."],
		[NOME_ALIADA, "Na época da colheita, tudo fica muito movimentado. Temos festivais, música e comida por toda parte!"],
		[NOME_SUPORTE, "Você parece gostar bastante dessa época."],
		[NOME_ALIADA, "E quem não gostaria?"],
		# cena 6: floresta
		["@olhar", "floresta"],
		[NOME_SUPORTE, "Aquela floresta também é importante para nós. Encontramos ervas medicinais, frutos silvestres e materiais utilizados pelos artesãos."],
		[NOME_ALIADA, "Mas tome cuidado se resolver explorá-la. Algumas criaturas não gostam muito de visitantes."],
		[NOME_SUPORTE, "Principalmente quando os visitantes resolvem incomodá-las."],
		[NOME_ALIADA, "Não precisa olhar para mim desse jeito!"],
		# cena 7: flores, ruínas e praia
		["@olhar", "flores"],
		[NOME_SUPORTE, "Ao sul ficam os campos de flores. É uma paisagem bastante bonita, especialmente durante a primavera."],
		["@olhar", "ruinas"],
		[NOME_ALIADA, "E também existem algumas ruínas antigas por lá. Ninguém sabe exatamente quem as construiu."],
		[NOME_SUPORTE, "Existem muitas teorias, mas nenhuma conclusão."],
		[NOME_ALIADA, "Algumas pessoas dizem que ainda escondem tesouros."],
		[NOME_SUPORTE, "E você acredita nisso?"],
		[NOME_ALIADA, "Eu disse que algumas pessoas dizem!"],
		["@olhar", "praia"],
		[NOME_SUPORTE, "Também temos uma praia mais afastada, perto da floresta que acompanha parte da costa. É um lugar tranquilo, longe da movimentação da capital."],
		[NOME_ALIADA, "Definitivamente um dos meus lugares favoritos."],
		# cena 8: colinas rochosas
		["@olhar", "colinas"],
		[NOME_SUPORTE, "Já naquela direção, o terreno fica mais acidentado. Existem outras ruínas espalhadas pelas colinas."],
		[NOME_ALIADA, "Sério, temos ruínas suficientes para manter arqueólogos ocupados por anos."],
		[NOME_SUPORTE, "Considerando a idade de algumas delas, talvez nem isso seja suficiente."],
		# cena 9: Vindemia
		["@olhar", "vindemia"],
		[NOME_SUPORTE, "E aquela é Vindemia, nossa capital. É o lugar mais movimentado de Fecúndia."],
		[NOME_SUPORTE, "Como fica às margens do rio e concentra boa parte do nosso comércio, produtos de todas as regiões passam por aqui antes de seguirem para outros lugares."],
		[NOME_ALIADA, "Além disso, temos lojas, oficinas, festivais... E lugares para descansar!"],
		[NOME_SUPORTE, "Vejo que você está especialmente interessada na última parte."],
		[NOME_ALIADA, "Depois dessa caminhada? Pode apostar!"],
		[NOME_SUPORTE, "Bem, acho que já falamos o suficiente por enquanto. Vamos entrar?"],
	], marcos)
	Global.dados["cutscene_fecundia_vista"] = true
	Global.dados["etapa"] = 6
	Global.salvar()
	_cena_enfermaria()

# ---------------------------------------------------------------- cena: a porta da enfermaria

func _bloco_cena(pai: Node3D, tam: Vector3, pos: Vector3, cor: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = 0.9
	mi.material_override = mat
	mi.position = pos
	pai.add_child(mi)
	return mi

# fachada provisória da enfermaria (troque pelo seu modelo). Frente voltada para -dir; devolve [raiz, pivô da porta]
func _montar_porta(D: Vector3, ang: float) -> Array:
	var raiz := Node3D.new()
	add_child(raiz)
	raiz.global_position = D
	raiz.rotation.y = ang
	var parede := Color(0.85, 0.78, 0.62)
	_bloco_cena(raiz, Vector3(3.0, 3.6, 0.5), Vector3(-2.15, 1.8, 0.0), parede)
	_bloco_cena(raiz, Vector3(3.0, 3.6, 0.5), Vector3(2.15, 1.8, 0.0), parede)
	_bloco_cena(raiz, Vector3(1.3, 1.2, 0.5), Vector3(0.0, 3.0, 0.0), parede)
	_bloco_cena(raiz, Vector3(7.4, 0.3, 1.6), Vector3(0.0, 3.75, -0.5), Color(0.62, 0.28, 0.22))
	_bloco_cena(raiz, Vector3(0.5, 0.14, 0.05), Vector3(0.0, 3.0, -0.27), Color(0.85, 0.15, 0.15))
	_bloco_cena(raiz, Vector3(0.14, 0.5, 0.05), Vector3(0.0, 3.0, -0.27), Color(0.85, 0.15, 0.15))
	_bloco_cena(raiz, Vector3(3.0, 3.0, 0.1), Vector3(0.0, 1.5, 1.0), Color(0.05, 0.04, 0.04))
	var pivo := Node3D.new()
	pivo.position = Vector3(-0.65, 0.0, -0.1)
	raiz.add_child(pivo)
	_bloco_cena(pivo, Vector3(1.3, 2.4, 0.12), Vector3(0.65, 1.2, 0.0), Color(0.45, 0.28, 0.16))
	return [raiz, pivo]

func _cena_enfermaria() -> void:
	while not alvo_valido():
		await get_tree().process_frame
	for h in escolta:
		if is_instance_valid(h):
			h.queue_free()
	escolta.clear()
	escolta_on = false
	var tut_visivel := painel_tut.visible
	painel_tut.visible = false
	_travar_controle()
	await _fade(Color.BLACK, 0.0, 1.0, 0.8).finished

	var D := cidade_pos
	var dir := Vector3.ZERO
	if estrada.size() >= 2:
		dir = estrada[estrada.size() - 1] - estrada[estrada.size() - 2]
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.1 else Vector3(0.0, 0.0, -1.0)
	var lado := Vector3(-dir.z, 0.0, dir.x)
	var ang := atan2(dir.x, dir.z)
	var up := Vector3(0.0, 1.0, 0.0)
	var heroi := str(Global.dados.get("nome_heroi", ""))

	var porta := _montar_porta(D, ang)
	var pivo: Node3D = porta[1]
	humano.visible = false
	var sup = _criar_figurante("suporte", _dias_chao(D - dir * 17.0 - lado * 1.4, D.y), ang)
	var ali = _criar_figurante("laranja", _dias_chao(D - dir * 17.0 + lado * 1.4, D.y), ang)
	var pro = _criar_figurante(tipo, _dias_chao(D - dir * 19.5, D.y), ang)
	var dolly = _criar_figurante("dolly", _dias_chao(D + dir * 0.5, D.y), ang + PI)
	dolly.scale = Vector3.ONE * 0.92
	dolly.visible = false
	var todos := [sup, ali, pro]

	# chegada: os dois guiam o protagonista até a porta
	_cam_inicio()
	cine_pos = D - dir * 27.0 + lado * 6.0 + up * 2.6
	cine_look = D - dir * 17.0 + up * 1.2
	_cam_para(D - dir * 9.0 + lado * 5.5 + up * 1.9, D - dir * 2.0 + up * 1.4, 5.6)
	_fade(Color.BLACK, 1.0, 0.0, 0.8)
	var fim_sup := _dias_chao(D - dir * 1.2 - lado * 0.9, D.y)
	var fim_ali := _dias_chao(D - dir * 1.9 + lado * 1.5, D.y)
	var fim_pro := _dias_chao(D - dir * 3.0, D.y)
	var fins := [fim_sup, fim_ali, fim_pro]
	var ult_tw: Tween = null
	for i in todos.size():
		var h = todos[i]
		h.modo_loco = true
		h.loco_bracos = true
		h.vel_h = 3.2
		var tw := create_tween()
		tw.tween_method(_passo_no.bind(h, h.global_position, fins[i]), 0.0, 1.0, 5.6)
		ult_tw = tw
	await ult_tw.finished
	for h in todos:
		h.vel_h = 0.0
	await _esperar(0.4)

	# Kael bate na porta
	_cam_para(D - dir * 5.0 + lado * 2.8 + up * 1.6, D - dir * 0.4 + up * 1.4, 1.2)
	await _esperar(0.9)
	sup.pose("tocar", 0.3)
	await _esperar(0.3)
	for i in 3:
		var tb := create_tween()
		tb.tween_property(pivo, "rotation_degrees:y", -2.0, 0.07)
		tb.tween_property(pivo, "rotation_degrees:y", 0.0, 0.07)
		await tb.finished
		await _esperar(0.12)
	sup.pose("em_pe", 0.4)
	await _esperar(0.9)

	# Dolly abre a porta
	dolly.visible = true
	dolly.pose("em_pe", 0.0)
	var abre := create_tween()
	abre.tween_property(pivo, "rotation_degrees:y", -100.0, 0.9).set_trans(Tween.TRANS_SINE)
	await abre.finished
	_cam_para(D - dir * 3.4 - lado * 1.4 + up * 1.5, D + dir * 0.2 - lado * 0.3 + up * 1.2, 0.8)
	await _esperar(0.7)
	await _fala("Dolly, cadê a sua mãe? Preciso falar com a Jolene, a enfermeira da cidade.", NOME_SUPORTE)
	await _virar(dolly, ang, 0.3).finished             # ela se vira para dentro de casa
	await _fala("MÃÃÃE!", NOME_DOLLY, true)
	await _virar(dolly, ang + PI, 0.3).finished
	await _fala("Ela já vem! Mas o que houve?", NOME_DOLLY)
	_cam_para(D - dir * 5.2 + lado * 2.2 + up * 1.7, D - dir * 1.6 + up * 1.2, 0.9)
	await _fala("Dolly, este é %s, um viajante que encontramos no caminho. Precisa de cuidados." % (heroi if heroi != "" else "o viajante"), NOME_SUPORTE)
	ali.pose("furioso", 0.25, true)
	await _fala("Um imprudente, isso sim! Se meteu em uma briga e olha só o estado em que ficou!", NOME_ALIADA)
	ali.pose("em_pe", 0.4)

	# Dolly fica pasma, depois determinada
	_cam_para(D - dir * 2.4 - lado * 0.8 + up * 1.5, D + dir * 0.2 + up * 1.3, 0.8)
	dolly.pose("paz", 0.2, true)
	dolly.tremor = 0.5
	await _esperar(1.5)
	dolly.tremor = 0.0
	dolly.pose("alcancar", 0.2, true)
	await _fala("Deixa comigo! Vem cá!", NOME_DOLLY, true)

	# ela agarra o braço do protagonista e o arrasta para dentro
	_cam_para(D - dir * 7.0 + lado * 3.0 + up * 1.8, D - dir * 1.4 + up * 1.3, 1.2)
	var d0: Vector3 = dolly.global_position
	var alvo_d := _dias_chao(fim_pro + dir * 0.9, D.y)
	dolly.modo_loco = true
	dolly.loco_bracos = false
	dolly.vel_h = 5.0
	dolly.correndo = true
	var vai := create_tween()
	vai.tween_method(_passo_no.bind(dolly, d0, alvo_d), 0.0, 1.0, 0.8)
	await vai.finished
	await _virar(dolly, ang, 0.2).finished
	pro.pose("duvida", 0.2)
	var p0: Vector3 = pro.global_position
	var porta_pos := _dias_chao(D + dir * 0.4, D.y)
	pro.modo_loco = true
	pro.loco_bracos = false
	pro.vel_h = 5.0
	pro.correndo = true
	var arrasta := create_tween().set_parallel(true)
	arrasta.tween_method(_passo_no.bind(dolly, alvo_d, porta_pos + dir * 0.3), 0.0, 1.0, 1.3)
	arrasta.tween_method(_passo_no.bind(pro, p0, porta_pos - dir * 0.9), 0.0, 1.0, 1.3)
	await arrasta.finished
	dolly.visible = false
	pro.visible = false

	# Kael ri e entra; Lys suspira e entra junto
	_cam_para(D - dir * 5.0 + lado * 1.8 + up * 1.7, D - dir * 0.8 + up * 1.4, 0.8)
	sup.pose("risada", 0.4)
	await _esperar(1.1)
	sup.pose("em_pe", 0.3)
	var s0: Vector3 = sup.global_position
	sup.vel_h = 3.2
	var entra := create_tween()
	entra.tween_method(_passo_no.bind(sup, s0, porta_pos), 0.0, 1.0, 1.4)
	await entra.finished
	sup.visible = false
	await _fala("*suspira*", NOME_ALIADA)
	await _cabeca(ali, 0.0, 0.4, 20.0).finished
	await _cabeca(ali, 0.0, 0.3, 0.0).finished
	var a0: Vector3 = ali.global_position
	ali.vel_h = 3.2
	var entra2 := create_tween()
	entra2.tween_method(_passo_no.bind(ali, a0, porta_pos), 0.0, 1.0, 1.6)
	await entra2.finished
	ali.visible = false

	# tela de carregamento
	await _fade(Color.BLACK, 0.0, 1.0, 0.8).finished
	Global.dados["cutscene_enfermaria_vista"] = true
	Global.dados["etapa"] = 7
	Global.salvar()
	for h in todos:
		h.queue_free()
	dolly.queue_free()
	if ResourceLoader.exists(CENA_ENFERMARIA):
		Global.ir_para(CENA_ENFERMARIA)
		return
	# a cena da enfermaria ainda não existe: devolve o controle diante da porta
	humano.visible = true
	jogador.global_position = _dias_chao(D - dir * 6.0, D.y) + Vector3(0.0, 0.05, 0.0)
	visual.rotation.y = ang
	var yaw := atan2(-dir.x, -dir.z)
	var pivot := jogador.global_position + Vector3(0.0, 1.55, 0.0)
	cine_pos = pivot + Vector3(sin(yaw) * cos(PITCH_INICIAL), -sin(PITCH_INICIAL), cos(yaw) * cos(PITCH_INICIAL)) * DIST_CAMERA
	cine_look = pivot + Vector3(0.0, 0.15, 0.0)
	camera.fov = 65.0
	_devolver_controle(yaw)
	_fade(Color.BLACK, 1.0, 0.0, 0.6)
	painel_tut.visible = tut_visivel
	_mostrar_dica("(a cena da enfermaria ainda não existe: crie %s)" % CENA_ENFERMARIA)

# ---------------------------------------------------------------- cena do despertar

func _intro() -> void:
	modo = Modo.CINE
	var P := jogador.global_position
	humano.pose("deitado", 0.0)
	visual.rotation_degrees.y = 0.0
	camera.fov = 55.0
	cine_pos = P + Vector3(1.0, 0.55, -2.8)
	cine_look = P + Vector3(0.0, 0.3, -0.4)
	var lento := create_tween()
	lento.tween_property(self, "cine_pos", P + Vector3(0.7, 0.45, -1.9), 6.0).set_trans(Tween.TRANS_SINE)
	_fade(Color.BLACK, 1.0, 0.0, 2.5)
	await _esperar(5.5)

	# ---- acorda de sobressalto, como após um pesadelo ----
	lento.kill()
	shake = 1.0
	humano.ofegante = 1.0
	humano.pose("sentado", 0.3, true)
	camera.fov = 40.0
	cine_pos = P + Vector3(0.9, 1.05, 1.4)
	cine_look = P + Vector3(0.0, 0.95, -0.05)
	await _esperar(0.4)
	create_tween().tween_property(self, "shake", 0.12, 1.8)
	await _esperar(2.0)

	# olha em volta, ofegante
	var t1 := create_tween()
	t1.tween_property(humano, "olhar_yaw", -55.0, 0.7)
	t1.tween_property(humano, "olhar_yaw", 55.0, 1.3)
	t1.tween_property(humano, "olhar_yaw", 0.0, 0.7)
	await t1.finished
	await _esperar(0.8)

	# ---- levanta ----
	var recua := create_tween().set_parallel(true)
	recua.tween_property(self, "cine_pos", P + Vector3(1.9, 1.5, 2.6), 3.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	recua.tween_property(self, "cine_look", P + Vector3(0.0, 0.9, 0.0), 3.4)
	recua.tween_property(camera, "fov", 55.0, 3.4)
	recua.tween_property(humano, "ofegante", 0.4, 4.0)
	await humano.pose("agachado", 1.2).finished
	await humano.pose("em_pe", 1.5).finished
	await _esperar(0.4)

	# ---- vira para a ilha e olha ao redor ----
	var giro := create_tween()
	giro.tween_property(visual, "rotation_degrees:y", 180.0, 2.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var cab := create_tween()
	cab.tween_property(humano, "olhar_yaw", 40.0, 1.0)
	cab.tween_property(humano, "olhar_yaw", -30.0, 1.2)
	cab.tween_property(humano, "olhar_yaw", 0.0, 0.8)
	var ini := _pos_orbita(0.0)
	var vai := create_tween().set_parallel(true)
	vai.tween_property(self, "cine_pos", ini[0], 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	vai.tween_property(self, "cine_look", ini[1], 2.6)
	vai.tween_property(camera, "fov", 52.0, 2.6)
	await vai.finished
	await _esperar(0.2)

	# ---- a câmera gira em volta dele mostrando o mundo ----
	var orb := create_tween()
	orb.tween_method(_passo_orbita, 0.0, 1.0, 11.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await orb.finished
	await _esperar(0.5)

	await _fala("Onde estou... Que lugar é esse?")
	Global.dados["cutscene5_vista"] = true
	Global.salvar()
	_comecar_jogo()

# posição da câmera na órbita (v = 0 e v = 1 coincidem com a câmera do jogo)
func _pos_orbita(v: float) -> Array:
	var c := jogador.global_position
	var f := sin(v * PI)
	var r := DIST_CAMERA * cos(PITCH_INICIAL) + 6.0 * f
	var altura := 1.55 - sin(PITCH_INICIAL) * DIST_CAMERA + 3.2 * f
	var ang := v * TAU
	var pos := c + Vector3(sin(ang) * r, altura, cos(ang) * r)
	var chao := maxf(_altura(pos.x, pos.z), 0.0) + 1.1
	pos.y = maxf(pos.y, chao)
	var alvo := c + Vector3(0.0, lerpf(1.7, 1.25, f), 0.0)
	return [pos, alvo]

func _passo_orbita(v: float) -> void:
	var r := _pos_orbita(v)
	cine_pos = r[0]
	cine_look = r[1]
	camera.fov = lerpf(52.0, 65.0, v)

# ---------------------------------------------------------------- escolhas e nome

func _montar_escolha_e_nome(ui: CanvasLayer) -> void:
	# menu de escolha (botões grandes, acima da caixa de diálogo)
	painel_escolha = Control.new()
	painel_escolha.visible = false
	ui.add_child(painel_escolha)
	painel_escolha.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	escolha_box = VBoxContainer.new()
	escolha_box.add_theme_constant_override("separation", 18)
	painel_escolha.add_child(escolha_box)
	escolha_box.anchor_left = 0.5
	escolha_box.anchor_right = 0.5
	escolha_box.anchor_top = 0.5
	escolha_box.anchor_bottom = 0.5
	escolha_box.offset_left = -330
	escolha_box.offset_right = 330
	escolha_box.offset_top = -40
	escolha_box.offset_bottom = 120

	# balão de nome
	painel_nome = Control.new()
	painel_nome.visible = false
	ui.add_child(painel_nome)
	painel_nome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sombra := ColorRect.new()
	sombra.color = Color(0, 0, 0, 0.55)
	painel_nome.add_child(sombra)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var balao := PanelContainer.new()
	painel_nome.add_child(balao)
	balao.anchor_left = 0.5
	balao.anchor_right = 0.5
	balao.anchor_top = 0.5
	balao.anchor_bottom = 0.5
	balao.offset_left = -330
	balao.offset_right = 330
	balao.offset_top = -170
	balao.offset_bottom = 170
	var est := StyleBoxFlat.new()
	est.bg_color = Color(0.06, 0.07, 0.14, 0.96)
	est.border_color = Color(0.75, 0.8, 1.0)
	est.set_border_width_all(3)
	est.set_corner_radius_all(22)
	est.set_content_margin_all(28)
	balao.add_theme_stylebox_override("panel", est)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	balao.add_child(col)
	var tit := Label.new()
	tit.text = "Qual é o seu nome?"
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tit.add_theme_font_size_override("font_size", 40)
	col.add_child(tit)
	nome_edit = LineEdit.new()
	nome_edit.placeholder_text = "Digite aqui..."
	nome_edit.max_length = 14
	nome_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome_edit.custom_minimum_size = Vector2(0, 80)
	nome_edit.add_theme_font_size_override("font_size", 40)
	col.add_child(nome_edit)
	nome_ok = Button.new()
	nome_ok.text = "Confirmar"
	nome_ok.disabled = true
	nome_ok.custom_minimum_size = Vector2(0, 76)
	nome_ok.add_theme_font_size_override("font_size", 34)
	col.add_child(nome_ok)
	nome_edit.text_changed.connect(func(t: String): nome_ok.disabled = t.strip_edges() == "")
	nome_edit.text_submitted.connect(func(_t: String): _confirmar_nome())
	nome_ok.pressed.connect(_confirmar_nome)

func _confirmar_nome() -> void:
	var n := nome_edit.text.strip_edges()
	if n == "":
		return
	nome_res = n
	nome_pronto = true

# Mostra as opções e devolve o índice escolhido (0, 1, ...). Teclas 1..4, clique ou toque.
func _escolher(opcoes: Array) -> int:
	for c in escolha_box.get_children():
		c.queue_free()
	for i in opcoes.size():
		var b := Button.new()
		b.text = str(opcoes[i])
		b.custom_minimum_size = Vector2(0, 76)
		b.add_theme_font_size_override("font_size", 36)
		var idx := i
		b.pressed.connect(func(): escolha_res = idx)
		escolha_box.add_child(b)
	var mouse_antes := Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	escolha_res = -1
	escolha_n = opcoes.size()
	painel_escolha.visible = true
	while escolha_res < 0:
		await get_tree().process_frame
	painel_escolha.visible = false
	escolha_n = 0
	Input.mouse_mode = mouse_antes
	return escolha_res

# Balão para digitar o nome. Devolve o nome já salvo.
func _pedir_nome() -> String:
	nome_edit.text = ""
	nome_ok.disabled = true
	nome_pronto = false
	var mouse_antes := Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	painel_nome.visible = true
	nome_edit.grab_focus()
	if modo_toque and DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_show("")
	while not nome_pronto:
		await get_tree().process_frame
	painel_nome.visible = false
	nome_edit.release_focus()
	Input.mouse_mode = mouse_antes
	Global.dados["nome_heroi"] = nome_res
	Global.salvar()
	clique = false
	return nome_res

func _fala(texto: String, quem := "", grito := false) -> void:
	var nome := NOME_PROTAGONISTA
	if nome == "":
		nome = str(Global.dados.get("nome_heroi", ""))
	if nome == "":
		nome = str(Global.dados.get("nome", ""))
	if quem != "":
		nome = quem
	nome_label.text = nome
	nome_label.visible = nome != ""
	fala_label.text = texto
	fala_label.add_theme_font_size_override("font_size", 56 if grito else 42)
	fala_label.visible_ratio = 0.0
	caixa.visible = true
	clique = false
	var dur := maxf(0.6, texto.length() / (CPS * (1.6 if grito else 1.0)))
	var t := create_tween()
	t.tween_property(fala_label, "visible_ratio", 1.0, dur)
	while t.is_running():
		if clique:
			t.kill()
			fala_label.visible_ratio = 1.0
			break
		await get_tree().process_frame
	seta.visible = true
	clique = false
	while not clique:
		await get_tree().process_frame
	seta.visible = false
	caixa.visible = false

func _camera_cine() -> void:
	camera.global_position = cine_pos
	if cine_pos.distance_to(cine_look) > 0.01:
		camera.look_at(cine_look)
	if shake > 0.0:
		var a := shake * 0.012
		camera.rotate_object_local(Vector3.RIGHT, sin(tempo * 47.0) * a)
		camera.rotate_object_local(Vector3.UP, sin(tempo * 61.0 + 1.0) * a)
		camera.rotate_object_local(Vector3.BACK, sin(tempo * 39.0 + 2.0) * a * 1.5)

# ---------------------------------------------------------------- gameplay

func _comecar_jogo() -> void:
	humano.modo_loco = true
	humano.ofegante = 0.0
	humano.olhar_yaw = 0.0
	modo = Modo.JOGO
	cam_yaw = 0.0
	cam_pitch = PITCH_INICIAL
	cam_pivot.global_position = jogador.global_position + Vector3(0.0, 1.55, 0.0)
	camera.fov = 65.0
	shake = 0.0
	controles.visible = modo_toque
	if not modo_toque:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not bool(Global.dados.get("tutorial_visto", false)):
		_iniciar_tutorial()

func _entrada_mover() -> Vector2:
	var v := Input.get_vector("mover_esq", "mover_dir", "mover_tras", "mover_frente")
	v += Vector2(joy_vec.x, -joy_vec.y)
	return v.limit_length(1.0)

func _physics_process(delta: float) -> void:
	if modo != Modo.JOGO:
		return
	var entrada := _entrada_mover()
	var no_chao := jogador.is_on_floor()
	# Tab alterna andar/trote
	if Input.is_action_just_pressed("trote"):
		_alternar_trote()
	# Shift: toque rápido = dash; segurando = corrida rápida
	var shift_seg := Input.is_action_pressed("dash") or int(t_botoes["dash"]) != -1
	var shift_soltou_rapido := false
	var shift_apertou := false
	if shift_seg:
		if not shift_ant:
			shift_t = 0.0
			shift_corrida = false
			shift_apertou = true
		shift_t += delta
		if shift_t >= TEMPO_SEGURAR and not shift_corrida and not DASH_AO_APERTAR:
			shift_corrida = true
		elif DASH_AO_APERTAR and not shift_apertou:
			shift_corrida = true
	else:
		if shift_ant and not shift_corrida and not DASH_AO_APERTAR:
			shift_soltou_rapido = true
		shift_corrida = false
	shift_ant = shift_seg
	var quer_correr := shift_corrida or trote_on
	var atacando := tempo < atacando_ate
	var esquivando := tempo < esq_ate
	var emp_ap := Vector3.ZERO
	var dashando := tempo < dash_ate

	var fwd := Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw))
	var dir_d := Vector3(cos(cam_yaw), 0.0, -sin(cam_yaw))
	var dir := fwd * entrada.y + dir_d * entrada.x

	# cargas do dash voltam com o tempo
	if cargas_dash < CARGAS_DASH:
		recarga_dash -= delta
		if recarga_dash <= 0.0:
			cargas_dash += 1
			recarga_dash = RECARGA_DASH
			hud_time.queue_redraw()

	# esquiva e dash (a esquiva cancela o golpe; o dash também)
	var quer_dash := shift_soltou_rapido or (DASH_AO_APERTAR and shift_apertou) or dash_pedido
	var quer_esq := Input.is_action_just_pressed("esquivar") or esq_pedido
	dash_pedido = false
	esq_pedido = false
	if quer_esq and not esquivando and tempo >= esq_cd_ate:
		_iniciar_esquiva(dir, entrada.length())
		esquivando = true
		dashando = false
		atacando = false
	elif quer_dash and not dashando and not esquivando and cargas_dash > 0:
		_iniciar_dash(dir, entrada.length())
		dashando = true
		atacando = false

	if esquivando or dashando:
		fant_prox -= delta
		if fant_prox <= 0.0:
			fant_prox = 0.04
			_fantasma()

	# movimento horizontal
	if esquivando:
		var pr := clampf((tempo - esq_ini) / ESQ_DUR, 0.0, 1.0)
		var ve := lerpf(ESQ_VEL, ESQ_VEL * 0.3, pr)
		jogador.velocity.x = esq_dir.x * ve
		jogador.velocity.z = esq_dir.z * ve
		deslize_fim = true
	elif dashando:
		jogador.velocity.x = dash_dir.x * DASH_VEL
		jogador.velocity.z = dash_dir.z * DASH_VEL
		deslize_fim = true
	elif tempo < lunge_ate:
		jogador.velocity.x = lunge_vel.x
		jogador.velocity.z = lunge_vel.z
		deslize_fim = true
	else:
		var vmax := VEL_ANDAR
		if shift_corrida and entrada.length() > 0.1:
			vmax = VEL_CORRER
		elif trote_on and entrada.length() > 0.1:
			vmax = VEL_TROTE
		if atacando:
			vmax *= 0.55
		var alvo := Vector2(dir.x, dir.z) * vmax
		var acel := 38.0 if no_chao else 22.0
		var vh := Vector2(jogador.velocity.x, jogador.velocity.z)
		if deslize_fim:                      # acabou o dash: não escorrega
			vh = vh.limit_length(VEL_CORRER)
			deslize_fim = false
		vh = vh.move_toward(alvo, acel * delta)
		jogador.velocity.x = vh.x
		jogador.velocity.z = vh.y
		emp_ap = empurrao
		jogador.velocity.x += emp_ap.x
		jogador.velocity.z += emp_ap.z
	empurrao = empurrao.move_toward(Vector3.ZERO, 30.0 * delta)

	# vertical: gravidade mais forte na queda; dash no ar flutua
	if no_chao:
		jogador.velocity.y = maxf(jogador.velocity.y, -1.0)
	elif dashando:
		jogador.velocity.y = maxf(jogador.velocity.y, 0.3)
	else:
		jogador.velocity.y -= GRAVIDADE * (1.35 if jogador.velocity.y < 0.0 else 1.0) * delta

	# pulo com tolerância: "coyote time" (logo depois da borda) e pedido guardado (logo antes de pousar)
	if no_chao:
		coyote_ate = tempo + 0.12
	if Input.is_action_just_pressed("pular") or pular_pedido:
		pulo_buf_ate = tempo + 0.12
	pular_pedido = false
	if tempo < pulo_buf_ate and (no_chao or tempo < coyote_ate) and not esquivando and not dashando:
		jogador.velocity.y = VEL_PULO
		evt_pulou = true
		pulo_buf_ate = 0.0
		coyote_ate = 0.0
	elif jogador.velocity.y > 0.0 and Input.is_action_just_released("pular") and not no_chao:
		jogador.velocity.y *= 0.55          # soltou cedo: pulo mais baixo

	# ataque: o botão apertado um pouco antes vale quando o golpe anterior acaba
	if Input.is_action_just_pressed("atacar") or atacar_pedido:
		atk_buf_ate = tempo + 0.28
	atacar_pedido = false
	if tempo < atk_buf_ate and tempo >= atacando_ate and not esquivando and not dashando:
		atk_buf_ate = 0.0
		atacando = true
		humano.golpear()
		atacando_ate = tempo + 0.5
		evt_atacou = true
		visual.rotation.y = atan2(fwd.x, fwd.z)      # o golpe sai para onde a câmera olha
		var perto := _inimigo_perto(5.5)             # mira assistida: vira e dá um passo até a sombra
		if perto != null:
			var v: Vector3 = perto.global_position - jogador.global_position
			v.y = 0.0
			visual.rotation.y = atan2(v.x, v.z)
			var dd := v.length()
			if dd > 1.7:
				lunge_vel = v.normalized() * clampf((dd - 1.5) / LUNGE_DUR, 0.0, 10.0)
				lunge_ate = tempo + LUNGE_DUR
		get_tree().create_timer(0.18).timeout.connect(_golpe_acerta)

	jogador.move_and_slide()
	jogador.velocity.x -= emp_ap.x          # o empurrão não fica acumulado na velocidade
	jogador.velocity.z -= emp_ap.z
	_verificar_pilares()
	if modo != Modo.JOGO:
		return

	# limites da ilha
	var pp := jogador.global_position
	var rr := Vector2(pp.x, pp.z).length()
	if rr > R_ILHA * 1.03:
		var n := Vector2(pp.x, pp.z) / rr * R_ILHA * 1.03
		jogador.global_position = Vector3(n.x, pp.y, n.y)
	if pp.y < -15.0:
		respawnar()

	# o corpo gira para onde anda
	if entrada.length() > 0.1 and not atacando and not esquivando and not dashando:
		var alvo_y := atan2(dir.x, dir.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, alvo_y, 1.0 - exp(-14.0 * delta))

	# animação
	var vel_h := Vector2(jogador.velocity.x, jogador.velocity.z).length()
	humano.vel_h = vel_h
	humano.correndo = quer_correr and vel_h > 5.0
	if dashando:
		humano.vel_h = 9.0
		humano.correndo = true
	humano.no_ar = not jogador.is_on_floor()

# ---------------------------------------------------------------- dash e esquiva

func _alternar_trote() -> void:
	trote_on = not trote_on
	evt_trote = true
	if jogador_vivo and modo == Modo.JOGO:
		numero_dano(jogador.global_position + Vector3(0.0, 2.3, 0.0), "Trote" if trote_on else "Andar", Color(0.9, 0.95, 1.0))

func _iniciar_dash(dir: Vector3, entrada_len: float) -> void:
	evt_dashou = true
	var d := dir.normalized() if entrada_len > 0.1 else Vector3(sin(visual.rotation.y), 0.0, cos(visual.rotation.y))
	dash_dir = d
	dash_ate = tempo + DASH_DUR
	dash_invul_ate = tempo + 0.15
	if cargas_dash == CARGAS_DASH:
		recarga_dash = RECARGA_DASH
	cargas_dash -= 1
	visual.rotation.y = atan2(d.x, d.z)
	atacando_ate = 0.0
	humano.ataque_t = -1.0
	empurrao = Vector3.ZERO
	_puff(jogador.global_position, Color(0.6, 0.9, 1.0))
	hud_time.queue_redraw()

func _iniciar_esquiva(dir: Vector3, entrada_len: float) -> void:
	var tras := entrada_len <= 0.1          # parado: pula para trás
	var d: Vector3
	if tras:
		d = -Vector3(sin(visual.rotation.y), 0.0, cos(visual.rotation.y))
	else:
		d = dir.normalized()
		visual.rotation.y = atan2(d.x, d.z)
	esq_dir = d
	esq_ini = tempo
	esq_ate = tempo + ESQ_DUR
	esq_invul_ate = tempo + ESQ_INVUL
	esq_cd_ate = tempo + ESQ_DUR + ESQ_RECARGA
	atacando_ate = 0.0
	humano.ataque_t = -1.0
	empurrao = Vector3.ZERO
	if tween_rolo != null:
		tween_rolo.kill()
	tween_rolo = create_tween()
	tween_rolo.tween_method(_passo_rolo.bind(-1.0 if tras else 1.0), 0.0, 1.0, ESQ_DUR)
	tween_rolo.tween_callback(func(): humano.transform = Transform3D.IDENTITY)

# cambalhota em volta do centro do corpo
func _passo_rolo(v: float, sinal: float) -> void:
	var b := Basis(Vector3.RIGHT, sinal * TAU * v)
	var centro := Vector3(0.0, 0.9, 0.0)
	humano.transform = Transform3D(b, centro - b * centro)

# esquivou bem na hora do golpe: o tempo desacelera e o dash recarrega
func _esquiva_perfeita() -> void:
	if tempo < perfeita_cd:
		return
	perfeita_cd = tempo + 2.5
	cargas_dash = CARGAS_DASH
	recarga_dash = RECARGA_DASH
	hud_time.queue_redraw()
	numero_dano(jogador.global_position + Vector3(0.0, 2.3, 0.0), "Esquiva!", Color(0.5, 0.9, 1.0))
	flash_dano.color = Color(0.3, 0.8, 1.0, 0.28)
	create_tween().tween_property(flash_dano, "color:a", 0.0, 0.6)
	_tempo_lento(0.3, 0.9)

# desacelera o jogo por alguns segundos REAIS (também usado na micro-pausa do golpe)
func _tempo_lento(escala: float, dur: float) -> void:
	if lento_ativo and escala > Engine.time_scale / ts_base:
		return                                # já existe uma desaceleração mais forte
	if not lento_ativo:
		ts_base = Engine.time_scale
	lento_ativo = true
	Engine.time_scale = escala * ts_base
	lento_id += 1
	var meu := lento_id
	await get_tree().create_timer(dur, true, false, true).timeout
	if meu == lento_id:
		Engine.time_scale = ts_base
		lento_ativo = false

# rastro de luz atrás do personagem
func _fantasma() -> void:
	var cor: Color = membros[idx_ativo]["cor"] if not membros.is_empty() else Color(0.6, 0.9, 1.0)
	var c := CapsuleMesh.new()
	c.radius = 0.3
	c.height = 1.7
	c.radial_segments = 8
	c.rings = 3
	var m := MeshInstance3D.new()
	m.mesh = c
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(cor.r, cor.g, cor.b, 0.4)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_position = jogador.global_position + Vector3(0.0, 0.9, 0.0)
	var t := create_tween()
	t.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	t.tween_callback(m.queue_free)

func _process(delta: float) -> void:
	tempo += delta
	mat_mar.uv1_offset += Vector3(delta * 0.012, delta * 0.007, 0.0)
	if modo == Modo.CINE:
		_camera_cine()
	else:
		_camera_jogo(delta)
		_tutorial_tick(delta)
	hud_vida.visible = modo == Modo.JOGO and jogador_vivo
	_curar_no_pilar(delta)
	if modo == Modo.JOGO:
		_tick_escolta(delta)

func _camera_jogo(delta: float) -> void:
	var alvo_p := jogador.global_position + Vector3(0.0, 1.55, 0.0)
	cam_pivot.global_position = cam_pivot.global_position.lerp(alvo_p, 1.0 - exp(-16.0 * delta))
	cam_pivot.rotation = Vector3(cam_pitch, cam_yaw, 0.0)
	var comp := spring.get_hit_length()
	camera.global_position = spring.global_position + spring.global_transform.basis.z * comp
	camera.look_at(cam_pivot.global_position + Vector3(0.0, 0.15, 0.0))
	# o campo de visão abre ao correr e no dash (sensação de velocidade)
	var fov_alvo := 65.0
	if tempo < dash_ate:
		fov_alvo = 78.0
	elif tempo < esq_ate:
		fov_alvo = 70.0
	elif shift_corrida and humano.correndo:
		fov_alvo = 70.0
	camera.fov = lerpf(camera.fov, fov_alvo, 1.0 - exp(-9.0 * delta))

# ---------------------------------------------------------------- entrada de eventos

func _set_modo_toque(v: bool) -> void:
	if FORCAR_TOQUE:
		v = true
	if v == modo_toque:
		return
	modo_toque = v
	controles.visible = modo_toque and modo == Modo.JOGO
	if modo == Modo.JOGO:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if modo_toque else Input.MOUSE_MODE_CAPTURED
	_reconstruir_tutorial()

func _input(event: InputEvent) -> void:
	# alterna entre PC e celular conforme o último tipo de entrada
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_set_modo_toque(true)
	elif event is InputEventKey and event.pressed:
		_set_modo_toque(false)

	# avançar diálogos
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clique = true
	elif event is InputEventScreenTouch and event.pressed:
		clique = true
	elif event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
		clique = true

	# menu de escolha: teclas 1..4
	if escolha_n > 0 and event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode - KEY_1
		if k >= 0 and k < escolha_n:
			escolha_res = k

	if modo != Modo.JOGO:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif not modo_toque:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			_trocar(0)
		elif event.keycode == KEY_2:
			_trocar(1)
		elif event.keycode == KEY_3:
			_trocar(2)

	if modo_toque:
		_entrada_toque(event)
		return

	if event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_yaw -= event.relative.x * SENS_MOUSE
		cam_pitch = clampf(cam_pitch - event.relative.y * SENS_MOUSE, -1.0, 0.6)

# ---------------------------------------------------------------- controles de celular

func _botao_centro(nome: String) -> Vector2:
	var s := get_viewport().get_visible_rect().size
	match nome:
		"pular":
			return Vector2(s.x - 170.0, s.y - 200.0)
		"atacar":
			return Vector2(s.x - 340.0, s.y - 120.0)
		"correr":
			return Vector2(s.x - 110.0, s.y - 360.0)
		"trocar":
			return Vector2(s.x - 300.0, s.y - 290.0)
		"dash":
			return Vector2(s.x - 240.0, s.y - 410.0)
		"esquivar":
			return Vector2(s.x - 470.0, s.y - 200.0)
	return Vector2.ZERO

func _botao_raio(nome: String) -> float:
	if nome == "pular":
		return 70.0
	if nome == "atacar":
		return 60.0
	return 52.0

func _botao_em(pos: Vector2) -> String:
	for nome in ["pular", "atacar", "correr", "trocar", "dash", "esquivar"]:
		if nome == "trocar" and membros.size() < 2:
			continue
		if pos.distance_to(_botao_centro(nome)) <= _botao_raio(nome) * 1.25:
			return nome
	return ""

func _entrada_toque(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var pos: Vector2 = event.position
		if event.pressed:
			var nome := _botao_em(pos)
			if nome != "":
				t_botoes[nome] = event.index
				if nome == "pular":
					pular_pedido = true
				elif nome == "atacar":
					atacar_pedido = true
				elif nome == "trocar":
					_trocar_proximo()
				elif nome == "dash":
					pass                      # toque rápido = dash, segurando = corrida (tratado no _physics_process)
				elif nome == "esquivar":
					esq_pedido = true
				else:
					_alternar_trote()
			elif pos.x < get_viewport().get_visible_rect().size.x * 0.45 and t_joy == -1:
				t_joy = event.index
				joy_centro = pos
				joy_pos = pos
				joy_vec = Vector2.ZERO
			elif t_cam == -1:
				t_cam = event.index
		else:
			if event.index == t_joy:
				t_joy = -1
				joy_vec = Vector2.ZERO
			elif event.index == t_cam:
				t_cam = -1
			for n in t_botoes:
				if t_botoes[n] == event.index:
					t_botoes[n] = -1
		controles.queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == t_joy:
			var d: Vector2 = event.position - joy_centro
			joy_vec = (d / JOY_RAIO).limit_length(1.0)
			joy_pos = joy_centro + joy_vec * JOY_RAIO
			controles.queue_redraw()
		elif event.index == t_cam:
			cam_yaw -= event.relative.x * SENS_TOQUE
			cam_pitch = clampf(cam_pitch - event.relative.y * SENS_TOQUE, -1.0, 0.6)

func _desenhar_toque() -> void:
	var fonte := ThemeDB.fallback_font
	var s := get_viewport().get_visible_rect().size
	if t_joy != -1:
		controles.draw_circle(joy_centro, JOY_RAIO, Color(1, 1, 1, 0.12))
		controles.draw_arc(joy_centro, JOY_RAIO, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)
		controles.draw_circle(joy_pos, 48.0, Color(1, 1, 1, 0.45))
	else:
		controles.draw_arc(Vector2(230.0, s.y - 230.0), JOY_RAIO, 0.0, TAU, 48, Color(1, 1, 1, 0.22), 3.0)
	var rotulos := {"pular": "Pular", "atacar": "Atacar", "correr": "Trote", "trocar": "Trocar", "dash": "Dash", "esquivar": "Esquiva"}
	for nome in rotulos:
		if nome == "trocar" and membros.size() < 2:
			continue
		var c := _botao_centro(nome)
		var r := _botao_raio(nome)
		var ativo: bool = t_botoes[nome] != -1 or (nome == "correr" and trote_on)
		controles.draw_circle(c, r, Color(1, 1, 1, 0.38 if ativo else 0.16))
		controles.draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.7), 3.0)
		controles.draw_string(fonte, c + Vector2(-r, 10.0), rotulos[nome],
			HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 26, Color.WHITE)

# ---------------------------------------------------------------- tutorial

func _tecla(txt: String, redonda := false) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.10, 0.14, 0.95)
	sb.border_color = Color(1, 1, 1, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(26 if redonda else 8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(56, 56)
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 28)
	p.add_child(l)
	return p

func _reconstruir_tutorial() -> void:
	for f in linhas_box.get_children():
		f.queue_free()
	tut_rows.clear()
	tut_labels.clear()
	for i in PASSOS.size():
		var passo: Dictionary = PASSOS[i]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		for ic in passo["toque" if modo_toque else "pc"]:
			h.add_child(_tecla(str(ic), modo_toque))
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 30)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(l)
		linhas_box.add_child(h)
		tut_rows.append(h)
		tut_labels.append(l)
	_colorir_tutorial()

func _colorir_tutorial() -> void:
	for i in tut_rows.size():
		var feito := i < tut_passo
		var atual := i == tut_passo
		var cor := Color(1, 1, 1, 0.4)
		if feito:
			cor = Color(0.65, 1.0, 0.65, 0.9)
		elif atual:
			cor = Color(1, 1, 1, 1)
		tut_rows[i].modulate = cor
		var base: String = PASSOS[i]["txt_toque" if modo_toque else "txt_pc"]
		tut_labels[i].text = base + ("  - ok" if feito else "")

func _iniciar_tutorial() -> void:
	tut_ativo = true
	tut_passo = 0
	tut_acum = 0.0
	evt_pulou = false
	evt_atacou = false
	evt_trote = false
	evt_dashou = false
	titulo_tut.text = "Como jogar"
	painel_tut.modulate = Color(1, 1, 1, 0)
	painel_tut.visible = true
	create_tween().tween_property(painel_tut, "modulate:a", 1.0, 0.8)
	_colorir_tutorial()

func _tutorial_tick(delta: float) -> void:
	if not tut_ativo or tut_passo >= PASSOS.size():
		return
	var vh: float = humano.vel_h
	match tut_passo:
		0:
			if vh > 0.8:
				tut_acum += delta
			if tut_acum >= 1.6:
				_tut_proximo()
		1:
			if evt_trote:
				_tut_proximo()
		2:
			if shift_corrida and humano.correndo:
				tut_acum += delta
			if tut_acum >= 1.2:
				_tut_proximo()
		3:
			if evt_dashou:
				_tut_proximo()
		4:
			if evt_pulou:
				_tut_proximo()
		5:
			if evt_atacou:
				_tut_proximo()

func _tut_proximo() -> void:
	tut_passo += 1
	tut_acum = 0.0
	evt_pulou = false
	evt_atacou = false
	evt_trote = false
	evt_dashou = false
	_colorir_tutorial()
	if tut_passo >= PASSOS.size():
		_tut_fim()

func _tut_fim() -> void:
	tut_ativo = false
	titulo_tut.text = "Pronto! Explore a ilha."
	Global.dados["tutorial_visto"] = true
	Global.salvar()
	await _esperar(3.5)
	var t := create_tween()
	t.tween_property(painel_tut, "modulate:a", 0.0, 1.0)
	await t.finished
	painel_tut.visible = false

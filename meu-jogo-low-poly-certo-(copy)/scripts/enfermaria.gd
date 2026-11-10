extends Node3D
# Interior da enfermaria de Vindemia: explorar, sentar no sofá, ganhar comida da Dolly e
# aprender o inventário. Tudo montado por código (os móveis são provisórios).

const HumanoScript := preload("res://scripts/humano.gd")
const InventarioScript := preload("res://scripts/inventario.gd")
const ASSET_COMIDA := "res://assets/comida.glb"   # opcional: seu modelo do prato (se não existir, usa um provisório)
const NOME_DOLLY := "Dolly"
const NOME_JOLENE := "Jolene"
const NOME_KAEL := "Kael"

const VEL_ANDAR := 4.2
const VEL_CORRER := 6.5
const GRAVIDADE := 22.0
const SENS_MOUSE := 0.0025
const SENS_TOQUE := 0.006
const VIDA_MAX := 100.0
const VIDA_INICIAL := 55.0
const SOFA_ASSENTO := Vector3(3.0, 0.38, -3.1)    # onde o protagonista senta
const SOFA_ENTREGA := Vector3(3.0, 0.0, -1.9)     # onde a Dolly para para entregar a comida
const MESA_DOLLY := Vector3(-3.4, 0.0, -2.3)      # onde a Dolly fica diante da mesa

var tipo := "feminino"
var jogador: CharacterBody3D
var visual: Node3D
var humano
var dolly
var jolene
var kael
var lys
var prato: Node3D
var cam_pivot: Node3D
var spring: SpringArm3D
var camera: Camera3D
var cam_yaw := 0.0
var cam_pitch := -0.25
var controle := false
var sentado := false
var sofa_ativo := false
var vida := VIDA_INICIAL
var tempo := 0.0
var modo_toque := false

# interface
var ui: CanvasLayer
var fade: ColorRect
var balao: PanelContainer
var balao_nome: Label
var balao_texto: Label
var objetivo: Label
var aviso: Button
var vida_fill: ColorRect
var vida_txt: Label
var seta: Control
var seta_alvo: Control = null
var inv

# toque
var t_joy := -1
var t_cam := -1
var joy_ini := Vector2.ZERO
var joy_vec := Vector2.ZERO
var joy_ui: Control

func _ready() -> void:
	tipo = str(Global.dados.get("corpo", "feminino"))
	if tipo != "masculino":
		tipo = "feminino"
	modo_toque = OS.has_feature("mobile")
	_montar_ambiente()
	_montar_sala()
	_montar_jogador()
	_montar_dolly()
	_montar_figurantes()
	_montar_ui()
	_atualizar_vida()
	_roteiro()

# ---------------------------------------------------------------- construção da sala

func _bloco(pos: Vector3, tam: Vector3, cor: Color, solido := true, pai: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = 0.9
	mi.material_override = mat
	mi.position = pos
	(pai if pai != null else self).add_child(mi)
	if solido:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = tam
		cs.shape = sh
		sb.add_child(cs)
		mi.add_child(sb)
	return mi

func _cilindro(pos: Vector3, raio: float, alt: float, cor: Color, pai: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = raio
	cm.bottom_radius = raio
	cm.height = alt
	cm.radial_segments = 10
	mi.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = 0.8
	mi.material_override = mat
	mi.position = pos
	(pai if pai != null else self).add_child(mi)
	return mi

func _montar_ambiente() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.93, 0.82)
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	for p in [Vector3(0, 2.9, 0.5), Vector3(-3.0, 2.6, -2.5), Vector3(3.0, 2.6, -2.5)]:
		var l := OmniLight3D.new()
		l.position = p
		l.light_color = Color(1.0, 0.88, 0.7)
		l.light_energy = 1.1
		l.omni_range = 9.0
		add_child(l)

func _montar_sala() -> void:
	var madeira := Color(0.55, 0.40, 0.26)
	var parede := Color(0.88, 0.82, 0.68)
	_bloco(Vector3(0, -0.1, 0), Vector3(10.6, 0.2, 8.6), madeira)                         # chão
	_bloco(Vector3(0, 1.7, -4.25), Vector3(11.1, 3.4, 0.5), parede)                       # parede norte
	_bloco(Vector3(-5.25, 1.7, -3.25), Vector3(0.5, 3.4, 2.1), parede)                    # oeste (com porta da cozinha)
	_bloco(Vector3(-5.25, 1.7, 1.5), Vector3(0.5, 3.4, 5.6), parede)
	_bloco(Vector3(-5.25, 2.9, -1.75), Vector3(0.5, 1.0, 0.9), parede, false)
	_bloco(Vector3(-6.4, 1.5, -1.75), Vector3(0.1, 3.0, 2.4), Color(0.06, 0.05, 0.05), false)   # cozinha (escura)
	_bloco(Vector3(5.25, 1.7, 0), Vector3(0.5, 3.4, 8.6), parede)                         # leste
	_bloco(Vector3(-3.0, 1.7, 4.25), Vector3(4.6, 3.4, 0.5), parede)                      # sul (com vão da porta)
	_bloco(Vector3(3.0, 1.7, 4.25), Vector3(4.6, 3.4, 0.5), parede)
	_bloco(Vector3(0, 2.9, 4.25), Vector3(1.6, 1.0, 0.5), parede, false)
	_bloco(Vector3(0, 0.01, -0.5), Vector3(4.0, 0.03, 3.0), Color(0.62, 0.25, 0.25), false)   # tapete
	# mesa/bancada da cozinha
	_bloco(Vector3(-3.4, 0.475, -3.2), Vector3(2.8, 0.95, 0.9), Color(0.45, 0.30, 0.18))
	_cilindro(Vector3(-4.1, 1.0, -3.2), 0.18, 0.1, Color(0.35, 0.35, 0.4))
	_cilindro(Vector3(-3.3, 0.97, -3.2), 0.16, 0.04, Color(0.92, 0.92, 0.95))
	_cilindro(Vector3(-2.8, 0.97, -3.2), 0.16, 0.04, Color(0.92, 0.92, 0.95))
	# sofá
	_bloco(Vector3(3.0, 0.25, -3.3), Vector3(2.6, 0.5, 0.9), Color(0.35, 0.45, 0.6))
	_bloco(Vector3(3.0, 0.75, -3.7), Vector3(2.6, 0.9, 0.25), Color(0.30, 0.40, 0.55))
	_bloco(Vector3(1.75, 0.45, -3.3), Vector3(0.25, 0.9, 0.9), Color(0.30, 0.40, 0.55))
	_bloco(Vector3(4.25, 0.45, -3.3), Vector3(0.25, 0.9, 0.9), Color(0.30, 0.40, 0.55))
	# camas
	for z in [0.0, 2.2]:
		_bloco(Vector3(-4.2, 0.3, z), Vector3(1.1, 0.6, 1.9), Color(0.92, 0.92, 0.95))
		_bloco(Vector3(-4.2, 0.65, z - 0.7), Vector3(0.8, 0.12, 0.4), Color(0.95, 0.9, 0.8), false)
	# estante com frascos
	_bloco(Vector3(0.0, 1.0, -3.8), Vector3(3.0, 2.0, 0.4), Color(0.42, 0.30, 0.2))
	var cores := [Color(0.3, 0.7, 0.4), Color(0.8, 0.3, 0.3), Color(0.3, 0.5, 0.85), Color(0.9, 0.8, 0.3)]
	for i in 8:
		_cilindro(Vector3(-1.2 + i * 0.34, 1.35 + (i % 2) * 0.5, -3.55), 0.07, 0.2, cores[i % 4])
	# cruz vermelha na parede e janelas
	_bloco(Vector3(0.0, 2.6, -3.98), Vector3(0.7, 0.2, 0.05), Color(0.85, 0.15, 0.15), false)
	_bloco(Vector3(0.0, 2.6, -3.98), Vector3(0.2, 0.7, 0.05), Color(0.85, 0.15, 0.15), false)
	for z in [-1.5, 1.8]:
		var j := _bloco(Vector3(5.0, 1.9, z), Vector3(0.05, 1.1, 1.2), Color(0.6, 0.8, 1.0), false)
		var mat: StandardMaterial3D = j.material_override
		mat.emission_enabled = true
		mat.emission = Color(0.5, 0.7, 1.0)
		mat.emission_energy_multiplier = 0.8

func _montar_jogador() -> void:
	jogador = CharacterBody3D.new()
	add_child(jogador)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	jogador.add_child(cs)
	jogador.position = Vector3(0.0, 0.05, 3.3)
	visual = Node3D.new()
	jogador.add_child(visual)
	humano = HumanoScript.new()
	humano.tipo = tipo
	visual.add_child(humano)
	humano.modo_loco = true
	visual.rotation.y = PI                       # olha para dentro da sala (norte)
	# câmera em terceira pessoa
	cam_pivot = Node3D.new()
	add_child(cam_pivot)
	spring = SpringArm3D.new()
	spring.spring_length = 3.4
	spring.margin = 0.15
	spring.collision_mask = 1
	var esf := SphereShape3D.new()
	esf.radius = 0.2
	spring.shape = esf
	spring.add_excluded_object(jogador.get_rid())
	cam_pivot.add_child(spring)
	camera = Camera3D.new()
	camera.fov = 65.0
	spring.add_child(camera)
	camera.make_current()

func _montar_figurantes() -> void:
	kael = HumanoScript.new()
	kael.tipo = "suporte"
	add_child(kael)
	kael.position = Vector3(1.4, 0.0, -0.7)
	kael.rotation.y = atan2(1.6, -2.4)
	lys = HumanoScript.new()
	lys.tipo = "laranja"
	add_child(lys)
	lys.position = Vector3(4.4, 0.0, -1.0)
	lys.rotation.y = atan2(-1.4, -2.1)
	jolene = HumanoScript.new()
	jolene.tipo = "jolene"
	add_child(jolene)
	jolene.position = Vector3(-6.0, 0.0, -1.75)
	jolene.rotation.y = -PI / 2.0
	jolene.visible = false
	jolene.modo_loco = true

func _montar_dolly() -> void:
	dolly = HumanoScript.new()
	dolly.tipo = "dolly"
	add_child(dolly)
	dolly.scale = Vector3.ONE * 0.92
	dolly.position = Vector3(-0.9, 0.0, 2.7)
	dolly.rotation.y = PI
	dolly.modo_loco = true

# ---------------------------------------------------------------- interface

func _montar_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 5
	add_child(ui)

	# vida (topo, centro)
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.6)
	ui.add_child(fundo)
	_ancorar_topo(fundo, 28, 52, 520)
	vida_fill = ColorRect.new()
	vida_fill.color = Color(0.9, 0.25, 0.3)
	fundo.add_child(vida_fill)
	vida_fill.position = Vector2(3, 3)
	vida_txt = Label.new()
	vida_txt.add_theme_font_size_override("font_size", 20)
	vida_txt.add_theme_color_override("font_outline_color", Color.BLACK)
	vida_txt.add_theme_constant_override("outline_size", 5)
	vida_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(vida_txt)
	_ancorar_topo(vida_txt, 26, 54, 520)

	# objetivo (canto esquerdo)
	objetivo = Label.new()
	objetivo.add_theme_font_size_override("font_size", 30)
	objetivo.add_theme_color_override("font_outline_color", Color.BLACK)
	objetivo.add_theme_constant_override("outline_size", 6)
	objetivo.position = Vector2(30, 28)
	objetivo.visible = false
	ui.add_child(objetivo)

	# aviso de interação (sentar)
	aviso = Button.new()
	aviso.add_theme_font_size_override("font_size", 34)
	aviso.visible = false
	aviso.anchor_left = 0.5
	aviso.anchor_right = 0.5
	aviso.anchor_top = 1.0
	aviso.anchor_bottom = 1.0
	aviso.offset_left = -220
	aviso.offset_right = 220
	aviso.offset_top = -330
	aviso.offset_bottom = -250
	aviso.pressed.connect(_sentar)
	ui.add_child(aviso)

	# balão de fala
	balao = PanelContainer.new()
	balao.visible = false
	ui.add_child(balao)
	balao.anchor_left = 0.0
	balao.anchor_right = 1.0
	balao.anchor_top = 1.0
	balao.anchor_bottom = 1.0
	balao.offset_left = 160
	balao.offset_right = -160
	balao.offset_top = -230
	balao.offset_bottom = -60
	var est := StyleBoxFlat.new()
	est.bg_color = Color(0.04, 0.05, 0.12, 0.88)
	est.border_color = Color(0.75, 0.8, 1.0)
	est.set_border_width_all(3)
	est.set_corner_radius_all(18)
	est.set_content_margin_all(18)
	balao.add_theme_stylebox_override("panel", est)
	var col := VBoxContainer.new()
	balao.add_child(col)
	balao_nome = Label.new()
	balao_nome.add_theme_font_size_override("font_size", 34)
	balao_nome.modulate = Color(1.0, 0.9, 0.6)
	col.add_child(balao_nome)
	balao_texto = Label.new()
	balao_texto.add_theme_font_size_override("font_size", 40)
	balao_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(balao_texto)

	# joystick (celular)
	joy_ui = Control.new()
	joy_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(joy_ui)
	joy_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	joy_ui.draw.connect(_desenhar_joy)

	# inventário
	inv = InventarioScript.new()
	add_child(inv)
	inv.aberto_mudou.connect(_ao_abrir_inventario)

	# seta do tutorial (acima de tudo)
	var cam_seta := CanvasLayer.new()
	cam_seta.layer = 9
	add_child(cam_seta)
	seta = Control.new()
	seta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seta.visible = false
	seta.size = Vector2(60, 70)
	seta.draw.connect(func():
		seta.draw_colored_polygon(PackedVector2Array([Vector2(30, 70), Vector2(0, 28), Vector2(20, 28), Vector2(20, 0), Vector2(40, 0), Vector2(40, 28), Vector2(60, 28)]), Color(1.0, 0.85, 0.2))
		seta.draw_polyline(PackedVector2Array([Vector2(30, 70), Vector2(0, 28), Vector2(20, 28), Vector2(20, 0), Vector2(40, 0), Vector2(40, 28), Vector2(60, 28), Vector2(30, 70)]), Color.BLACK, 3.0))
	cam_seta.add_child(seta)

	# fade
	var cf := CanvasLayer.new()
	cf.layer = 10
	add_child(cf)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cf.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _ancorar_topo(c: Control, topo: float, base: float, meia_larg: float) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.0
	c.anchor_bottom = 0.0
	c.offset_left = -meia_larg
	c.offset_right = meia_larg
	c.offset_top = topo
	c.offset_bottom = base

func _atualizar_vida() -> void:
	var f := clampf(vida / VIDA_MAX, 0.0, 1.0)
	vida_fill.size = Vector2((520.0 * 2 - 6) * f, 18)
	vida_txt.text = "%d / %d" % [int(round(vida)), int(VIDA_MAX)]

func _esperar(s: float) -> void:
	await get_tree().create_timer(s).timeout

# fala com balão: some depois de `dur` segundos (se ninguém tiver trocado o texto)
func _dizer(texto: String, quem: String, dur := 4.0) -> void:
	balao_nome.text = quem
	balao_texto.text = texto
	balao.visible = true
	await _esperar(dur)
	if balao_texto.text == texto:
		balao.visible = false

func _objetivo(t: String) -> void:
	objetivo.text = "▶ " + t
	objetivo.visible = t != ""

func _apontar(alvo: Control) -> void:
	seta_alvo = alvo
	seta.visible = alvo != null

# ---------------------------------------------------------------- roteiro da cena

func _roteiro() -> void:
	fade.color.a = 1.0
	var tf := create_tween()
	tf.tween_property(fade, "color:a", 0.0, 0.8)
	_travar_mouse(true)
	controle = true
	# a Dolly solta o protagonista e vai até a mesa; o jogador já pode andar
	await _mover(dolly, MESA_DOLLY, 6.0)
	await _virar_para(dolly, PI, 0.4)
	await _esperar(0.8)
	await _dizer("Sente-se, fique à vontade, vou buscar comida para você.", NOME_DOLLY, 5.0)
	_objetivo("Sente-se no sofá")
	sofa_ativo = true
	while not sentado:
		await get_tree().process_frame
	_objetivo("")

	# a Dolly pega a comida e traz
	await _esperar(1.0)
	prato = _montar_prato()
	dolly.add_child(prato)
	prato.position = Vector3(0.0, 0.95, 0.4)
	dolly.pose("paz", 0.4)
	await _mover(dolly, SOFA_ENTREGA, 4.0)
	await _virar_para(dolly, PI, 0.4)
	await _dizer("Aqui! Vai se sentir melhor.", NOME_DOLLY, 3.0)
	prato.queue_free()
	dolly.pose("em_pe", 0.4)
	inv.adicionar("prato_comida", 1)
	_objetivo("Você recebeu: Prato de comida")
	await _esperar(2.0)

	# tutorial do inventário
	inv.mostrar_icone(true)
	_objetivo("Abra seu inventário (clique em Mochila ou aperte I)")
	_apontar(inv.get_icone())
	while not inv.aberto:
		await inv.aberto_mudou
	_objetivo("Selecione o prato de comida")
	await get_tree().process_frame
	await get_tree().process_frame
	_apontar(inv.get_slot("prato_comida"))
	await inv.item_selecionado
	_objetivo("Consuma o item")
	_apontar(inv.get_btn_consumir())
	await inv.consumido
	_apontar(null)
	_objetivo("")
	vida = minf(vida + float(inv.ITENS["prato_comida"]["cura"]), VIDA_MAX)
	_atualizar_vida()
	await _esperar(1.0)
	inv.fechar()
	await _esperar(0.8)

	# de volta à cena
	await _dizer("Está se sentindo melhor?", NOME_DOLLY, 3.0)
	await _acenar()
	await _esperar(0.8)
	await _cena_jolene()
	humano.pose("em_pe", 0.5)
	sentado = false
	jogador.global_position = Vector3(SOFA_ASSENTO.x, 0.05, SOFA_ASSENTO.z + 1.0)
	humano.modo_loco = true
	Global.dados["vida_atual"] = vida
	Global.dados["etapa"] = 8
	Global.dados["tutorial_inventario_visto"] = true
	Global.salvar()
	_travar_mouse(true)
	controle = true
	_objetivo("Fim desta parte por enquanto. Pode explorar a enfermaria.")

# ---------------------------------------------------------------- cutscene: conhecendo a Jolene

func _olhar_para(no: Node3D, alvo: Vector3, dur := 0.35) -> void:
	var d := alvo - no.position
	await _virar_para(no, atan2(d.x, d.z), dur)

func _cena_jolene() -> void:
	controle = false
	var heroi := str(Global.dados.get("nome_heroi", ""))
	if heroi == "":
		heroi = "viajante"
	var ele := "ela" if tipo == "feminino" else "ele"
	var assento := SOFA_ASSENTO
	var este := "esta" if tipo == "feminino" else "este"

	# passos na cozinha: Jolene aparece com alguns frascos
	await _esperar(0.6)
	jolene.visible = true
	var frascos := Node3D.new()
	jolene.add_child(frascos)
	frascos.position = Vector3(0.0, 1.0, 0.35)
	var cores := [Color(0.3, 0.7, 0.4), Color(0.8, 0.3, 0.3), Color(0.3, 0.5, 0.85)]
	for i in 3:
		_cilindro(Vector3(-0.1 + i * 0.1, 0.0, 0.0), 0.04, 0.16, cores[i], frascos)
	jolene.pose("paz", 0.4)
	await _mover(jolene, Vector3(-3.0, 0.0, -1.75), 3.2)
	await _mover(jolene, Vector3(-2.35, 0.0, -2.35), 1.0)
	await _virar_para(jolene, PI, 0.4)
	# coloca os frascos sobre o balcão
	await _esperar(0.4)
	frascos.queue_free()
	for i in 3:
		_cilindro(Vector3(-2.55 + i * 0.2, 1.05, -3.2), 0.05, 0.16, cores[i])
	jolene.pose("em_pe", 0.4)
	await _esperar(0.6)
	# limpa as mãos no avental
	jolene.pose("paz", 0.4)
	jolene.tremor = 0.45
	await _esperar(1.4)
	jolene.tremor = 0.0
	jolene.pose("em_pe", 0.4)
	await _olhar_para(jolene, dolly.position)
	await _dizer("Dolly, querida, o que está acontecendo por aqui?", NOME_JOLENE, 3.6)

	# ela se aproxima do grupo e observa o protagonista
	await _mover(jolene, Vector3(2.0, 0.0, -1.5), 4.2)
	await _olhar_para(jolene, assento, 0.4)
	await _dizer("Ora... Temos uma visita? O que aconteceu? Está tudo bem?", NOME_JOLENE, 4.2)
	await _olhar_para(kael, jolene.position)
	await _dizer("Olá, Jolene! Encontramos %s viajante pelo caminho. %s acabou se machucando, então pensamos que seria melhor trazê-l%s até você." % [este, ele.capitalize(), "a" if tipo == "feminino" else "o"], NOME_KAEL, 6.2)
	await _dizer("Entendo... E como você se chama, meu bem?", NOME_JOLENE, 3.6)
	await _dizer("Me chamo %s." % heroi, heroi, 2.6)
	await _olhar_para(kael, jolene.position)
	await _dizer("%s é %s. Acabamos nos conhecendo durante a viagem." % [este.capitalize(), heroi], NOME_KAEL, 4.4)
	await _dizer("Muito prazer, %s. Sou Jolene, a responsável pela enfermaria. E aquela pequena ajudante ali é minha filha, Dolly." % heroi, NOME_JOLENE, 6.4)
	await _olhar_para(dolly, jolene.position)
	dolly.pose("risada", 0.3)
	await _dizer("Eu já trouxe comida pra %s, mamãe!" % ele, NOME_DOLLY, 3.6)
	dolly.pose("em_pe", 0.5)
	await _dizer("Ah, foi mesmo? Muito bem, querida.", NOME_JOLENE, 3.0)
	await _olhar_para(jolene, dolly.position, 0.3)
	jolene.pose("risada", 0.4)
	await _esperar(1.0)
	jolene.pose("em_pe", 0.4)
	await _olhar_para(jolene, assento, 0.4)
	await _dizer("Bem, vamos dar uma olhadinha nesses ferimentos? Não precisa se preocupar, está em boas mãos.", NOME_JOLENE, 5.6)
	# gesto gentil para o protagonista se aproximar
	jolene.pose("alcancar", 0.5)
	await _esperar(1.4)
	jolene.pose("em_pe", 0.5)

func _montar_prato() -> Node3D:
	var n := Node3D.new()
	if ResourceLoader.exists(ASSET_COMIDA):
		var ps = load(ASSET_COMIDA)
		if ps is PackedScene:
			n.add_child(ps.instantiate())
			return n
	_cilindro(Vector3.ZERO, 0.17, 0.03, Color(0.92, 0.92, 0.95), n)
	var comida := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.08
	sm.height = 0.12
	comida.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.45, 0.2)
	comida.material_override = mat
	comida.position = Vector3(0.0, 0.07, 0.0)
	n.add_child(comida)
	_cilindro(Vector3(0.09, 0.04, 0.05), 0.04, 0.03, Color(0.35, 0.65, 0.25), n)
	return n

func _mover(no: Node3D, destino: Vector3, dur: float) -> void:
	var d := destino - no.position
	d.y = 0.0
	if d.length() > 0.1:
		no.rotation.y = atan2(d.x, d.z)
	if "modo_loco" in no:
		no.vel_h = 3.0
	var tw := create_tween()
	tw.tween_property(no, "position", Vector3(destino.x, no.position.y, destino.z), dur)
	await tw.finished
	if "modo_loco" in no:
		no.vel_h = 0.0

func _virar_para(no: Node3D, ang: float, dur: float) -> void:
	var tw := create_tween()
	var de := no.rotation.y
	tw.tween_method(func(k: float): no.rotation.y = lerp_angle(de, ang, k), 0.0, 1.0, dur)
	await tw.finished

func _acenar() -> void:
	var tw := create_tween()
	for i in 2:
		tw.tween_property(humano, "olhar_pitch", 18.0, 0.25)
		tw.tween_property(humano, "olhar_pitch", -2.0, 0.25)
	tw.tween_property(humano, "olhar_pitch", 0.0, 0.15)
	await tw.finished

# ---------------------------------------------------------------- sentar

func _sentar() -> void:
	if sentado or not sofa_ativo:
		return
	sentado = true
	controle = false
	aviso.visible = false
	joy_vec = Vector2.ZERO
	_travar_mouse(false)
	jogador.velocity = Vector3.ZERO
	var tw := create_tween().set_parallel(true)
	tw.tween_property(jogador, "global_position", SOFA_ASSENTO, 0.5)
	tw.tween_property(visual, "rotation:y", 0.0, 0.5)
	tw.tween_property(self, "cam_yaw", 0.0, 0.8)
	tw.tween_property(self, "cam_pitch", -0.15, 0.8)
	humano.modo_loco = false
	humano.vel_h = 0.0
	humano.pose("sentado", 0.5)

func _travar_mouse(capturar: bool) -> void:
	if modo_toque:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capturar else Input.MOUSE_MODE_VISIBLE

func _ao_abrir_inventario(aberto: bool) -> void:
	if not aberto:
		return

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# ---------------------------------------------------------------- entrada e movimento

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_sentar_se_perto()
		elif event.keycode == KEY_ESCAPE and controle:
			_travar_mouse(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
	if event is InputEventMouseButton and event.pressed and controle and not inv.aberto \
			and not modo_toque and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_travar_mouse(true)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and controle:
		cam_yaw -= event.relative.x * SENS_MOUSE
		cam_pitch = clampf(cam_pitch - event.relative.y * SENS_MOUSE, -1.2, 0.5)
	if modo_toque or event is InputEventScreenTouch or event is InputEventScreenDrag:
		_entrada_toque(event)

func _entrada_toque(event: InputEvent) -> void:
	if not controle or inv.aberto:
		return
	var tam := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < tam.x * 0.5 and t_joy == -1:
				t_joy = event.index
				joy_ini = event.position
			elif t_cam == -1:
				t_cam = event.index
		else:
			if event.index == t_joy:
				t_joy = -1
				joy_vec = Vector2.ZERO
			elif event.index == t_cam:
				t_cam = -1
		joy_ui.queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == t_joy:
			joy_vec = ((event.position - joy_ini) / 110.0).limit_length(1.0)
			joy_ui.queue_redraw()
		elif event.index == t_cam:
			cam_yaw -= event.relative.x * SENS_TOQUE
			cam_pitch = clampf(cam_pitch - event.relative.y * SENS_TOQUE, -1.2, 0.5)

func _desenhar_joy() -> void:
	if t_joy == -1:
		return
	joy_ui.draw_circle(joy_ini, 110.0, Color(1, 1, 1, 0.15))
	joy_ui.draw_circle(joy_ini + joy_vec * 110.0, 46.0, Color(1, 1, 1, 0.4))

func _sentar_se_perto() -> void:
	if sofa_ativo and not sentado and controle and _perto_do_sofa():
		_sentar()

func _perto_do_sofa() -> bool:
	return Vector2(jogador.global_position.x - SOFA_ENTREGA.x, jogador.global_position.z - SOFA_ENTREGA.z).length() < 2.2

func _physics_process(delta: float) -> void:
	if controle and not inv.aberto:
		var v := Input.get_vector("ui_left", "ui_right", "ui_down", "ui_up")
		if Input.is_key_pressed(KEY_A):
			v.x -= 1.0
		if Input.is_key_pressed(KEY_D):
			v.x += 1.0
		if Input.is_key_pressed(KEY_W):
			v.y += 1.0
		if Input.is_key_pressed(KEY_S):
			v.y -= 1.0
		v += Vector2(joy_vec.x, -joy_vec.y)
		v = v.limit_length(1.0)
		var correr := Input.is_key_pressed(KEY_SHIFT)
		var vel := VEL_CORRER if correr else VEL_ANDAR
		var dir := Basis(Vector3.UP, cam_yaw) * Vector3(v.x, 0.0, -v.y)
		jogador.velocity.x = dir.x * vel
		jogador.velocity.z = dir.z * vel
		if v.length() > 0.1:
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 12.0))
		humano.vel_h = Vector2(jogador.velocity.x, jogador.velocity.z).length()
		humano.correndo = correr and humano.vel_h > 0.5
		if not jogador.is_on_floor():
			jogador.velocity.y -= GRAVIDADE * delta
		else:
			jogador.velocity.y = -1.0
		jogador.move_and_slide()
	elif not sentado:
		jogador.velocity.x = 0.0
		jogador.velocity.z = 0.0
		humano.vel_h = 0.0

func _process(delta: float) -> void:
	tempo += delta
	cam_pivot.global_position = cam_pivot.global_position.lerp(jogador.global_position + Vector3(0.0, 1.5, 0.0), 1.0 - exp(-14.0 * delta))
	cam_pivot.rotation = Vector3(cam_pitch, cam_yaw, 0.0)
	# aviso de "sentar"
	var mostrar := sofa_ativo and not sentado and controle and _perto_do_sofa()
	aviso.visible = mostrar
	if mostrar:
		aviso.text = "Sentar" if modo_toque else "E  -  Sentar"
	# seta do tutorial balançando acima do alvo
	if seta_alvo != null and is_instance_valid(seta_alvo) and seta_alvo.is_visible_in_tree():
		var r := seta_alvo.get_global_rect()
		seta.visible = true
		seta.position = Vector2(r.position.x + r.size.x * 0.5 - 30.0, r.position.y - 76.0 + sin(tempo * 7.0) * 8.0)
	elif seta_alvo != null:
		seta.visible = false

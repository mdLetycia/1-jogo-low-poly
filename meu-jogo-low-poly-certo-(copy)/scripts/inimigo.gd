extends CharacterBody3D
# Sombra: inimigo provisório. Detecta o protagonista, avisa o grupo, corre até ele,
# ataca, recebe dano e morre. Se perder o protagonista de vista, volta para a posição inicial.

signal contato                       # emitido uma vez, quando alcança o protagonista
signal morreu(inimigo)

enum Estado { SURGINDO, PARADO, ALERTA, PERSEGUIR, CERCAR, ATACAR, VOLTAR, MORTO }

const PilarScript := preload("res://scripts/pilar.gd")

# valores que o chefe (chefe.gd) sobrescreve
var VIDA_MAX := 30
var DANO := 8                        # dano que a sombra causa no protagonista
var RAIO_DETECTAR := 15.0            # distância em que ela enxerga o protagonista
var RAIO_PERDER := 30.0              # passou disso, perdeu de vista e volta para casa
const RAIO_LONGE_DE_CASA := 55.0     # também desiste se for arrastada longe demais
var VEL_CORRIDA := 7.4
const VEL_VOLTAR := 5.5
var ALCANCE_ATAQUE := 1.9
var DIST_CONTATO := 2.2
var PREPARO := 0.6                   # tempo "armando" o golpe (dá para desviar)
const RECUPERA := 0.45
var RECARGA := 1.5                   # intervalo mínimo entre ataques
const MAX_ATACANTES := 2             # no máximo 2 sombras atacando ao mesmo tempo
const KNOCKBACK := 5.0                # quanto a sombra é empurrada ao apanhar (menor = menos)
var escala := 1.0                    # tamanho do corpo
var dist_alvo := 1.6                 # a que distância do protagonista ela para
var peso := 1.0                      # quanto mais pesado, menos é empurrado
var aturde_dur := 0.28
var super_armadura := false          # true = golpe do jogador não interrompe o ataque
var dur_surgir := 1.4
var cor_emissao := Color(0.25, 0.08, 0.35)
const GRAVIDADE := 22.0

var mundo: Node = null               # quem controla o protagonista (mundo.gd)
var alvo: Node3D = null
var estado := Estado.SURGINDO
var casa := Vector3.ZERO
var slot := 0.0                      # ângulo ao redor do alvo (cada sombra pega um lado)
var tempo := 0.0
var vida := VIDA_MAX
var empurrao := Vector3.ZERO
var aturdido_ate := 0.0
var recarga_ate := 0.0
var piscar := 0.0
var t_estado := 0.0
var bateu := false
var inclina := 0.0
var visual: Node3D
var mat_corpo: StandardMaterial3D
var mat_olho: StandardMaterial3D
var exclamacao: Label3D
var barra: Node3D
var barra_fill: MeshInstance3D
var avisou := false

func _ready() -> void:
	collision_layer = 4              # inimigos: camada 3 (valor 4)
	collision_mask = 1 | 4           # chão e outros inimigos
	add_to_group("inimigos")
	casa = global_position
	_montar()
	visual.scale = Vector3.ZERO
	var t := create_tween()
	t.tween_property(visual, "scale", Vector3.ONE * escala, dur_surgir).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func(): if estado == Estado.SURGINDO: estado = Estado.PARADO)

func alertar(atraso := 0.0) -> void:
	if estado != Estado.PARADO:
		return
	estado = Estado.ALERTA
	await get_tree().create_timer(atraso + 0.55).timeout
	if estado == Estado.ALERTA:
		estado = Estado.PERSEGUIR

# ---------------------------------------------------------------- dano

func levar_dano(valor: int, de: Vector3) -> void:
	if estado == Estado.MORTO or estado == Estado.SURGINDO:
		return
	vida -= valor
	var d := global_position - de
	d.y = 0.0
	empurrao = d.normalized() * KNOCKBACK / peso if d.length() > 0.01 else Vector3.ZERO
	aturdido_ate = tempo + aturde_dur
	piscar = 0.14
	if mundo != null:
		mundo.numero_dano(global_position + Vector3(0.0, 2.4, 0.0), str(valor), Color(1.0, 0.92, 0.55))
	_atualizar_barra()
	if vida <= 0:
		_morrer()
		return
	if estado == Estado.ATACAR and not super_armadura:   # golpe interrompido
		estado = Estado.PERSEGUIR
		recarga_ate = tempo + 0.6
	elif estado == Estado.PARADO or estado == Estado.ALERTA or estado == Estado.VOLTAR:
		estado = Estado.PERSEGUIR
		_avistar()                               # apanhou: o grupo todo reage

func _morrer() -> void:
	estado = Estado.MORTO
	collision_layer = 0
	collision_mask = 0
	remove_from_group("inimigos")
	exclamacao.visible = false
	barra.visible = false
	morreu.emit(self)
	# fumaça de luz roxa
	var p := PilarScript.criar_motes(Color(0.7, 0.4, 1.0), 22, 0.5, 1.2)
	p.position = global_position + Vector3(0.0, 0.5, 0.0)
	p.emitting = true
	var pai := get_parent()
	if pai != null:
		pai.add_child(p)
		get_tree().create_timer(1.2).timeout.connect(func(): p.emitting = false)
		get_tree().create_timer(5.0).timeout.connect(p.queue_free)
	var t := create_tween().set_parallel(true)
	t.tween_property(visual, "scale", Vector3(1.3 * escala, 0.05, 1.3 * escala), 0.5).set_trans(Tween.TRANS_SINE)
	t.chain().tween_callback(queue_free)

func _atualizar_barra() -> void:
	barra.visible = vida > 0 and vida < VIDA_MAX
	barra_fill.scale.x = clampf(float(vida) / VIDA_MAX, 0.001, 1.0)

# ---------------------------------------------------------------- comportamento

func _voltar() -> void:
	estado = Estado.VOLTAR
	t_estado = 0.0
	avisou = false

# usado nas cutscenes: interrompe o que estava fazendo e dá um respiro
func acalmar() -> void:
	if estado == Estado.ATACAR or estado == Estado.CERCAR or estado == Estado.PERSEGUIR:
		estado = Estado.PERSEGUIR
		recarga_ate = tempo + 2.0
	aturdido_ate = 0.0
	empurrao = Vector3.ZERO

func _atacantes() -> int:
	var n := 0
	for o in get_tree().get_nodes_in_group("inimigos"):
		if o.estado == Estado.ATACAR:
			n += 1
	return n

func _tentar_atacar(dist: float) -> void:
	if dist < ALCANCE_ATAQUE and tempo >= recarga_ate and _atacantes() < MAX_ATACANTES:
		estado = Estado.ATACAR
		t_estado = 0.0
		bateu = false

func _physics_process(delta: float) -> void:
	tempo += delta
	if estado == Estado.MORTO:
		return
	if mundo != null and mundo.congelar_inimigos:      # durante cutscenes ficam parados
		velocity = Vector3.ZERO
		return
	var plano := Vector3.ZERO
	var quer := Vector3.ZERO
	var vel := 0.0
	var dist := 99999.0
	var valido: bool = alvo != null and mundo != null and mundo.alvo_valido()
	if valido:
		plano = alvo.global_position - global_position
		plano.y = 0.0
		dist = plano.length()
	var dist_casa := Vector2(global_position.x - casa.x, global_position.z - casa.z).length()
	var atordoado := tempo < aturdido_ate

	if estado != Estado.SURGINDO and not atordoado:
		match estado:
			Estado.PARADO:
				visual.rotation.y += sin(tempo * 0.6 + slot) * 0.4 * delta
				if valido and dist < RAIO_DETECTAR:
					_avistar()
			Estado.ALERTA:
				_olhar(plano, delta, 12.0)
				if not valido:
					_voltar()
			Estado.PERSEGUIR, Estado.CERCAR:
				if not valido or dist > RAIO_PERDER or dist_casa > RAIO_LONGE_DE_CASA:
					_voltar()
				elif estado == Estado.PERSEGUIR:
					var ponto := alvo.global_position + Vector3(cos(slot), 0.0, sin(slot)) * dist_alvo
					quer = ponto - global_position
					quer.y = 0.0
					vel = VEL_CORRIDA
					if dist < DIST_CONTATO:
						estado = Estado.CERCAR
						if not avisou:
							avisou = true
							contato.emit()
				else:
					var ponto2 := alvo.global_position + Vector3(cos(slot), 0.0, sin(slot)) * (dist_alvo + 0.2)
					quer = ponto2 - global_position
					quer.y = 0.0
					vel = 3.0 if quer.length() > 0.4 else 0.0
					_olhar(plano, delta, 10.0)
					if dist > DIST_CONTATO * 2.2:
						estado = Estado.PERSEGUIR
				if estado == Estado.PERSEGUIR or estado == Estado.CERCAR:
					_tentar_atacar(dist)
			Estado.ATACAR:
				t_estado += delta
				_olhar(plano, delta, 12.0 if t_estado < PREPARO else 0.0)
				if t_estado >= PREPARO and not bateu:
					bateu = true
					if valido and dist < ALCANCE_ATAQUE + 0.7:
						if super_armadura:
							mundo.tremer(0.7)
						mundo.dano_no_jogador(DANO, global_position)
						empurrao = plano.normalized() * 4.0       # avanço do golpe
				if t_estado >= PREPARO + RECUPERA:
					recarga_ate = tempo + RECARGA + randf() * 0.6
					estado = Estado.PERSEGUIR if not valido else Estado.CERCAR
			Estado.VOLTAR:
				t_estado += delta
				quer = casa - global_position
				quer.y = 0.0
				vel = VEL_VOLTAR
				if dist_casa < 0.8:
					vida = VIDA_MAX
					_atualizar_barra()
					estado = Estado.PARADO

	exclamacao.visible = estado == Estado.ALERTA or (estado == Estado.VOLTAR and t_estado < 1.6)
	exclamacao.text = "!" if estado == Estado.ALERTA else "?"

	var dir := quer.normalized() if quer.length() > 0.05 else Vector3.ZERO
	var alvo_v := dir * vel
	velocity.x = move_toward(velocity.x, alvo_v.x, 40.0 * delta)
	velocity.z = move_toward(velocity.z, alvo_v.z, 40.0 * delta)
	var emp_ap := empurrao                 # o empurrão vale só neste quadro (não se acumula na velocidade)
	velocity.x += emp_ap.x
	velocity.z += emp_ap.z
	empurrao = empurrao.move_toward(Vector3.ZERO, 28.0 * delta)
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= GRAVIDADE * delta
	move_and_slide()
	velocity.x -= emp_ap.x
	velocity.z -= emp_ap.z

	var vh := Vector2(velocity.x, velocity.z).length()
	if vh > 0.5 and (estado == Estado.PERSEGUIR or estado == Estado.VOLTAR):
		_olhar(Vector3(velocity.x, 0.0, velocity.z), delta, 14.0)

	# animação: balança ao correr; arma o golpe para trás e desfere para frente
	var correndo := clampf(vh / VEL_CORRIDA, 0.0, 1.0)
	visual.position.y = absf(sin(tempo * 13.0)) * 0.18 * correndo
	var alvo_incl := 0.35 * correndo
	if estado == Estado.ATACAR:
		alvo_incl = -0.45 if t_estado < PREPARO else 0.75
	visual.rotation.x = lerpf(visual.rotation.x, alvo_incl, 1.0 - exp(-14.0 * delta))

	# brilho do corpo: branco ao apanhar, vermelho crescente ao armar o golpe
	if piscar > 0.0:
		piscar -= delta
		mat_corpo.emission = Color(1, 1, 1)
		mat_corpo.emission_energy_multiplier = 2.5
	elif estado == Estado.ATACAR and t_estado < PREPARO:
		mat_corpo.emission = Color(1.0, 0.15, 0.1)
		mat_corpo.emission_energy_multiplier = lerpf(0.4, 2.2, t_estado / PREPARO)
	else:
		mat_corpo.emission = cor_emissao
		mat_corpo.emission_energy_multiplier = 0.4

	var pulso := 1.6 + sin(tempo * 4.0) * 0.4
	if estado == Estado.PERSEGUIR or estado == Estado.CERCAR or estado == Estado.ATACAR:
		pulso = 3.2
	mat_olho.emission_energy_multiplier = pulso

func _process(_delta: float) -> void:
	# a barra de vida sempre olha para a câmera
	if barra != null and barra.visible:
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			barra.look_at(cam.global_position, Vector3.UP)

func _avistar() -> void:
	# o primeiro que vê avisa o grupo inteiro (cada um reage com um pequeno atraso)
	var i := 0
	for o in get_tree().get_nodes_in_group("inimigos"):
		o.alertar(i * 0.18)
		i += 1

func _olhar(v: Vector3, delta: float, rapidez: float) -> void:
	if v.length() < 0.05 or rapidez <= 0.0:
		return
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(v.x, v.z), 1.0 - exp(-rapidez * delta))

func _quad(tam: Vector2, cor: Color, prioridade: int) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = tam
	var m := MeshInstance3D.new()
	m.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mat.render_priority = prioridade
	mat.albedo_color = cor
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m

func _montar() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4 * escala
	cap.height = 1.7 * escala
	col.shape = cap
	col.position = Vector3(0, 0.85 * escala, 0)
	add_child(col)

	visual = Node3D.new()
	add_child(visual)

	var mat := StandardMaterial3D.new()
	mat_corpo = mat
	mat.albedo_color = Color(0.08, 0.05, 0.12)
	mat.roughness = 1.0
	mat.emission_enabled = true
	mat.emission = Color(0.25, 0.08, 0.35)
	mat.emission_energy_multiplier = 0.4

	var corpo := CapsuleMesh.new()
	corpo.radius = 0.38
	corpo.height = 1.5
	corpo.radial_segments = 7
	corpo.rings = 3
	var mc := MeshInstance3D.new()
	mc.mesh = corpo
	mc.material_override = mat
	mc.position = Vector3(0, 0.85, 0)
	mc.scale = Vector3(1.0, 1.0, 0.85)
	visual.add_child(mc)

	var cab := SphereMesh.new()
	cab.radius = 0.3
	cab.height = 0.6
	cab.radial_segments = 8
	cab.rings = 4
	var mh := MeshInstance3D.new()
	mh.mesh = cab
	mh.material_override = mat
	mh.position = Vector3(0, 1.72, 0.04)
	visual.add_child(mh)

	# braços longos e caídos
	for lado in [-1.0, 1.0]:
		var br := CapsuleMesh.new()
		br.radius = 0.08
		br.height = 1.1
		br.radial_segments = 6
		br.rings = 2
		var mb := MeshInstance3D.new()
		mb.mesh = br
		mb.material_override = mat
		mb.position = Vector3(0.46 * lado, 0.95, 0.1)
		mb.rotation_degrees = Vector3(-12.0, 0.0, 8.0 * lado)
		visual.add_child(mb)

	# olhos
	mat_olho = StandardMaterial3D.new()
	mat_olho.albedo_color = Color(1.0, 0.25, 0.2)
	mat_olho.emission_enabled = true
	mat_olho.emission = Color(1.0, 0.2, 0.15)
	mat_olho.emission_energy_multiplier = 1.6
	mat_olho.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for lado2 in [-1.0, 1.0]:
		var ol := SphereMesh.new()
		ol.radius = 0.055
		ol.height = 0.11
		ol.radial_segments = 6
		ol.rings = 3
		var mo := MeshInstance3D.new()
		mo.mesh = ol
		mo.material_override = mat_olho
		mo.position = Vector3(0.11 * lado2, 1.76, 0.29)
		visual.add_child(mo)

	exclamacao = Label3D.new()
	exclamacao.text = "!"
	exclamacao.font_size = 120
	exclamacao.pixel_size = 0.006
	exclamacao.modulate = Color(1.0, 0.35, 0.25)
	exclamacao.outline_modulate = Color.BLACK
	exclamacao.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	exclamacao.no_depth_test = true
	exclamacao.position = Vector3(0, 2.5 * escala, 0)
	exclamacao.visible = false
	add_child(exclamacao)

	# barra de vida (só aparece depois do primeiro dano)
	barra = Node3D.new()
	barra.position = Vector3(0, 2.15 * escala, 0)
	barra.scale = Vector3.ONE * maxf(1.0, escala * 0.6)
	barra.visible = false
	add_child(barra)
	var fundo := _quad(Vector2(1.04, 0.14), Color(0, 0, 0, 0.8), 0)
	barra.add_child(fundo)
	barra_fill = _quad(Vector2(1.0, 0.09), Color(0.85, 0.25, 0.9), 1)
	(barra_fill.mesh as QuadMesh).center_offset = Vector3(0.5, 0, 0)
	barra_fill.position = Vector3(-0.5, 0, 0.01)
	barra.add_child(barra_fill)

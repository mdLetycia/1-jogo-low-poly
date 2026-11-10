extends Node3D
# Pilar da Deusa: ponto de renascimento. O mesmo script serve para todos os pilares
# (um por nação). Para criar outro: PilarScript.new(), mude id e nome_nacao, add_child.

const COR_DORMENTE := Color(0.30, 0.55, 0.50)
const COR_ATIVA := Color(1.0, 0.80, 0.42)

var id := "fecundia"
var nome_nacao := "Fecúndia"
var raio_gatilho := 9.0
var ativado := false

var mat_runa: StandardMaterial3D
var mat_cristal: StandardMaterial3D
var cristal: MeshInstance3D
var luz: OmniLight3D
var motes: CPUParticles3D
var brilho := 0.0
var tempo := 0.0

func _ready() -> void:
	_montar()
	ativado = Global.pilar_ativado(id)
	_set_brilho(1.0 if ativado else 0.0)

# ---------------------------------------------------------------- ativação

func ativar(instantaneo := false) -> void:
	ativado = true
	if instantaneo:
		_set_brilho(1.0)
		return
	var t := create_tween()
	t.tween_method(_set_brilho, brilho, 1.0, 2.2).set_trans(Tween.TRANS_SINE)
	_onda(0.0)
	get_tree().create_timer(0.5).timeout.connect(_onda.bind(0.0))

func _set_brilho(v: float) -> void:
	brilho = v
	var cor := COR_DORMENTE.lerp(COR_ATIVA, v)
	mat_runa.emission = cor
	mat_runa.emission_energy_multiplier = lerpf(0.25, 3.2, v)
	mat_cristal.emission = cor
	mat_cristal.emission_energy_multiplier = lerpf(0.3, 2.6, v)
	luz.light_color = cor
	luz.light_energy = lerpf(0.2, 1.8, v)
	motes.emitting = v > 0.05

# anel de luz que se abre no chão
func _onda(_x: float) -> void:
	var m := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.92
	tor.outer_radius = 1.0
	tor.rings = 24
	tor.ring_segments = 6
	m.mesh = tor
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.85, 0.5, 0.8)
	m.material_override = mat
	m.position = Vector3(0, 0.3, 0)
	m.scale = Vector3(0.6, 0.6, 0.6)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	var t := create_tween().set_parallel(true)
	t.tween_property(m, "scale", Vector3(7.0, 1.0, 7.0), 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color:a", 0.0, 2.4)
	t.chain().tween_callback(m.queue_free)

func _process(delta: float) -> void:
	tempo += delta
	if cristal == null:
		return
	cristal.rotation.y += delta * lerpf(0.3, 0.9, brilho)
	cristal.position.y = 3.85 + sin(tempo * 1.3) * 0.08
	luz.light_energy = lerpf(0.2, 1.8, brilho) * (0.92 + 0.08 * sin(tempo * 2.1))

# ---------------------------------------------------------------- partículas reutilizáveis

# pontinhos de luz que giram em volta de um ponto (usado no pilar e no protagonista)
static func criar_motes(cor: Color, quantidade: int, raio: float, altura: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	mat.albedo_texture = tex
	q.material = mat
	p.mesh = q
	p.amount = quantidade
	p.lifetime = 3.6
	p.local_coords = true
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = raio
	p.emission_ring_inner_radius = raio * 0.55
	p.emission_ring_height = altura
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 0.25, 0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.25
	p.orbit_velocity_min = 0.18
	p.orbit_velocity_max = 0.32
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.5
	var r := Gradient.new()
	r.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	r.colors = PackedColorArray([
		Color(cor.r, cor.g, cor.b, 0.0), Color(cor.r, cor.g, cor.b, 1.0),
		Color(cor.r, cor.g, cor.b, 0.8), Color(cor.r, cor.g, cor.b, 0.0)])
	p.color_ramp = r
	p.emitting = false
	return p

# ---------------------------------------------------------------- modelo provisório

func _mat(cor: Color, rug := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = rug
	return m

func _cil(r_topo: float, r_base: float, h: float, lados: int, mat: Material, y: float) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r_topo
	c.bottom_radius = r_base
	c.height = h
	c.radial_segments = lados
	c.rings = 1
	var m := MeshInstance3D.new()
	m.mesh = c
	m.material_override = mat
	m.position = Vector3(0, y, 0)
	add_child(m)

func _montar() -> void:
	var pedra := _mat(Color(0.68, 0.66, 0.60))
	var pedra_esc := _mat(Color(0.46, 0.46, 0.43))

	_cil(1.05, 1.15, 0.55, 12, pedra_esc, -0.08)        # base
	_cil(0.75, 0.80, 0.18, 12, pedra, 0.26)             # degrau
	_cil(0.38, 0.50, 2.6, 8, pedra, 1.6)                # coluna
	_cil(0.58, 0.46, 0.22, 8, pedra_esc, 3.0)           # capitel

	# runas brilhantes nas faces da coluna
	mat_runa = StandardMaterial3D.new()
	mat_runa.albedo_color = Color(0.12, 0.14, 0.13)
	mat_runa.emission_enabled = true
	mat_runa.roughness = 0.6
	var alturas := [1.05, 1.95]
	var tams := [0.7, 0.45]
	for linha in 2:
		var y: float = alturas[linha]
		var r := 0.5 - (y - 0.3) / 2.6 * 0.12
		var apotema := r * cos(deg_to_rad(22.5)) + 0.012
		for k in 8:
			var a := deg_to_rad(k * 45.0)
			var b := MeshInstance3D.new()
			var bx := BoxMesh.new()
			bx.size = Vector3(0.07, tams[linha], 0.03)
			b.mesh = bx
			b.material_override = mat_runa
			b.position = Vector3(sin(a) * apotema, y, cos(a) * apotema)
			b.rotation.y = a
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(b)

	# cristal flutuante
	mat_cristal = StandardMaterial3D.new()
	mat_cristal.albedo_color = Color(0.9, 0.95, 0.9)
	mat_cristal.emission_enabled = true
	mat_cristal.roughness = 0.2
	var esf := SphereMesh.new()
	esf.radius = 0.5
	esf.height = 1.0
	esf.radial_segments = 4
	esf.rings = 2
	cristal = MeshInstance3D.new()
	cristal.mesh = esf
	cristal.material_override = mat_cristal
	cristal.scale = Vector3(0.32, 0.6, 0.32)
	cristal.position = Vector3(0, 3.85, 0)
	cristal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cristal)

	luz = OmniLight3D.new()
	luz.position = Vector3(0, 3.4, 0)
	luz.omni_range = 10.0
	luz.shadow_enabled = false
	add_child(luz)

	motes = criar_motes(Color(1.0, 0.85, 0.5), 36, 1.5, 3.0)
	motes.position = Vector3(0, 0.6, 0)
	add_child(motes)

	# colisão: só a coluna (a base é baixa, dá para pisar)
	var corpo := StaticBody3D.new()
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	var col := CollisionShape3D.new()
	var cil := CylinderShape3D.new()
	cil.radius = 0.55
	cil.height = 3.4
	col.shape = cil
	col.position = Vector3(0, 1.7, 0)
	corpo.add_child(col)
	add_child(corpo)

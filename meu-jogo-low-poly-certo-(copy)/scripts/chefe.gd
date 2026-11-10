extends "res://scripts/inimigo.gd"
# Colosso: chefe provisório. É a mesma lógica das sombras (herda inimigo.gd),
# só que enorme, muito mais forte e sem ser interrompido pelos golpes do jogador.

func _init() -> void:
	VIDA_MAX = 320
	vida = 320
	DANO = 20
	RAIO_DETECTAR = 24.0
	RAIO_PERDER = 45.0
	VEL_CORRIDA = 5.2
	ALCANCE_ATAQUE = 3.6
	DIST_CONTATO = 4.0
	dist_alvo = 3.0
	PREPARO = 0.95
	RECARGA = 1.6
	escala = 2.4
	peso = 6.0
	aturde_dur = 0.0
	super_armadura = true
	dur_surgir = 3.2
	cor_emissao = Color(0.6, 0.06, 0.04)

func _montar() -> void:
	super._montar()
	mat_corpo.albedo_color = Color(0.16, 0.03, 0.05)
	mat_olho.albedo_color = Color(1.0, 0.75, 0.15)
	mat_olho.emission = Color(1.0, 0.65, 0.1)
	var mat_chifre := StandardMaterial3D.new()
	mat_chifre.albedo_color = Color(0.85, 0.8, 0.7)
	mat_chifre.roughness = 0.8
	for lado in [-1.0, 1.0]:
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 0.11
		c.height = 0.65
		c.radial_segments = 6
		var m := MeshInstance3D.new()
		m.mesh = c
		m.material_override = mat_chifre
		m.position = Vector3(0.2 * lado, 2.08, 0.0)
		m.rotation_degrees = Vector3(0.0, 0.0, -28.0 * lado)
		visual.add_child(m)

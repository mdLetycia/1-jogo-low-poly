extends Node3D

const SAVE := "user://config.cfg"

@onready var login_box: VBoxContainer = $UI/Tela/LoginBox
@onready var login_edit: LineEdit = $UI/Tela/LoginBox/NomeEdit
@onready var entrar_btn: Button = $UI/Tela/LoginBox/EntrarBtn
@onready var click_label: Label = $UI/Tela/ClickLabel

var pronto_para_clicar := false

func _ready() -> void:
	# --- tamanho da UI ---
	login_box.custom_minimum_size = Vector2(500, 0)
	login_box.add_theme_constant_override("separation", 20)

	login_edit.custom_minimum_size = Vector2(0, 70)
	login_edit.add_theme_font_size_override("font_size", 36)

	entrar_btn.custom_minimum_size = Vector2(0, 70)
	entrar_btn.add_theme_font_size_override("font_size", 36)

	click_label.add_theme_font_size_override("font_size", 48)
	click_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# --- textos explicativos ---
	var titulo := Label.new()
	titulo.text = "Identifique-se"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 56)
	login_box.add_child(titulo)
	login_box.move_child(titulo, 0)

	var dica := Label.new()
	dica.text = "Seu progresso será salvo com este nome.\nO nome do personagem você escolhe depois."
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dica.add_theme_font_size_override("font_size", 24)
	dica.modulate = Color(1, 1, 1, 0.7)
	login_box.add_child(dica)
	login_box.move_child(dica, login_edit.get_index() + 1)

	login_edit.placeholder_text = "Seu apelido de jogador"
	login_edit.max_length = 20
	login_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	entrar_btn.text = "Entrar"

	entrar_btn.pressed.connect(_on_entrar)
	login_edit.text_submitted.connect(func(_t): _on_entrar())

	# --- login salvo? ---
	var cfg := ConfigFile.new()
	var login: String = ""
	if cfg.load(SAVE) == OK:
		login = cfg.get_value("conta", "login", "")
	if login != "":
		_mostrar_click(login)
	else:
		click_label.visible = false

func _on_entrar() -> void:
	var login := login_edit.text.strip_edges()
	if login.is_empty():
		return
	var cfg := ConfigFile.new()
	cfg.load(SAVE)  # preserva dados já salvos
	cfg.set_value("conta", "login", login)
	cfg.save(SAVE)
	_mostrar_click(login)

func _mostrar_click(login: String) -> void:
	login_box.visible = false
	click_label.text = "Login: %s\nClique para começar" % login
	click_label.visible = true
	await get_tree().create_timer(0.4).timeout
	pronto_para_clicar = true
	var t := create_tween().set_loops()
	t.tween_property(click_label, "modulate:a", 0.3, 1.0)
	t.tween_property(click_label, "modulate:a", 1.0, 1.0)

func _input(event: InputEvent) -> void:
	if pronto_para_clicar and event is InputEventMouseButton and event.pressed:
		pronto_para_clicar = false
		get_tree().change_scene_to_file("res://scenes/slots.tscn")

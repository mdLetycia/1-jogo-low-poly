extends Control

const IMAGEM := "res://assets/Galaxia.png"
const TOTAL := 3

var botoes: Array[Button] = []
var apagar_btns: Array[Button] = []
var apagar_todos_btn: Button
var painel_conf: Control
var texto_conf: Label
var slot_para_apagar := 0   # 0 = todos os slots

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# --- fundo ---
	if ResourceLoader.exists(IMAGEM):
		var img := TextureRect.new()
		img.texture = load(IMAGEM)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(img)
		img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var escuro := ColorRect.new()
	escuro.color = Color(0, 0, 0, 0.55)
	add_child(escuro)
	escuro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# --- conteúdo centralizado ---
	var centro := CenterContainer.new()
	add_child(centro)
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 24)
	centro.add_child(caixa)

	var titulo := Label.new()
	titulo.text = "Escolha seu slot"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 64)
	titulo.add_theme_color_override("font_outline_color", Color.BLACK)
	titulo.add_theme_constant_override("outline_size", 8)
	caixa.add_child(titulo)

	# --- um slot por linha: [botão do slot] [Apagar] ---
	for i in range(1, TOTAL + 1):
		var linha := HBoxContainer.new()
		linha.add_theme_constant_override("separation", 16)
		caixa.add_child(linha)

		var b := Button.new()
		b.custom_minimum_size = Vector2(800, 130)
		b.add_theme_font_size_override("font_size", 34)
		b.pressed.connect(_escolher.bind(i))
		linha.add_child(b)
		botoes.append(b)

		var x := Button.new()
		x.text = "Apagar"
		x.custom_minimum_size = Vector2(180, 130)
		x.add_theme_font_size_override("font_size", 28)
		x.pressed.connect(_pedir_apagar.bind(i))
		linha.add_child(x)
		apagar_btns.append(x)

	# --- rodapé: Voltar e Apagar todos ---
	var rodape := HBoxContainer.new()
	rodape.alignment = BoxContainer.ALIGNMENT_CENTER
	rodape.add_theme_constant_override("separation", 40)
	caixa.add_child(rodape)

	var voltar := Button.new()
	voltar.text = "Voltar"
	voltar.custom_minimum_size = Vector2(300, 80)
	voltar.add_theme_font_size_override("font_size", 30)
	voltar.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/titulo.tscn"))
	rodape.add_child(voltar)

	apagar_todos_btn = Button.new()
	apagar_todos_btn.text = "Apagar todos"
	apagar_todos_btn.custom_minimum_size = Vector2(300, 80)
	apagar_todos_btn.add_theme_font_size_override("font_size", 30)
	apagar_todos_btn.pressed.connect(_pedir_apagar.bind(0))
	rodape.add_child(apagar_todos_btn)

	_montar_confirmacao()
	_atualizar()

# ---------------------------------------------------------------- confirmação

func _montar_confirmacao() -> void:
	painel_conf = Control.new()
	painel_conf.visible = false
	add_child(painel_conf)
	painel_conf.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# fundo escuro (também bloqueia cliques nos botões de trás)
	var sombra := ColorRect.new()
	sombra.color = Color(0, 0, 0, 0.75)
	painel_conf.add_child(sombra)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var centro := CenterContainer.new()
	painel_conf.add_child(centro)
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var fundo := PanelContainer.new()
	centro.add_child(fundo)

	var margem := MarginContainer.new()
	margem.add_theme_constant_override("margin_left", 60)
	margem.add_theme_constant_override("margin_right", 60)
	margem.add_theme_constant_override("margin_top", 50)
	margem.add_theme_constant_override("margin_bottom", 50)
	fundo.add_child(margem)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 40)
	margem.add_child(v)

	texto_conf = Label.new()
	texto_conf.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_conf.add_theme_font_size_override("font_size", 40)
	v.add_child(texto_conf)

	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 40)
	v.add_child(h)

	var cancelar := Button.new()
	cancelar.text = "Cancelar"
	cancelar.custom_minimum_size = Vector2(280, 90)
	cancelar.add_theme_font_size_override("font_size", 34)
	cancelar.pressed.connect(func(): painel_conf.visible = false)
	h.add_child(cancelar)

	var ok := Button.new()
	ok.text = "Apagar"
	ok.custom_minimum_size = Vector2(280, 90)
	ok.add_theme_font_size_override("font_size", 34)
	ok.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	ok.pressed.connect(_apagar_confirmado)
	h.add_child(ok)

func _pedir_apagar(n: int) -> void:
	slot_para_apagar = n
	if n == 0:
		texto_conf.text = "Apagar TODOS os saves?\nIsso não pode ser desfeito."
	else:
		texto_conf.text = "Apagar o Slot %d?\nIsso não pode ser desfeito." % n
	painel_conf.visible = true

func _apagar_confirmado() -> void:
	if slot_para_apagar == 0:
		for i in range(1, TOTAL + 1):
			Global.apagar_slot(i)
	else:
		Global.apagar_slot(slot_para_apagar)
	painel_conf.visible = false
	_atualizar()

# ---------------------------------------------------------------- slots

func _atualizar() -> void:
	var algum := false
	for i in TOTAL:
		var n := i + 1
		botoes[i].text = _texto_slot(n)
		apagar_btns[i].disabled = not Global.slot_existe(n)
		if Global.slot_existe(n):
			algum = true
	apagar_todos_btn.disabled = not algum

func _texto_slot(n: int) -> String:
	if not Global.slot_existe(n):
		return "Slot %d\nVazio  -  Novo jogo" % n
	var d: Dictionary = Global.ler_slot(n)
	var nome: String = str(d.get("nome", ""))
	if nome == "":
		nome = "Aventureiro"
	var nivel: int = int(d.get("nivel", 1))
	var ultimo: String = str(d.get("ultimo_save", "-"))
	return "Slot %d  -  %s  (Nível %d)\nÚltimo save: %s" % [n, nome, nivel, ultimo]

func _escolher(n: int) -> void:
	if Global.slot_existe(n):
		Global.carregar_jogo(n)
	else:
		Global.novo_jogo(n)

	# ATALHO DE TESTE: segurar Shift refaz as cutscenes (remova no final)
	if Input.is_key_pressed(KEY_SHIFT):
		Global.dados.erase("corpo")
		Global.dados.erase("cutscene2_vista")
		Global.dados.erase("cutscene3_vista")
		Global.dados.erase("cutscene4_vista")

	if Global.dados.get("corpo", "") == "":
		Global.ir_para("res://scenes/cutscene_1.tscn")
	elif not Global.dados.get("cutscene2_vista", false):
		Global.ir_para("res://scenes/cutscene_2.tscn")
	elif not Global.dados.get("cutscene3_vista", false):
		Global.ir_para("res://scenes/cutscene_3.tscn")
	elif not Global.dados.get("cutscene4_vista", false):
		Global.ir_para("res://scenes/cutscene_4.tscn")
	else:
		Global.ir_para("res://scenes/mundo.tscn")

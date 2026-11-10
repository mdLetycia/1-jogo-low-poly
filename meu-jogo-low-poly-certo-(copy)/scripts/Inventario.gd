extends CanvasLayer
# Inventário: ícone da mochila no HUD + painel com grade de slots.
# Os itens ficam salvos em Global.dados["inventario"] ({id: quantidade}).
# Para criar um item novo, é só acrescentar uma linha em ITENS (e um desenho em _desenhar_icone).

signal aberto_mudou(aberto: bool)
signal item_selecionado(id: String)
signal consumido(id: String)

const ITENS := {
	"prato_comida": {
		"nome": "Prato de comida",
		"tipo": "Material",
		"cura": 25,
		"desc": "Uma refeição quentinha, feita com carinho. Recupera um pouco de vida.",
	},
}
const COLUNAS := 5
const SLOTS := 15

var aberto := false
var selecionado := ""
var icone_btn: Button
var painel: Control
var grade: GridContainer
var det_nome: Label
var det_tipo: Label
var det_desc: Label
var btn_consumir: Button
var slots := {}                       # id -> Button

func _ready() -> void:
	layer = 6
	_montar()
	_reconstruir()

func _inv() -> Dictionary:
	if not Global.dados.has("inventario") or not (Global.dados["inventario"] is Dictionary):
		Global.dados["inventario"] = {}
	return Global.dados["inventario"]

func quantidade(id: String) -> int:
	return int(_inv().get(id, 0))

func adicionar(id: String, n := 1) -> void:
	_inv()[id] = quantidade(id) + n
	_reconstruir()

func mostrar_icone(v: bool) -> void:
	icone_btn.visible = v

func get_icone() -> Control:
	return icone_btn

func get_slot(id: String) -> Control:
	return slots.get(id)

func get_btn_consumir() -> Control:
	return btn_consumir

func abrir() -> void:
	if aberto:
		return
	aberto = true
	painel.visible = true
	aberto_mudou.emit(true)


func fechar() -> void:
	if not aberto:
		return
	aberto = false
	painel.visible = false
	aberto_mudou.emit(false)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I and icone_btn.visible:
			if aberto:
				fechar()
			else:
				abrir()
		elif event.keycode == KEY_ESCAPE and aberto:
			fechar()

# ---------------------------------------------------------------- interface

func _montar() -> void:
	icone_btn = Button.new()
	icone_btn.text = "Mochila (I)"
	icone_btn.add_theme_font_size_override("font_size", 26)
	icone_btn.visible = false
	icone_btn.anchor_left = 1.0
	icone_btn.anchor_right = 1.0
	icone_btn.offset_left = -230
	icone_btn.offset_right = -24
	icone_btn.offset_top = 24
	icone_btn.offset_bottom = 96
	icone_btn.pressed.connect(func(): if aberto: fechar() else: abrir())
	add_child(icone_btn)

	painel = Control.new()
	painel.visible = false
	add_child(painel)
	painel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sombra := ColorRect.new()
	sombra.color = Color(0, 0, 0, 0.55)
	painel.add_child(sombra)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var caixa := PanelContainer.new()
	painel.add_child(caixa)
	caixa.anchor_left = 0.5
	caixa.anchor_right = 0.5
	caixa.anchor_top = 0.5
	caixa.anchor_bottom = 0.5
	caixa.offset_left = -520
	caixa.offset_right = 520
	caixa.offset_top = -300
	caixa.offset_bottom = 300
	var est := StyleBoxFlat.new()
	est.bg_color = Color(0.07, 0.08, 0.15, 0.97)
	est.border_color = Color(0.75, 0.8, 1.0)
	est.set_border_width_all(3)
	est.set_corner_radius_all(20)
	est.set_content_margin_all(24)
	caixa.add_theme_stylebox_override("panel", est)

	var raiz := VBoxContainer.new()
	raiz.add_theme_constant_override("separation", 14)
	caixa.add_child(raiz)
	var topo := HBoxContainer.new()
	raiz.add_child(topo)
	var tit := Label.new()
	tit.text = "Inventário"
	tit.add_theme_font_size_override("font_size", 40)
	tit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(tit)
	var x := Button.new()
	x.text = "X"
	x.add_theme_font_size_override("font_size", 30)
	x.custom_minimum_size = Vector2(64, 56)
	x.pressed.connect(fechar)
	topo.add_child(x)

	var meio := HBoxContainer.new()
	meio.add_theme_constant_override("separation", 24)
	meio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	raiz.add_child(meio)
	grade = GridContainer.new()
	grade.columns = COLUNAS
	grade.add_theme_constant_override("h_separation", 10)
	grade.add_theme_constant_override("v_separation", 10)
	meio.add_child(grade)

	var det := VBoxContainer.new()
	det.add_theme_constant_override("separation", 12)
	det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meio.add_child(det)
	det_nome = Label.new()
	det_nome.add_theme_font_size_override("font_size", 36)
	det.add_child(det_nome)
	det_tipo = Label.new()
	det_tipo.add_theme_font_size_override("font_size", 24)
	det_tipo.modulate = Color(0.7, 0.8, 1.0)
	det.add_child(det_tipo)
	det_desc = Label.new()
	det_desc.add_theme_font_size_override("font_size", 28)
	det_desc.custom_minimum_size = Vector2(300, 0)
	det.add_child(det_desc)
	btn_consumir = Button.new()
	btn_consumir.text = "Consumir"
	btn_consumir.add_theme_font_size_override("font_size", 34)
	btn_consumir.custom_minimum_size = Vector2(0, 72)
	btn_consumir.visible = false
	btn_consumir.pressed.connect(_consumir)
	det.add_child(btn_consumir)

func _reconstruir() -> void:
	for c in grade.get_children():
		c.queue_free()
	slots.clear()
	var ids: Array = []
	for id in _inv():
		if quantidade(id) > 0 and ITENS.has(id):
			ids.append(id)
	for i in SLOTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(112, 112)
		grade.add_child(b)
		if i < ids.size():
			var id: String = ids[i]
			slots[id] = b
			var ic := Control.new()
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			ic.draw.connect(_desenhar_icone.bind(ic, id))
			b.add_child(ic)
			var q := Label.new()
			q.text = "x%d" % quantidade(id)
			q.add_theme_font_size_override("font_size", 24)
			q.add_theme_color_override("font_outline_color", Color.BLACK)
			q.add_theme_constant_override("outline_size", 5)
			q.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ic.add_child(q)
			q.position = Vector2(66, 80)
			b.pressed.connect(_selecionar.bind(id))
	if selecionado == "" or quantidade(selecionado) <= 0:
		selecionado = ""
		det_nome.text = ""
		det_tipo.text = ""
		det_desc.text = "Selecione um item."
		btn_consumir.visible = false

func _desenhar_icone(c: Control, id: String) -> void:
	var m := c.size * 0.5
	if id == "prato_comida":
		c.draw_circle(m + Vector2(0, 6), 40.0, Color(0.92, 0.92, 0.95))
		c.draw_circle(m + Vector2(0, 6), 30.0, Color(0.80, 0.82, 0.88))
		c.draw_circle(m + Vector2(-9, 2), 13.0, Color(0.78, 0.45, 0.2))
		c.draw_circle(m + Vector2(10, 8), 11.0, Color(0.35, 0.65, 0.25))
		c.draw_circle(m + Vector2(2, 16), 8.0, Color(0.85, 0.2, 0.2))

func _selecionar(id: String) -> void:
	selecionado = id
	var d: Dictionary = ITENS[id]
	det_nome.text = d["nome"]
	det_tipo.text = d["tipo"]
	det_desc.text = d["desc"]
	btn_consumir.visible = true
	item_selecionado.emit(id)

func _consumir() -> void:
	if selecionado == "" or quantidade(selecionado) <= 0:
		return
	var id := selecionado
	_inv()[id] = quantidade(id) - 1
	_reconstruir()
	consumido.emit(id)

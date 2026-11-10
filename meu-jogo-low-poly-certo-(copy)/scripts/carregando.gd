extends Control

const IMAGEM := "res://assets/Galaxia.png"
const TEMPO_MINIMO := 2.0     # tempo mínimo da tela de loading
const TEMPO_LIMITE := 12.0    # passou disso, tenta abrir a cena direto

const DICAS := [
	"Dica: explore cada canto do mapa, há tesouros escondidos.",
	"Dica: descanse perto de fogueiras para recuperar energia.",
	"Dica: derrote inimigos para ganhar experiência.",
	"Dica: converse com os moradores para descobrir novas missões.",
	"Dica: o clima e a hora do dia mudam o que você encontra.",
]

var dica: Label
var barra: ProgressBar
var caminho := ""
var progresso: Array = []
var tempo := 0.0
var ativo := true

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
	else:
		var cor := ColorRect.new()
		cor.color = Color(0.05, 0.05, 0.15)
		add_child(cor)
		cor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# --- faixa escura embaixo ---
	var faixa := ColorRect.new()
	faixa.color = Color(0, 0, 0, 0.65)
	add_child(faixa)
	_ancorar_embaixo(faixa, 0, 0, -220, 0)

	# --- texto da dica ---
	dica = Label.new()
	dica.text = DICAS.pick_random()
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dica.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dica.add_theme_font_size_override("font_size", 36)
	dica.add_theme_color_override("font_color", Color.WHITE)
	dica.add_theme_color_override("font_outline_color", Color.BLACK)
	dica.add_theme_constant_override("outline_size", 8)
	add_child(dica)
	_ancorar_embaixo(dica, 80, -80, -190, -80)

	# --- barra ---
	barra = ProgressBar.new()
	barra.min_value = 0.0
	barra.max_value = 100.0
	barra.value = 0.0
	barra.show_percentage = false
	add_child(barra)
	_ancorar_embaixo(barra, 80, -80, -60, -44)

	# --- começa a carregar ---
	caminho = Global.destino
	if caminho == "":
		caminho = "res://scenes/mundo.tscn"   # para testar esta cena sozinha (F6)

	print("Carregando: ", caminho, " | existe: ", ResourceLoader.exists(caminho))

	if not ResourceLoader.exists(caminho):
		_erro("o arquivo não existe.\nConfira o nome e a pasta da cena.")
		return

	ResourceLoader.load_threaded_request(caminho)

func _ancorar_embaixo(c: Control, esq: float, dir: float, topo: float, base: float) -> void:
	c.anchor_left = 0.0
	c.anchor_right = 1.0
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = esq
	c.offset_right = dir
	c.offset_top = topo
	c.offset_bottom = base

# mostra o erro na tela (em vermelho) em vez de travar sem avisar
func _erro(msg: String) -> void:
	ativo = false
	dica.text = "Erro ao carregar:\n" + caminho + "\n" + msg
	dica.add_theme_font_size_override("font_size", 28)
	dica.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	push_error("Falha ao carregar " + caminho + ": " + msg)

# plano B: abre a cena sem o carregamento em segundo plano
# (se a cena tiver erro de script, a aba Saída mostra a linha do erro)
func _abrir_direto() -> void:
	ativo = false
	var erro := get_tree().change_scene_to_file(caminho)
	if erro != OK:
		_erro("não foi possível abrir (código %d).\nAbra a cena no editor, aperte F6 e veja a aba Saída." % erro)

func _process(delta: float) -> void:
	if not ativo:
		return
	tempo += delta
	var status := ResourceLoader.load_threaded_get_status(caminho, progresso)

	if status == ResourceLoader.THREAD_LOAD_FAILED \
			or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_abrir_direto()
		return

	if tempo > TEMPO_LIMITE and status != ResourceLoader.THREAD_LOAD_LOADED:
		_abrir_direto()
		return

	var alvo := 0.0
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		alvo = 100.0
	elif progresso.size() > 0:
		alvo = progresso[0] * 100.0

	barra.value = move_toward(barra.value, alvo, delta * 60.0)

	if status == ResourceLoader.THREAD_LOAD_LOADED \
			and barra.value >= 100.0 and tempo >= TEMPO_MINIMO:
		ativo = false
		var cena := ResourceLoader.load_threaded_get(caminho) as PackedScene
		if cena == null:
			_abrir_direto()
			return
		var erro := get_tree().change_scene_to_packed(cena)
		if erro != OK:
			_erro("falha ao trocar de cena (código %d)." % erro)

# atalho de desenvolvimento: Esc fecha o jogo (remova no final)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()

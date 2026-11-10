extends Node

var destino := ""
var slot_atual := 0
var dados: Dictionary = {}

func ir_para(caminho: String) -> void:
	destino = caminho
	get_tree().change_scene_to_file("res://scenes/carregando.tscn")

# --- sistema de slots ---

func caminho_slot(n: int) -> String:
	return "user://save_%d.json" % n

func slot_existe(n: int) -> bool:
	return FileAccess.file_exists(caminho_slot(n))

func ler_slot(n: int) -> Dictionary:
	if not slot_existe(n):
		return {}
	var f := FileAccess.open(caminho_slot(n), FileAccess.READ)
	if f == null:
		return {}
	var r = JSON.parse_string(f.get_as_text())
	return r if r is Dictionary else {}

func salvar() -> void:
	if slot_atual == 0:
		return
	dados["ultimo_save"] = Time.get_datetime_string_from_system(false, true)
	var f := FileAccess.open(caminho_slot(slot_atual), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(dados, "\t"))

func novo_jogo(n: int) -> void:
	slot_atual = n
	dados = {
		"nome": "",
		"nivel": 1,
		"criado_em": Time.get_datetime_string_from_system(false, true),
		"ultimo_save": "",
	}
	salvar()

func carregar_jogo(n: int) -> void:
	slot_atual = n
	dados = ler_slot(n)

func apagar_slot(n: int) -> void:
	if slot_existe(n):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho_slot(n)))

# --- pilares da Deusa (pontos de renascimento) ---

func pilar_ativado(id: String) -> bool:
	var p = dados.get("pilares", {})
	return p is Dictionary and p.has(id)

# guarda o pilar como ativado e o torna o ponto de renascimento atual
func ativar_pilar(id: String, ponto_renascer: Vector3) -> void:
	var p = dados.get("pilares", {})
	if not (p is Dictionary):
		p = {}
	p[id] = [snappedf(ponto_renascer.x, 0.01), snappedf(ponto_renascer.y, 0.01), snappedf(ponto_renascer.z, 0.01)]
	dados["pilares"] = p
	dados["spawn_id"] = id
	salvar()

# ponto de renascimento atual (ou o padrão, se nenhum pilar foi ativado)
func posicao_spawn(padrao: Vector3) -> Vector3:
	var p = dados.get("pilares", {})
	var id := str(dados.get("spawn_id", ""))
	if p is Dictionary and p.has(id):
		var a = p[id]
		if a is Array and a.size() == 3:
			return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return padrao

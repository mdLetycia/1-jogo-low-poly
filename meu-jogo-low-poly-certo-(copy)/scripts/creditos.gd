extends Control

@onready var texto: Label = $Texto

var iniciado := false

func _ready() -> void:
	texto.modulate.a = 0.0
	_tocar_creditos()

func _tocar_creditos() -> void:
	var tween := create_tween()
	tween.tween_property(texto, "modulate:a", 1.0,1.5)
	tween.tween_interval(2.5)
	tween.tween_property(texto, "modulate:a", 0.0,1.5)
	tween.tween_interval(0.5)
	tween.tween_callback(_ir_para_titulo)
	
func _ir_para_titulo() -> void:
	get_tree().change_scene_to_file("res://scenes/titulo.tscn")

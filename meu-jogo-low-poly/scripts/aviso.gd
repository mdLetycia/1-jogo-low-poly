extends Control

@onready var texto: Label = $Texto

var pulado := false

func _ready() -> void:
	texto.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(texto, "modulate:a", 1.0,1.0)
	tween.tween_interval(5.0)
	tween.tween_property(texto, "modulate:a", 0.0, 1.0)
	tween.tween_interval(0.5)
	tween.tween_callback(_ir_para_creditos)
	
func _ir_para_creditos() -> void:
	if pulado:
		return
	pulado = true
	get_tree().change_scene_to_file("res://scenes/creditos.tscn")

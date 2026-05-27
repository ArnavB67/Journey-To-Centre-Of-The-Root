extends Control

const LEVEL1 = preload("uid://b7fbbnbj0p6fo")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_join_pressed() -> void:
	var Lvl1=LEVEL1.instantiate()
	get_tree().current_scene.add_child(Lvl1)
	hide()


func _on_quit_pressed() -> void:
	get_tree().quit()

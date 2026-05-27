extends Control

const LEVEL1 = preload("uid://b7fbbnbj0p6fo")
const WARRIOR = preload("uid://dm6l1a5i5eenu")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if OS.has_feature('server'):
		HighLevelNetworkHandler.CreateServer()
		AddLevel()
		hide()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_join_pressed() -> void:
	HighLevelNetworkHandler.CreateClient()
	AddLevel()
	hide()

func AddLevel():
	var Lvl1=LEVEL1.instantiate()
	get_tree().current_scene.add_child.call_deferred(Lvl1)

func _on_quit_pressed() -> void:
	get_tree().quit()

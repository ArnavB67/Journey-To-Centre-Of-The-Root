extends Control

const LEVEL1 = preload("uid://b7fbbnbj0p6fo")
const WARRIOR = preload("uid://dm6l1a5i5eenu")
@onready var join_web_rtc: Button = %JoinWebRtc
@onready var lobby_id_input: LineEdit = $PanelContainer/MarginContainer/HBoxContainer/WebRtc/LobbyIdInput
@onready var v_box_container: VBoxContainer = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer
@onready var web_rtc: VBoxContainer = %WebRtc


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if HighLevelNetworkHandler.TubeEnabled:
		v_box_container.hide()
	else:
		web_rtc.hide()
	join_web_rtc.disabled=true
	HighLevelNetworkHandler.Tubeclient.error_raised.connect(OnErrorRaised)
	if OS.has_feature('server'):
		HighLevelNetworkHandler.CreateServer()
		await get_tree().create_timer(0.1).timeout
		AddLevel()
		hide()
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_join_pressed() -> void:
	HighLevelNetworkHandler.CreateClient()
	AddLevel()


func AddLevel():
	var Lvl1=LEVEL1.instantiate()
	get_tree().current_scene.add_child(Lvl1)
	hide()

func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_lobby_id_input_text_changed(new_text: String) -> void:
	if new_text!='':
		join_web_rtc.disabled=false

func _on_username_input_text_changed(new_text: String) -> void:
	Global.Username=new_text


func _on_join_web_rtc_pressed() -> void:
	join_web_rtc.disabled=true
	HighLevelNetworkHandler.TubeJoin(lobby_id_input.text)
	multiplayer.connected_to_server.connect(AddLevel)


func _on_quit_web_rtc_pressed() -> void:
	get_tree().quit()


func _on_host_server_pressed() -> void:
	HighLevelNetworkHandler.TubeCreate()
	AddLevel()
	

func OnErrorRaised(_Code,_Message):
	lobby_id_input.text=''
	join_web_rtc.add_theme_color_override(&"font_disabled_color",Color.DARK_RED)
	join_web_rtc.disabled=true
	HighLevelNetworkHandler.CleanUpSignals()

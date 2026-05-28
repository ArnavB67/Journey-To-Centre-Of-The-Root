extends Node

const IpAddress:String="localhost"
const Port:int=42069
var peer:ENetMultiplayerPeer
const WARRIOR = preload("uid://dm6l1a5i5eenu")
const TUBE_CONTEXT = preload("uid://clf0g5oy74te3")
var Tubeclient:=TubeClient.new()
var TubeEnabled=true

func _ready() -> void:
	if TubeEnabled:
		Tubeclient.context=TUBE_CONTEXT
		get_tree().root.add_child.call_deferred(Tubeclient)

func TubeCreate():
	multiplayer.peer_connected.connect(AddPlayer)
	multiplayer.peer_disconnected.connect(RemovePlayer)
	Tubeclient.create_session()
	AddPlayer(1)

func TubeJoin(SessionId:String):
	multiplayer.peer_connected.connect(AddPlayer)
	multiplayer.peer_disconnected.connect(RemovePlayer)
	multiplayer.connected_to_server.connect(OnConnectedToServer)
	Tubeclient.join_session(SessionId)
	

func CreateServer():
	peer=ENetMultiplayerPeer.new()
	peer.create_server(Port)
	multiplayer.multiplayer_peer=peer
	multiplayer.peer_connected.connect(AddPlayer)
	multiplayer.peer_disconnected.connect(RemovePlayer)

func CreateClient():
	peer=ENetMultiplayerPeer.new()
	peer.create_client(IpAddress,Port)
	multiplayer.multiplayer_peer=peer
	multiplayer.peer_connected.connect(AddPlayer)
	multiplayer.peer_disconnected.connect(RemovePlayer)
	multiplayer.connected_to_server.connect(OnConnectedToServer)

func AddPlayer(PeerId:int):
	if PeerId==1 and multiplayer.multiplayer_peer is ENetMultiplayerPeer:return
	var NewWarrior=WARRIOR.instantiate()
	NewWarrior.name=str(PeerId)
	var RandomX=randi_range(50,150)
	NewWarrior.position=Vector2(RandomX,350)
	get_tree().current_scene.add_child(NewWarrior,true)

func OnConnectedToServer():
	AddPlayer(multiplayer.get_unique_id())

func RemovePlayer(PeerId):
	if PeerId==1:
		LeaveServer()
	
	var Players:Array[Node]=get_tree().get_nodes_in_group('Players')
	var PlayerToRemove=Players.find_custom(func(item):return item.name==str(PeerId))
	if PlayerToRemove!=-1:
		Players[PlayerToRemove].queue_free()

func LeaveServer():
	if TubeEnabled:
		Tubeclient.leave_session()
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer=null
	CleanUpSignals()
	get_tree().reload_current_scene()

func CleanUpSignals():
	multiplayer.peer_connected.disconnect(AddPlayer)
	multiplayer.peer_disconnected.disconnect(RemovePlayer)
	multiplayer.connected_to_server.disconnect(OnConnectedToServer)
	
func _exit_tree() -> void:
	if TubeEnabled:
		Tubeclient.leave_session()

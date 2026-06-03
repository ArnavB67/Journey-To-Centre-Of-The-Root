extends Node

const IpAddress:String="localhost"
const Port:int=42069
var peer:ENetMultiplayerPeer
const WARRIOR = preload("uid://dm6l1a5i5eenu")
const TUBE_CONTEXT = preload("uid://clf0g5oy74te3")
var Tubeclient:=TubeClient.new()
var TubeEnabled=true
const WIZARD = preload("uid://cduhud2k2tsa3")


func _ready() -> void:
	if TubeEnabled:
		Tubeclient.context=TUBE_CONTEXT
		get_tree().root.add_child.call_deferred(Tubeclient)

func TubeCreate():
	multiplayer.peer_connected.connect(SendPlayerData)
	multiplayer.peer_disconnected.connect(RemovePlayer)
	Tubeclient.create_session()
	GetPlayer(1,Global.MyCharacter,Vector2(100,350))

func TubeJoin(SessionId:String):
	multiplayer.peer_connected.connect(SendPlayerData)
	multiplayer.peer_disconnected.connect(RemovePlayer)
	multiplayer.connected_to_server.connect(OnConnectedToServer)
	Tubeclient.join_session(SessionId)
	

func CreateServer():
	peer=ENetMultiplayerPeer.new()
	peer.create_server(Port)
	multiplayer.multiplayer_peer=peer
	multiplayer.peer_connected.connect(SendPlayerData)
	multiplayer.peer_disconnected.connect(RemovePlayer)

func CreateClient():
	peer=ENetMultiplayerPeer.new()
	peer.create_client(IpAddress,Port)
	multiplayer.multiplayer_peer=peer
	multiplayer.peer_connected.connect(SendPlayerData)
	multiplayer.peer_disconnected.connect(RemovePlayer)
	multiplayer.connected_to_server.connect(OnConnectedToServer)

func SendPlayerData(PeerId:int):
	var CurrentPlayerID=multiplayer.get_unique_id()
	if CurrentPlayerID==1 and multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		return
	var CurrentPlayerPosition=Vector2(100,350)
	var CurrentPlayerNode=get_tree().current_scene.get_node_or_null(str(CurrentPlayerID))
	if CurrentPlayerNode:
		CurrentPlayerPosition=CurrentPlayerNode.position
	
	rpc_id(PeerId,"GetPlayer",CurrentPlayerID,Global.MyCharacter,CurrentPlayerPosition)

		
func OnConnectedToServer():
	var JoinedPlayerId=multiplayer.get_unique_id()
	var RandPosition=Vector2(randi_range(50,150),350)
	rpc("GetPlayer",JoinedPlayerId,Global.MyCharacter,RandPosition)

@rpc("any_peer","call_local")
func GetPlayer(PeerId,Character,SpawnPosition):
	if get_tree().current_scene.has_node(str(PeerId)):
		return
	var NewPlayer=null
	if Character=="Warrior":
		NewPlayer=WARRIOR.instantiate()
	if Character=="Wizard":
		NewPlayer=WIZARD.instantiate()
	
	if NewPlayer:
		NewPlayer.name=str(PeerId)
		NewPlayer.position=SpawnPosition
		get_tree().current_scene.add_child(NewPlayer,true)

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
	multiplayer.peer_connected.disconnect(SendPlayerData)
	multiplayer.peer_disconnected.disconnect(RemovePlayer)
	multiplayer.connected_to_server.disconnect(OnConnectedToServer)
	
func _exit_tree() -> void:
	if TubeEnabled:
		Tubeclient.leave_session()

@rpc("any_peer","call_local")
func ChangeCharacter(PeerId,NewCharacter):
	var CharacterToChange=get_tree().current_scene.get_node_or_null(str(PeerId))
	var SpawnPosition
	if CharacterToChange:
		SpawnPosition=CharacterToChange.position
		CharacterToChange.name="Replacing"+str(PeerId)
		CharacterToChange.queue_free()
	SpawnReplaced(PeerId,NewCharacter,SpawnPosition)

func SpawnReplaced(PeerId,NewCharacter,SpawnPosition):
	var NewPlayer
	if NewCharacter=="Warrior":
		NewPlayer=WARRIOR.instantiate()
	if NewCharacter=="Wizard":
		NewPlayer=WIZARD.instantiate()
	if NewPlayer:
		NewPlayer.name=str(PeerId)
		NewPlayer.position=SpawnPosition
		get_tree().current_scene.add_child(NewPlayer,true)

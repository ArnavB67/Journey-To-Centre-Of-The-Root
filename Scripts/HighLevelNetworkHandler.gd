extends Node

const IpAddress:String="localhost"
const Port:int=42069
var peer:ENetMultiplayerPeer

func CreateServer():
	peer=ENetMultiplayerPeer.new()
	peer.create_server(Port)
	multiplayer.multiplayer_peer=peer

func CreateClient():
	peer=ENetMultiplayerPeer.new()
	peer.create_client(IpAddress,Port)
	multiplayer.multiplayer_peer=peer

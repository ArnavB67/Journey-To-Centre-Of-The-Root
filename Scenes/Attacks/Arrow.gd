extends Area2D

var AttackSpeed=500
@export var AttackDirection=Vector2.RIGHT
var InitialPosition
var Anchored=false

func _ready() -> void:
	InitialPosition=global_position
	get_tree().create_timer(8.0).timeout.connect(queue_free)

func _process(delta: float) -> void:
	if not Anchored:
		position+=AttackSpeed*delta*AttackDirection



func _on_body_entered(body: Node2D) -> void:
	if is_multiplayer_authority():
		if body.is_in_group("Players"):
			body.GiveDamage.rpc(body.get_path(),10)
	queue_free()
	
	
	
	

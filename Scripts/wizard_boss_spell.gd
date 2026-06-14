extends Area2D

var AttackSpeed=400
@export var Direction=Vector2.RIGHT

func _ready() -> void:
	get_tree().create_timer(3.0).timeout.connect(queue_free)

func _process(delta: float) -> void:
	position+=AttackSpeed*delta*Direction



func _on_body_entered(body: Node2D) -> void:
	if is_multiplayer_authority():
		if body.is_in_group("Players"):
			body.GiveDamage.rpc(body.get_path(),25)
	queue_free()

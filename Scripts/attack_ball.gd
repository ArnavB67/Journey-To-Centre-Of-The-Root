extends Area2D

var AttackSpeed=100
var AttackDirection=1

func _process(delta: float) -> void:
	position.x+=AttackSpeed*delta*AttackDirection



func _on_body_entered(body: Node2D) -> void:
	pass # Replace with function body.

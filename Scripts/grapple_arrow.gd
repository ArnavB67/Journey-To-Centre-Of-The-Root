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
	if Anchored:
		return
	if not body.is_in_group("Players"):
		Anchored=true
		CreateRope()
	
func CreateRope():
	var Rope=StaticBody2D.new()
	Rope.collision_layer=2
	var CollisionShape=CollisionShape2D.new()
	var Segment=SegmentShape2D.new()
	Segment.a=to_local(InitialPosition)
	Segment.b=Vector2.ZERO
	CollisionShape.shape=Segment
	Rope.add_child(CollisionShape)
	var VisualRope=Line2D.new()
	VisualRope.add_point(Segment.a)
	VisualRope.add_point(Segment.b)
	VisualRope.width=8
	VisualRope.default_color=Color(0.6,0.4,0.2,0.9)
	Rope.add_child(VisualRope)
	add_child(Rope)
	
	
	
	
	
	
	
	
	

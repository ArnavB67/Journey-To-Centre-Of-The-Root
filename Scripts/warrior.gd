extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
@onready var camera_2d: Camera2D = %Camera2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	camera_2d.make_current()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
		animated_sprite_2d.play(&"Jump")

	if Input.is_action_just_pressed(&"jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis(&"left", &"right")
	if direction>0:
		animated_sprite_2d.play(&"Run")
		animated_sprite_2d.flip_h=false
	if direction<0:
		animated_sprite_2d.play(&"Run")
		animated_sprite_2d.flip_h=true
	if direction==0:
		animated_sprite_2d.play(&"Idle")
	if direction:
		velocity.x = direction * SPEED
		
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

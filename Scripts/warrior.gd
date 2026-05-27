extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
@onready var camera_2d: Camera2D = %Camera2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

func _enter_tree() -> void:
	set_multiplayer_authority(int(name))

func _ready() -> void:
	add_to_group('Players')

	camera_2d.make_current()
	if not is_multiplayer_authority():
		set_process(false)
		set_physics_process(false)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed(&"jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis(&"left", &"right")

	if not is_on_floor():
		animated_sprite_2d.play(&"Jump")
	if direction!=0:
		animated_sprite_2d.flip_h=direction<0
		animated_sprite_2d.play(&"Run")
	if direction==0:
		animated_sprite_2d.play(&"Idle")
	if direction:
		velocity.x = direction * SPEED
		
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

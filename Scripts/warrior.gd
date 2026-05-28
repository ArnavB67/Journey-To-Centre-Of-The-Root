extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
@onready var camera_2d: Camera2D = %Camera2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
var Attacking=false
@onready var attack_animation_timer: Timer = $AttackAnimationTimer

func _enter_tree() -> void:
	set_multiplayer_authority(int(name))

func _ready() -> void:
	add_to_group('Players')
	if not is_multiplayer_authority():
		set_process(false)
		set_physics_process(false)
	if is_multiplayer_authority():
		camera_2d.make_current()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed(&"Attack1") and is_on_floor():
		Attacking=true
		attack_animation_timer.start()
		PlayAttackAnimation.rpc(&"Attack1")
		
	if Input.is_action_just_pressed(&"Attack2") and is_on_floor():
		Attacking=true
		PlayAttackAnimation.rpc(&"Attack2")
		attack_animation_timer.start()

@rpc("authority","call_local","reliable")
func PlayAttackAnimation(AnimationName):
	animated_sprite_2d.play(AnimationName)
	

func _physics_process(delta: float) -> void:
	if not Attacking:
			if not is_on_floor():
				velocity += get_gravity() * delta

			if Input.is_action_just_pressed(&"jump") and is_on_floor():
				velocity.y = JUMP_VELOCITY

			var direction := Input.get_axis(&"left", &"right")

			if not is_on_floor():
				PlayAttackAnimation.rpc(&"Jump")
				if direction!=0:
					animated_sprite_2d.flip_h=direction<0
			if is_on_floor():
				if direction!=0:
					animated_sprite_2d.flip_h=direction<0
					PlayAttackAnimation.rpc(&"Run")
				if direction==0:
					PlayAttackAnimation.rpc(&"Idle")
				
			if direction:
				velocity.x = direction * SPEED
				
			else:
				velocity.x = move_toward(velocity.x, 0, SPEED)

			move_and_slide()


func _on_attack_animation_timer_timeout() -> void:
	Attacking=false

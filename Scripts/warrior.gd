extends CharacterBody2D

@export var Dead=false
@export var Health=100
const SPEED = 300.0
const JUMP_VELOCITY = -400.0
@onready var camera_2d: Camera2D = %Camera2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
var Attacking=false
@onready var attack_animation_timer: Timer = $AttackAnimationTimer
@onready var lobby_id: Label = %LobbyId
@onready var health_label: Label = %HealthLabel
@onready var attack_1_collision_shape: CollisionShape2D = $Area2D/Attack1CollisionShape
@onready var death_animation_timer: Timer = $DeathAnimationTimer
var CurrentSpectating=0

func _enter_tree() -> void:
	set_multiplayer_authority(int(name))

func _ready() -> void:
	add_to_group('Players')
	if not is_multiplayer_authority():
		set_process(false)
		set_physics_process(false)
	if is_multiplayer_authority():
		if Global.Username:
			$Username.text=Global.Username
		camera_2d.make_current()
		lobby_id.text="Lobby Code: "+HighLevelNetworkHandler.Tubeclient.session_id

func _process(delta: float) -> void:
	if is_multiplayer_authority():
		if Dead==true:
			PlayAttackAnimation.rpc("Death")
			if Input.is_action_just_pressed(&"ChangeSpectator"):
				ChangeSpectator()
			return

		health_label.text=str(Health)
		if Input.is_action_just_pressed(&"Attack1") and is_on_floor() and not Dead:
			Attacking=true
			attack_1_collision_shape.disabled=false
			attack_animation_timer.start()
			PlayAttackAnimation.rpc(&"Attack1")
			
		if Input.is_action_just_pressed(&"Attack2") and is_on_floor() and not Dead:
			Attacking=true
			attack_1_collision_shape.disabled=false
			PlayAttackAnimation.rpc(&"Attack2")
			attack_animation_timer.start()

@rpc("authority","call_local","reliable")
func PlayAttackAnimation(AnimationName):
	animated_sprite_2d.play(AnimationName)
	

func _physics_process(delta: float) -> void:
	if not Attacking and not Dead:
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
	attack_1_collision_shape.disabled=true


func _on_leave_button_pressed() -> void:
	HighLevelNetworkHandler.LeaveServer()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if is_multiplayer_authority():
		if body.is_in_group("Players"):
			GiveDamage.rpc(body.get_path(),10)

@rpc("any_peer","call_local")
func GiveDamage(DamagedPlayer,DamageAmount):
	var PlayerToDamage=get_node(DamagedPlayer)

	if PlayerToDamage:
		var NextHealth=PlayerToDamage.Health-DamageAmount
		if NextHealth<=0:
			PlayerToDamage.Health=0
			PlayerToDamage.Dead=true
			PlayerToDamage.death_animation_timer.start()
			
		else:
			PlayerToDamage.Health=NextHealth


func _on_death_animation_timer_timeout() -> void:
	if is_multiplayer_authority():
		PlayerDead.rpc()

@rpc("any_peer","call_local")
func PlayerDead():
	visible=false
	attack_1_collision_shape.disabled=true
	if is_multiplayer_authority():
		ChangeSpectator()
	
func ChangeSpectator():
	var Players=get_tree().get_nodes_in_group("Players")
	var AlivePlayers=[]
	for Player in Players:
		if not Player.Dead and Player!=self:
			AlivePlayers.append(Player)
	if AlivePlayers.size()>0:
		CurrentSpectating=(CurrentSpectating+1)%AlivePlayers.size()
		var SpectatePlayer=AlivePlayers[CurrentSpectating]
		SpectatePlayer.camera_2d.make_current()
		
	
	

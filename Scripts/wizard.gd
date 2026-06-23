extends CharacterBody2D

@export var Dead=false
@export var Health=100
var SPEED = 200.0
var JUMP_VELOCITY = -250
var Attack1Cooldown=10
var Attack2Cooldown=3
@onready var camera_2d: Camera2D = %Camera2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
var Attacking=false
@onready var attack_animation_timer: Timer = $AttackAnimationTimer
@onready var lobby_id: Label = %LobbyId
@onready var health_label: Label = %HealthLabel
@onready var death_animation_timer: Timer = $DeathAnimationTimer
var CurrentSpectating=0
@onready var ray_cast_2d_right: RayCast2D = $InteractionRaycast/RayCast2DRight
@onready var ray_cast_2d_left: RayCast2D = $InteractionRaycast/RayCast2DLeft
@onready var select_menu: PanelContainer = $CanvasLayer/SelectMenu
var CurrentPhysicsProcess=true
@onready var attack_1_duration: Timer = %Attack1Duration
const ATTACK_BALL = preload("uid://c6gkl3o6jk388")
@onready var attack_spawn_point: Node2D = %AttackSpawnPoint
var CurrentCooldownAttack1=0
var CurrentCooldownAttack2=0

func _enter_tree() -> void:
	set_multiplayer_authority(int(name))
	
func _ready() -> void:
	floor_max_angle=deg_to_rad(85)
	floor_snap_length=16
	add_to_group('Players')
	if not is_multiplayer_authority():
		set_process(false)
		set_physics_process(false)
		$CanvasLayer.visible=false
	if is_multiplayer_authority():
		if Global.Username:
			$Username.text=Global.Username
		camera_2d.make_current()
		lobby_id.text="Lobby Code: "+HighLevelNetworkHandler.Tubeclient.session_id
		Input.set_custom_mouse_cursor(preload("res://Assets/crosshair.png"),Input.CURSOR_ARROW,Vector2(16,16))
		
func _process(delta: float) -> void:
	if is_multiplayer_authority():
		if not attack_1_duration.is_stopped():
			%BuffTimer.max_value=5
			%BuffTimer.value=attack_1_duration.time_left
			$CanvasLayer/BuffTimer/TimeRemain.text=str(ceil(attack_1_duration.time_left))
			$CanvasLayer/BuffTimer/TimeRemain.show()
		
		if CurrentCooldownAttack1>0:
			CurrentCooldownAttack1-=delta
			%Attack1Cooldown.max_value=Attack1Cooldown
			%Attack1Cooldown.value=CurrentCooldownAttack1
			$CanvasLayer/HBoxContainer/Attack1Cooldown/Cooldown.text=str(ceil(CurrentCooldownAttack1))
			$CanvasLayer/HBoxContainer/Attack1Cooldown/Cooldown.show()
		else:
			%Attack1Cooldown.value=0
			$CanvasLayer/HBoxContainer/Attack1Cooldown/Cooldown.hide()
		
		if CurrentCooldownAttack2>0:
			CurrentCooldownAttack2-=delta
			%Attack2Cooldown.max_value=Attack2Cooldown
			%Attack2Cooldown.value=CurrentCooldownAttack2
			$CanvasLayer/HBoxContainer/Attack2Cooldown/Cooldown.text=str(ceil(CurrentCooldownAttack2))
			$CanvasLayer/HBoxContainer/Attack2Cooldown/Cooldown.show()
		else:
			%Attack2Cooldown.value=0
			$CanvasLayer/HBoxContainer/Attack2Cooldown/Cooldown.hide()
		
		if ray_cast_2d_left.is_colliding()or ray_cast_2d_right.is_colliding():
			if Input.is_action_just_pressed(&"Interact"):
				select_menu.visible=!select_menu.visible
				CurrentPhysicsProcess=!CurrentPhysicsProcess
				set_physics_process(CurrentPhysicsProcess)
				if select_menu.visible:
					PlayAttackAnimation("Idle")
		if Dead==true:
			PlayAttackAnimation.rpc("Death")
			if Input.is_action_just_pressed(&"ChangeSpectator"):
				ChangeSpectator()
			return

		health_label.text=str(Health)
		if Input.is_action_just_pressed(&"Attack1") and is_on_floor() and not Dead and not Attacking and CurrentCooldownAttack1<=0:
			Attacking=true
			CurrentCooldownAttack1=Attack1Cooldown
			attack_animation_timer.start()
			PlayAttackAnimation.rpc(&"Attack1")
			Attack1.rpc()
			
		if Input.is_action_just_pressed(&"Attack2") and is_on_floor() and not Dead and not Attacking and CurrentCooldownAttack2<=0:
			Attacking=true
			CurrentCooldownAttack2=Attack2Cooldown
			PlayAttackAnimation.rpc(&"Attack2")
			attack_animation_timer.start()
			var IsAimingLeft=get_global_mouse_position().x<global_position.x
			animated_sprite_2d.flip_h=IsAimingLeft
			if IsAimingLeft:
				attack_spawn_point.position.x=-43
			else:
				attack_spawn_point.position.x=43
			var AimDirection=(get_global_mouse_position()-attack_spawn_point.global_position).normalized()
			if animated_sprite_2d.flip_h:
				AimDirection.x=-abs(AimDirection.x)
			else:
				AimDirection.x=abs(AimDirection.x)
			AimDirection=AimDirection.normalized()
			Attack2.rpc(AimDirection)
		
		if Input.is_action_just_pressed(&"Special") and Health<=25 and not Dead:
			SacrificeRevive()

@rpc("authority","call_local","reliable")
func PlayAttackAnimation(AnimationName):
	animated_sprite_2d.play(AnimationName)
	

func _physics_process(delta: float) -> void:
	if not Dead:
		var IsOnRope=false
		if is_on_floor():
				for CollisionNo in get_slide_collision_count():
					var CollidedWith=get_slide_collision(CollisionNo).get_collider()
					if CollidedWith and CollidedWith.is_in_group("GrappleRope"):
						IsOnRope=true
						break
		if IsOnRope:
			var RealRotation= get_floor_normal().angle()+(PI/2)
			rotation=lerp_angle(rotation,RealRotation,15*delta)
		else:
			rotation=lerp_angle(rotation,0,15*delta)
			
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
					attack_spawn_point.position.x = -43 if direction < 0 else 43
			if is_on_floor():
				if direction!=0:
					animated_sprite_2d.flip_h=direction<0
					attack_spawn_point.position.x = -43 if direction < 0 else 43
					$CollisionShape2D.position.x = 5 if direction < 0 else -5
					if animated_sprite_2d.animation!="Run":
						PlayAttackAnimation.rpc(&"Run")
				if direction==0:
					if animated_sprite_2d.animation!="Idle":
						PlayAttackAnimation.rpc(&"Idle")

			if direction:
				velocity.x = direction * SPEED

			else:
				velocity.x = move_toward(velocity.x, 0, SPEED)

			move_and_slide()


func _on_attack_animation_timer_timeout() -> void:
	Attacking=false



func _on_leave_button_pressed() -> void:
	HighLevelNetworkHandler.LeaveServer()


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
		


func _on_warrior_pressed() -> void:
	if is_multiplayer_authority():
		Global.MyCharacter="Warrior"
		HighLevelNetworkHandler.ChangeCharacter.rpc(multiplayer.get_unique_id(),"Warrior",Health)
		
func _on_button_pressed() -> void:
	if is_multiplayer_authority():
		Global.MyCharacter="Wizard"
		HighLevelNetworkHandler.ChangeCharacter.rpc(multiplayer.get_unique_id(),"Wizard",Health)

@rpc("any_peer","call_local")
func Attack1():
	SPEED=400
	JUMP_VELOCITY=-500	
	Attack2Cooldown=2
	if is_multiplayer_authority():
		if attack_1_duration.is_stopped():
			attack_1_duration.start()

@rpc("any_peer","call_local")
func Attack1Reset():
	SPEED=150
	JUMP_VELOCITY=-250
	Attack2Cooldown=3

func _on_attack_1_duration_timeout() -> void:
	if is_multiplayer_authority():
		Attack1Reset.rpc()
		$CanvasLayer/BuffTimer/TimeRemain.hide()


@rpc("any_peer","call_local")
func Attack2(AimDirection):
	var AttackBall=ATTACK_BALL.instantiate()
	AttackBall.top_level=true
	AttackBall.global_position=attack_spawn_point.global_position
	AttackBall.AttackDirection=AimDirection
	AttackBall.rotation=AimDirection.angle()
	get_tree().current_scene.add_child(AttackBall)
	

func _on_archer_pressed() -> void:
	if is_multiplayer_authority():
		Global.MyCharacter="Archer"
		HighLevelNetworkHandler.ChangeCharacter.rpc(multiplayer.get_unique_id(),"Archer",Health)


func _on_regen_timer_timeout() -> void:
	if not Dead and Health<100:
		Health=min(Health+randi_range(1,3),100)

@rpc("any_peer","call_local")
func RevivePlayer():
	Dead=false
	Health=100
	visible=true
	death_animation_timer.stop()
	PlayAttackAnimation("Idle")
	if is_multiplayer_authority():
		camera_2d.make_current()

func SacrificeRevive():
	var Players = get_tree().get_nodes_in_group("Players")
	var ReviveTarget=null
	for Player in Players:
		if Player.Dead and Player!=self:
			ReviveTarget=Player
			break
	if ReviveTarget:
		ReviveTarget.RevivePlayer.rpc()
		GiveDamage.rpc(get_path(),Health)
	

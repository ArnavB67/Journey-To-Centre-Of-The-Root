extends CharacterBody2D

@export var Dead=false
@export var Health=100
var SPEED = 250.0
var JUMP_VELOCITY = -450.0
var Attack1Cooldown=1.5
var Attack2Cooldown=5
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
const ARROW = preload("uid://cxi2neiheg8xg")
const GRAPPLE_ARROW = preload("uid://d0uswe3hxap8o")
@onready var attack_spawn_point: Node2D = %AttackSpawnPoint
var CurrentCooldownAttack1=0
var CurrentCooldownAttack2=0

func _enter_tree() -> void:
	set_multiplayer_authority(int(name))
	
func _ready() -> void:
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
		Input.set_custom_mouse_cursor(preload("res://Assets/crosshair.png"))
		
func _process(delta: float) -> void:
	if is_multiplayer_authority():
		
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
			PlayAttackAnimation.rpc(&"ShootArrow")
			var AimDirection=(get_global_mouse_position()-attack_spawn_point.global_position).normalized()
			if animated_sprite_2d.flip_h:
				AimDirection.x=-abs(AimDirection.x)
			else:
				AimDirection.x=abs(AimDirection.x)
			AimDirection=AimDirection.normalized()
			Attack1.rpc(AimDirection)
			
		if Input.is_action_just_pressed(&"Attack2") and is_on_floor() and not Dead and not Attacking and CurrentCooldownAttack2<=0:
			Attacking=true
			CurrentCooldownAttack2=Attack2Cooldown
			PlayAttackAnimation.rpc(&"Attack2")
			attack_animation_timer.start()
			var AimDirection=(get_global_mouse_position()-attack_spawn_point.global_position).normalized()
			if animated_sprite_2d.flip_h:
				AimDirection.x=-abs(AimDirection.x)
			else:
				AimDirection.x=abs(AimDirection.x)
			AimDirection=AimDirection.normalized()
			Attack2.rpc(AimDirection)

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
					attack_spawn_point.position.x = -43 if direction < 0 else 43
			if is_on_floor():
				if direction!=0:
					animated_sprite_2d.flip_h=direction<0
					attack_spawn_point.position.x = -43 if direction < 0 else 43
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
		HighLevelNetworkHandler.ChangeCharacter.rpc(multiplayer.get_unique_id(),"Warrior")
		
func _on_button_pressed() -> void:
	if is_multiplayer_authority():
		Global.MyCharacter="Wizard"
		HighLevelNetworkHandler.ChangeCharacter.rpc(multiplayer.get_unique_id(),"Wizard")

@rpc("any_peer","call_local")
func Attack1(AimDirection):
	var Arrow=ARROW.instantiate()
	Arrow.top_level=true
	Arrow.global_position=attack_spawn_point.global_position
	Arrow.AttackDirection=AimDirection
	Arrow.rotation=AimDirection.angle()
	get_tree().current_scene.add_child(Arrow)


@rpc("any_peer","call_local")
func Attack2(AimDirection):
	var GrappleArrow=GRAPPLE_ARROW.instantiate()
	GrappleArrow.top_level=true
	GrappleArrow.global_position=attack_spawn_point.global_position
	GrappleArrow.AttackDirection=AimDirection
	GrappleArrow.rotation=AimDirection.angle()
	get_tree().current_scene.add_child(GrappleArrow)
	


func _on_archer_pressed() -> void:
	if is_multiplayer_authority():
		Global.MyCharacter="Archer"
		HighLevelNetworkHandler.ChangeCharacter.rpc(multiplayer.get_unique_id(),"Archer")

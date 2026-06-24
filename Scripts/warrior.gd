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
@onready var attack_1_collision_shape: CollisionShape2D = $Attack1Hitbox/Attack1CollisionShape
@onready var death_animation_timer: Timer = $DeathAnimationTimer
var CurrentSpectating=0
@onready var attack_1_hitbox: Area2D = $Attack1Hitbox
@onready var attack_2_collision_shape: CollisionShape2D = $Attack2Hitbox/Attack2CollisionShape
@onready var attack_2_hitbox: Area2D = $Attack2Hitbox
@onready var ray_cast_2d_right: RayCast2D = $InteractionRaycast/RayCast2DRight
@onready var ray_cast_2d_left: RayCast2D = $InteractionRaycast/RayCast2DLeft
@onready var select_menu: PanelContainer = $CanvasLayer/SelectMenu
var CurrentPhysicsProcess=true
var JumpCount=0
var CurrentCooldownAttack1=0
var CurrentCooldownAttack2=0
var Attack1Cooldown=1
var Attack2Cooldown=5
var IsSpecialAbilityActive=false
var SpecialAbilityTarget=null
var DiedFromExplosion = false
@export var SyncPosition = Vector2.ZERO
@export var SyncRotation = 0

func _enter_tree() -> void:
	set_multiplayer_authority(int(name))

func _ready() -> void:
	floor_max_angle=deg_to_rad(85)
	floor_snap_length=16
	add_to_group('Players')
	SyncPosition = global_position
	if not is_multiplayer_authority():
		$CanvasLayer.visible=false
	if is_multiplayer_authority():
		if Global.Username:
			$Username.text=Global.Username
		camera_2d.make_current()
		lobby_id.text="Lobby Code: "+HighLevelNetworkHandler.Tubeclient.session_id
		Input.set_custom_mouse_cursor(preload("res://Assets/crosshair.png"),Input.CURSOR_ARROW,Vector2(16,16))


func _process(delta: float) -> void:
	if is_multiplayer_authority():
		if CurrentCooldownAttack1>0:
			CurrentCooldownAttack1-=delta
			%Attack1CooldownW.max_value=Attack1Cooldown
			%Attack1CooldownW.value=CurrentCooldownAttack1
			$CanvasLayer/HBoxContainer/Attack1CooldownW/Cooldown.text=str(ceil(CurrentCooldownAttack1))
			$CanvasLayer/HBoxContainer/Attack1CooldownW/Cooldown.show()
		else:
			%Attack1CooldownW.value=0
			$CanvasLayer/HBoxContainer/Attack1CooldownW/Cooldown.hide()
		
		if CurrentCooldownAttack2>0:
			CurrentCooldownAttack2-=delta
			%Attack2CooldownW.max_value=Attack2Cooldown
			%Attack2CooldownW.value=CurrentCooldownAttack2
			$CanvasLayer/HBoxContainer/Attack2CooldownW/Cooldown.text=str(ceil(CurrentCooldownAttack2))
			$CanvasLayer/HBoxContainer/Attack2CooldownW/Cooldown.show()
		else:
			%Attack2CooldownW.value=0
			$CanvasLayer/HBoxContainer/Attack2CooldownW/Cooldown.hide()
		
		if ray_cast_2d_left.is_colliding()or ray_cast_2d_right.is_colliding():
			if Input.is_action_just_pressed(&"Interact"):
				select_menu.visible=!select_menu.visible
				CurrentPhysicsProcess=!CurrentPhysicsProcess
				set_physics_process(CurrentPhysicsProcess)
				if select_menu.visible:
					PlayAttackAnimation.rpc("Idle")
		if Dead==true:
			if not DiedFromExplosion and animated_sprite_2d.animation!="Death":
				PlayAttackAnimation.rpc("Death")
			if Input.is_action_just_pressed(&"ChangeSpectator"):
				ChangeSpectator()
			return

		health_label.text=str(Health)
		if Input.is_action_just_pressed(&"Attack1") and is_on_floor() and not Dead and CurrentCooldownAttack1<=0:
			Attacking=true
			CurrentCooldownAttack1=Attack1Cooldown
			attack_1_collision_shape.disabled=false
			attack_animation_timer.start()
			PlayAttackAnimation.rpc(&"Attack1")
			
		if Input.is_action_just_pressed(&"Attack2") and is_on_floor() and not Dead and CurrentCooldownAttack2<=0:
			Attacking=true
			CurrentCooldownAttack2=Attack2Cooldown
			attack_2_collision_shape.disabled=false
			PlayAttackAnimation.rpc(&"Attack2")
			attack_animation_timer.start()
		if Input.is_action_just_pressed(&"Special") and not IsSpecialAbilityActive and Health<=25:
			var Enemies = get_tree().get_nodes_in_group("Enemies")
			var NearestEnemyDistance=1000000
			for Enemy in Enemies:
				var Distance = global_position.distance_to(Enemy.global_position)
				if Distance < NearestEnemyDistance:
					NearestEnemyDistance= Distance
					SpecialAbilityTarget=Enemy
				if SpecialAbilityTarget:
					IsSpecialAbilityActive = true
					PlayAttackAnimation.rpc("Run")
@rpc("authority","call_local","reliable")
func PlayAttackAnimation(AnimationName):
	animated_sprite_2d.play(AnimationName)
	

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		global_position=global_position.lerp(SyncPosition,15*delta)
		rotation = lerp_angle(rotation,SyncRotation,15*delta)
		return
	
	if IsSpecialAbilityActive:
		if not is_instance_valid(SpecialAbilityTarget):
			Explode()
			return
		var Direction= (SpecialAbilityTarget.global_position-global_position).normalized()
		velocity=Direction*SPEED*2
		var IsLeft= velocity.x<0
		animated_sprite_2d.flip_h=IsLeft
		move_and_slide()
		if global_position.distance_to(SpecialAbilityTarget.global_position)<=50:
			Explode()
		return
				
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

			if Input.is_action_just_pressed(&"jump") and (is_on_floor() or JumpCount!=1):
				JumpCount+=1
				velocity.y = JUMP_VELOCITY

			var direction := Input.get_axis(&"left", &"right")

			if not is_on_floor():
				PlayAttackAnimation.rpc(&"Jump")
				if direction!=0:
					animated_sprite_2d.flip_h=direction<0
			if is_on_floor():
				JumpCount=0
				if direction!=0:
					var IsLeft=direction<0
					animated_sprite_2d.flip_h=IsLeft
					if animated_sprite_2d.animation!="Run":
						PlayAttackAnimation.rpc(&"Run")
					if direction<0:
						attack_1_hitbox.scale.x=-1
						attack_2_hitbox.scale.x=-1
						$CollisionShape2D.position.x=-6
					else:
						attack_1_hitbox.scale.x=1
						attack_2_hitbox.scale.x=1
						$CollisionShape2D.position.x=6
				if direction==0:
					if animated_sprite_2d.animation!="Idle":
						PlayAttackAnimation.rpc(&"Idle")

			if direction:
				velocity.x = direction * SPEED

			else:
				velocity.x = move_toward(velocity.x, 0, SPEED)

			move_and_slide()
			SyncPosition = global_position
			SyncRotation= rotation


func _on_attack_animation_timer_timeout() -> void:
	Attacking=false
	attack_1_collision_shape.disabled=true
	attack_2_collision_shape.disabled=true


func _on_leave_button_pressed() -> void:
	HighLevelNetworkHandler.LeaveServer()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if is_multiplayer_authority():
		if body.is_in_group("Enemies"):
			body.GiveDamage.rpc(body.get_path(),10)



@rpc("any_peer","call_local")
func GiveDamage(DamagedPlayer,DamageAmount):
	var PlayerToDamage=get_node(DamagedPlayer)

	if PlayerToDamage:
		var NextHealth=PlayerToDamage.Health-DamageAmount
		if NextHealth<=0 and PlayerToDamage.IsSpecialAbilityActive:
			PlayerToDamage.Health=1
			return
		
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
		SpectatePlayer.camera_2d.reset_smoothing()
		


func _on_warrior_pressed() -> void:
	if is_multiplayer_authority():
		Global.MyCharacter="Warrior"
		HighLevelNetworkHandler.ChangeCharacter.rpc(multiplayer.get_unique_id(),"Warrior",Health)
		
func _on_button_pressed() -> void:
	if is_multiplayer_authority():
		Global.MyCharacter="Wizard"
		HighLevelNetworkHandler.ChangeCharacter.rpc(multiplayer.get_unique_id(),"Wizard",Health)


func _on_attack_2_hitbox_body_entered(body: Node2D) -> void:
	if is_multiplayer_authority():
		if body.is_in_group("Enemies"):
			body.GiveDamage.rpc(body.get_path(),25)


func _on_archer_pressed() -> void:
	if is_multiplayer_authority():
		Global.MyCharacter="Archer"
		HighLevelNetworkHandler.ChangeCharacter.rpc(multiplayer.get_unique_id(),"Archer",Health)


@rpc("any_peer","call_local")
func RevivePlayer():
	Dead=false
	DiedFromExplosion = false
	Health=100
	visible=true
	animated_sprite_2d.visible=true
	death_animation_timer.stop()
	PlayAttackAnimation("Idle")
	if is_multiplayer_authority():
		camera_2d.make_current()

func Explode():
	var ExplosionRadius = 120
	var Enemies= get_tree().get_nodes_in_group("Enemies")
	for Enemy in Enemies:
		if global_position.distance_to(Enemy.global_position)<=ExplosionRadius:
			Enemy.GiveDamage.rpc(Enemy.get_path(),80)
	ExplosionVisuals.rpc()

@rpc("any_peer","call_local")
func ExplosionVisuals():
	IsSpecialAbilityActive=false
	Health=0
	Dead=true
	animated_sprite_2d.visible=false
	$ExplosionParticles.emitting=true
	death_animation_timer.start()
	

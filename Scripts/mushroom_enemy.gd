extends CharacterBody2D

enum State {IDLE,CHASE,ATTACKING,DEAD}
var CurrentState = State.IDLE
var TargetPlayer= null
@export var Health=100
@export var Dead= false
var Speed = 500
var OnCooldown=false
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var DamageAttack1Hitbox: CollisionShape2D = $Attack1Hitbox/CollisionShape2D
@onready var attack_1_hitbox: Area2D = $Attack1Hitbox
var JumpVelocity=-400
var CurrentPhase=1
var LastAttack=''
var PlannedAttack='Melee'
var MeleeRange=55
@onready var progress_bar: ProgressBar = $ProgressBar




func _ready() -> void:
	add_to_group("Enemies")
	DisableHitbox()

func _enter_tree() -> void:
	set_multiplayer_authority(1)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity+=get_gravity()*delta
		
	match CurrentState:
		State.IDLE:
			velocity.x=0
			if is_multiplayer_authority() and animated_sprite_2d.animation!="Idle":
				PlayAnimation.rpc("Idle")

		State.CHASE:
			if is_multiplayer_authority():
				ChasePlayer(delta)
		
		State.ATTACKING:
			velocity.x=0
		
		State.DEAD:
			velocity.x=0
	move_and_slide()

func _process(delta: float) -> void:
	progress_bar.value=Health
	#health.text=str(Health)+"/500"

@rpc("authority","call_local")
func PlayAnimation(AnimationName):
	if animated_sprite_2d.animation!=AnimationName:
		animated_sprite_2d.play(AnimationName)

func ChasePlayer(delta):
	if not is_instance_valid(TargetPlayer) or TargetPlayer.Dead:
		FindTarget()
		return

	var Distance=global_position.distance_to(TargetPlayer.global_position)
	var Direction=sign(TargetPlayer.global_position.x-global_position.x)
	var IsLeft=Direction>0
	var HeightDifference=TargetPlayer.global_position.y-global_position.y
	var HorizontalDistance=abs(TargetPlayer.global_position.x-global_position.x)
	
	if animated_sprite_2d.flip_h!=IsLeft:
		SyncFlipH.rpc(IsLeft)
		if  IsLeft:
			attack_1_hitbox.scale.x=-1
		else:
			attack_1_hitbox.scale.x=1
	if OnCooldown:
		velocity.x=move_toward(velocity.x,0,Speed)
		if animated_sprite_2d.animation!="Idle" and is_on_floor():
			PlayAnimation.rpc("Idle")
		return
	if is_on_floor():
		var IsStuck=is_on_wall() and velocity.x!=0
		var IsPlayerHigher=HeightDifference<-60 and abs(TargetPlayer.global_position.x-global_position.x)<200
		var RandomJump=randf()<0.02
		if IsStuck or IsPlayerHigher or RandomJump:
			velocity.y=JumpVelocity
			
	if PlannedAttack=="Melee":
		if HorizontalDistance<=MeleeRange:
			velocity.x=0
			if is_on_floor():
				OnCooldown=true
				LastAttack="Melee"
				TriggerAttack.rpc("Melee")
		else:
			velocity.x=Direction*Speed
			if animated_sprite_2d.animation!="Run":
				PlayAnimation.rpc("Run")


@rpc("authority","call_local")
func SyncFlipH(IsLeft):
	animated_sprite_2d.flip_h=IsLeft

func PlanNextMove():
	if not is_instance_valid(TargetPlayer):
		return
	var Distance=global_position.distance_to(TargetPlayer.global_position)
	var Random=randf()
	if Health<=250 and CurrentPhase==1:
		CurrentPhase=2
		Speed=800
	if CurrentPhase==2:
		Speed=randi_range(700,900)
	else:
		Speed=randi_range(400,600)
	if Distance<100:
		PlannedAttack="Melee"
	else:
		PlannedAttack="Melee"
	
@rpc("authority","call_local")
func TriggerAttack(Attack):
	CurrentState=State.ATTACKING
	animated_sprite_2d.play(Attack)
	if Attack=="Melee":
		get_tree().create_timer(0.4).timeout.connect(EnableHitbox)
		get_tree().create_timer(0.6).timeout.connect(DisableHitbox)

func EnableHitbox():
	if not Dead:
		DamageAttack1Hitbox.set_deferred("disabled",false)
		
func DisableHitbox():
	DamageAttack1Hitbox.set_deferred("disabled",true)

func _on_aggro_range_body_entered(body: Node2D) -> void:
	if is_multiplayer_authority() and CurrentState==State.IDLE:
		if body.is_in_group("Players") and not body.Dead:
			SyncTarget.rpc(body.get_path())
			PlanNextMove()

@rpc("authority","call_local")
func SyncTarget(PlayerPath):
	TargetPlayer=get_node_or_null(PlayerPath)
	if TargetPlayer:
		CurrentState=State.CHASE
	


func _on_attack_1_hitbox_body_entered(body: Node2D) -> void:
	if is_multiplayer_authority():
		if body.is_in_group("Players"):
			if CurrentPhase==2:
				body.GiveDamage.rpc(body.get_path(),20)
			else:
				body.GiveDamage.rpc(body.get_path(),10)


func _on_animated_sprite_2d_animation_finished() -> void:
	if CurrentState==State.ATTACKING:
		CurrentState=State.CHASE
		if is_multiplayer_authority():
			var CooldownTime
			if CurrentPhase==2:
				CooldownTime=0.8
			else:
				CooldownTime=1
			get_tree().create_timer(CooldownTime).timeout.connect(ResetCooldown)
		
func ResetCooldown():
	OnCooldown=false
	PlanNextMove()

@rpc("any_peer", "call_local")
func GiveDamage(DamagedBody,DamageAmount):
	if Dead:
		return
	Health -= DamageAmount
	if Health <= 0:
		Health = 0
		Dead = true
		CurrentState = State.DEAD
		DisableHitbox()
		PlayAnimation.rpc("Death")
		get_tree().create_timer(4.0).timeout.connect(queue_free)

func FindTarget():
	var Players=get_tree().get_nodes_in_group("Players")
	var ClosestPlayer
	var ClosestDistance=10000
	for Player in Players:
		if not Player.Dead:
			var Distance=global_position.distance_to(Player.global_position)
			if Distance<400:
				if Distance<ClosestDistance:
					ClosestDistance=Distance
					ClosestPlayer=Player
		if ClosestPlayer:
			SyncTarget.rpc(ClosestPlayer.get_path())
		else:
			CurrentState=State.IDLE
			TargetPlayer=null
		

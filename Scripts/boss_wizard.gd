extends CharacterBody2D

enum State {IDLE,CHASE,ATTACKING,DEAD}
var CurrentState = State.IDLE
var TargetPlayer= null
@export var Health=400
@export var Dead= false
var Speed = 300
var OnCooldown=false
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var DamageAttack1Hitbox: CollisionShape2D = $Attack1Hitbox/CollisionShape2D
@onready var attack_1_hitbox: Area2D = $Attack1Hitbox
var JumpVelocity=-500
var CurrentPhase=1
var LastAttack=''
var PlannedAttack='Melee'
var MeleeRange=65
var SpellRange=250
const WIZARD_BOSS_SPELL = preload("uid://b0y2pnlu1laws")
@onready var progress_bar: ProgressBar = $CanvasLayer/ProgressBar
@onready var health: Label = $CanvasLayer/Health
var Poisoned = false
var PoisonTimerStarted = false
@export var SyncPosition = Vector2.ZERO

func _ready() -> void:
	add_to_group("Enemies")
	DisableHitbox()
	SyncPosition = global_position
	
	
func _enter_tree() -> void:
	set_multiplayer_authority(1)

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		global_position = global_position.lerp(SyncPosition,15*delta)
		return
		
	if not is_on_floor():
		velocity+=get_gravity()*delta
		
	match CurrentState:
		State.IDLE:
			velocity.x=0
			if is_multiplayer_authority() and animated_sprite_2d.animation!="Idle":
				PlayAnimation.rpc("Idle")
			if is_multiplayer_authority():
				FindTarget()

		State.CHASE:
			if is_multiplayer_authority():
				FindTarget()
				ChasePlayer(delta)
		
		State.ATTACKING:
			velocity.x=0
		
		State.DEAD:
			velocity.x=0
	move_and_slide()
	SyncPosition = global_position

func _process(delta: float) -> void:
	if Poisoned==true and not PoisonTimerStarted:
		PoisonTimerStarted=true
		$PoisonTimer.start()
		ShowParticles.rpc()
		
	progress_bar.value=Health
	health.text=str(Health)+"/500"

@rpc("authority","call_local")
func ShowParticles():
	$PoisonedParticleEffect.emitting=true

@rpc("authority","call_local")
func PlayAnimation(AnimationName):
	if animated_sprite_2d.animation!=AnimationName:
		animated_sprite_2d.play(AnimationName)

func ChasePlayer(delta):
	if not is_instance_valid(TargetPlayer) or TargetPlayer.Dead:
		return
	
	var Distance=global_position.distance_to(TargetPlayer.global_position)
	var Direction=sign(TargetPlayer.global_position.x-global_position.x)
	var IsLeft=Direction<0
	var HeightDifference=TargetPlayer.global_position.y-global_position.y
	var HorizontalDistance=abs(TargetPlayer.global_position.x-global_position.x)
	
	if Direction==0:
		Direction=1
	
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
		var RandomJump=randf()<0.015
		if IsStuck or IsPlayerHigher or RandomJump:
			velocity.y=JumpVelocity
			
	if PlannedAttack=="RetreatAndSpell":
		if Distance>160 or is_on_wall():
			PlannedAttack="Spell"
		else:
			velocity.x=-Direction*Speed*0.8
			if animated_sprite_2d.animation!="Run":
				PlayAnimation.rpc("Run")
	elif PlannedAttack=="Melee":
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

	elif PlannedAttack=="Spell":
		var OptimalSpellDistance=150
		if HorizontalDistance<OptimalSpellDistance and not is_on_wall():
			velocity.x=-Direction*Speed*0.8
			if animated_sprite_2d.animation!="Run":
				PlayAnimation.rpc("Run")
		elif HorizontalDistance>SpellRange:
			velocity.x=Direction*Speed
			if animated_sprite_2d.animation!="Run":
				PlayAnimation.rpc("Run")
		else:
			OnCooldown=true
			LastAttack="Spell"
			TriggerAttack.rpc("Spell")


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
		if LastAttack=="Melee" and Random<0.6:
			PlannedAttack="RetreatAndSpell"
		elif Random>0.85:
			PlannedAttack="Melee"
		else:
			PlannedAttack="Melee"
	else:
		if LastAttack=="Spell" and Random<0.7:
			PlannedAttack="Melee"
		elif Random>0.95:
			PlannedAttack="Spell"
		else:
			PlannedAttack="Spell"
	
@rpc("authority","call_local")
func TriggerAttack(Attack):
	CurrentState=State.ATTACKING
	animated_sprite_2d.play(Attack)
	if Attack=="Melee":
		get_tree().create_timer(0.4).timeout.connect(EnableHitbox)
		get_tree().create_timer(0.6).timeout.connect(DisableHitbox)
	elif Attack=="Spell":
		get_tree().create_timer(0.4).timeout.connect(AddSpell)

func EnableHitbox():
	if not Dead:
		DamageAttack1Hitbox.set_deferred("disabled",false)
		
func DisableHitbox():
	DamageAttack1Hitbox.set_deferred("disabled",true)
	
func AddSpell():
	if is_multiplayer_authority() and is_instance_valid(TargetPlayer)and not Dead:
		var SpellDirection=(TargetPlayer.global_position-global_position).normalized()
		var SpawnPosition=global_position+Vector2(SpellDirection*30)
		SpawnSpell.rpc(SpellDirection,SpawnPosition)
	
@rpc("authority","call_local")
func SpawnSpell(SpellDirection,SpawnPosition):
	var Spell=WIZARD_BOSS_SPELL.instantiate()
	Spell.top_level=true
	Spell.global_position=SpawnPosition
	Spell.Direction=SpellDirection
	Spell.rotation=SpellDirection.angle()
	get_tree().current_scene.add_child(Spell)



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
		$CanvasLayer.visible=true
	


func _on_attack_1_hitbox_body_entered(body: Node2D) -> void:
	if is_multiplayer_authority():
		if body.is_in_group("Players"):
			if CurrentPhase==2:
				body.GiveDamage.rpc(body.get_path(),10)
			else:
				body.GiveDamage.rpc(body.get_path(),5)


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
		$CanvasLayer.hide()
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
			if Distance<2000:
				if Distance<ClosestDistance:
					ClosestDistance=Distance
					ClosestPlayer=Player
	if ClosestPlayer:
		if TargetPlayer!= ClosestPlayer:
			SyncTarget.rpc(ClosestPlayer.get_path())
			PlanNextMove()
	else:
		CurrentState=State.IDLE
		TargetPlayer=null
		


func _on_poison_timer_timeout() -> void:
	GiveDamage.rpc(get_path(),5)

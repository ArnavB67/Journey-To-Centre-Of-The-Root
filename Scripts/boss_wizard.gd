extends CharacterBody2D

enum State {IDLE,CHASE,ATTACKING,DEAD}
var CurrentState = State.IDLE
var TargetPlayer= null
@export var Health=500
@export var Dead= false
var Speed = 500
var OnCooldown=false
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var DamageAttack1Hitbox: CollisionShape2D = $Attack1Hitbox/CollisionShape2D
@onready var attack_1_hitbox: Area2D = $Attack1Hitbox

var CurrentPhase=1
var LastAttack=''
var PlannedAttack='Melee'
var MeleeRange=65
var SpellRange=250
const WIZARD_BOSS_SPELL = preload("uid://b0y2pnlu1laws")



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
	
@rpc("authority","call_local")
func PlayAnimation(AnimationName):
	if animated_sprite_2d.animation!=AnimationName:
		animated_sprite_2d.play(AnimationName)

func ChasePlayer(delta):
	if not is_instance_valid(TargetPlayer) or TargetPlayer.Dead:
		CurrentState=State.IDLE
		TargetPlayer=null
		return
	
	var Distance=global_position.distance_to(TargetPlayer.global_position)
	var Direction=sign(TargetPlayer.global_position.x-global_position.x)
	var IsLeft=Direction<0
	if animated_sprite_2d.flip_h!=IsLeft:
		SyncFlipH.rpc(IsLeft)
		if  IsLeft:
			attack_1_hitbox.scale.x=-1
		else:
			attack_1_hitbox.scale.x=1
	if OnCooldown:
		velocity.x=move_toward(velocity.x,0,Speed)
		if animated_sprite_2d.animation!="Idle":
			PlayAnimation.rpc("Idle")
		return
	
	if PlannedAttack=="RetreatAndSpell":
		if Distance>160 or is_on_wall():
			PlannedAttack="Spell"
		else:
			velocity.x=-Direction*Speed*0.8
			if animated_sprite_2d.animation!="Run":
				PlayAnimation.rpc("Run")
	elif PlannedAttack=="Melee":
		if Distance<=MeleeRange:
			OnCooldown=true
			LastAttack="Melee"
			TriggerAttack.rpc("Melee")
		else:
			velocity.x=Direction*Speed
			if animated_sprite_2d.animation!="Run":
				PlayAnimation.rpc("Run")

	elif PlannedAttack=="Spell":
		var OptimalSpellDistance=150
		if Distance<OptimalSpellDistance and not is_on_wall():
			velocity.x=-Direction*Speed*0.8
			if animated_sprite_2d.animation!="Run":
				PlayAnimation.rpc("Run")
		elif Distance>SpellRange:
			velocity.x=Direction*Speed
			if animated_sprite_2d.animation!="Run":
				PlayAnimation("Run")
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
	if Distance<100:
		if LastAttack=='Melee' and Random<0.6:
			PlannedAttack="RetreatAndSpell"
		else:
			PlannedAttack="Melee"
	else:
		if LastAttack=="Spell" and Random<0.7:
			PlannedAttack="Melee"
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
		get_tree().create_timer(0.8).timeout.connect(AddSpell)

func EnableHitbox():
	if not Dead:
		DamageAttack1Hitbox.disabled=false
		
func DisableHitbox():
	DamageAttack1Hitbox.disabled=true
	
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
	


func _on_attack_1_hitbox_body_entered(body: Node2D) -> void:
	if is_multiplayer_authority():
		if body.is_in_group("Players"):
			if CurrentPhase==2:
				body.GiveDamage.rpc(body.get_path(),35)
			else:
				body.GiveDamage.rpc(body.get_path(),25)


func _on_animated_sprite_2d_animation_finished() -> void:
	if CurrentState==State.ATTACKING:
		CurrentState=State.CHASE
		if is_multiplayer_authority():
			var CooldownTime
			if CurrentPhase==2:
				CooldownTime=1
			else:
				CooldownTime=2
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

extends CharacterBody2D

enum State {IDLE,CHASE,ATTACKING,DEAD}
var CurrentState = State.IDLE
var TargetPlayer= null
@export var Health=100
@export var Dead= false
var Speed = 200
var OnCooldown=false
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var DamageAttack1Hitbox: CollisionShape2D = $Attack1Hitbox/CollisionShape2D
@onready var attack_1_hitbox: Area2D = $Attack1Hitbox
var JumpVelocity=-350
var CurrentPhase=1
var LastAttack=''
var PlannedAttack='Melee'
var MeleeRange=45
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var nearby_ground_detector: RayCast2D = $NearbyGroundDetector
@onready var farther_ground_detector: ShapeCast2D = $FartherGroundDetector
var LastTargetGroundY=0
var Poisoned = false
@export var SyncPosition = Vector2.ZERO

func _ready() -> void:
	add_to_group("Enemies")
	SyncPosition= global_position
	DisableHitbox()

func _enter_tree() -> void:
	set_multiplayer_authority(1)

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		global_position=global_position.lerp(SyncPosition,15*delta)
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
	SyncPosition= global_position

func _process(delta: float) -> void:
	progress_bar.value=Health

@rpc("authority","call_local")
func PlayAnimation(AnimationName):
	if animated_sprite_2d.animation!=AnimationName:
		animated_sprite_2d.play(AnimationName)

func ChasePlayer(delta):
	if not is_instance_valid(TargetPlayer) or TargetPlayer.Dead:
		return
	if TargetPlayer.is_on_floor():
		LastTargetGroundY=TargetPlayer.global_position.y
	elif LastTargetGroundY==0:
		LastTargetGroundY=TargetPlayer.global_position.y
		
	var Distance=global_position.distance_to(TargetPlayer.global_position)
	var Direction=sign(TargetPlayer.global_position.x-global_position.x)
	var IsLeft=Direction>0
	var HeightDifference=LastTargetGroundY-global_position.y
	var HorizontalDistance=abs(TargetPlayer.global_position.x-global_position.x)
	
	if animated_sprite_2d.flip_h!=IsLeft:
		SyncFlipH.rpc(IsLeft)
	if  IsLeft:
		attack_1_hitbox.scale.x=-1
		nearby_ground_detector.position.x=25
		farther_ground_detector.position.x=96
	else:
		attack_1_hitbox.scale.x=1
		nearby_ground_detector.position.x=-25
		farther_ground_detector.position.x=-96
			
	if OnCooldown:
		velocity.x=move_toward(velocity.x,0,Speed)
		if animated_sprite_2d.animation!="Idle" and is_on_floor():
			PlayAnimation.rpc("Idle")
		return
	
	var IsOnEdge=false
	
	if is_on_floor():
		nearby_ground_detector.force_raycast_update()
		IsOnEdge= not nearby_ground_detector.is_colliding()
		var IsStuck=is_on_wall() and velocity.x!=0
		var IsPlayerHigher=HeightDifference<-60 and abs(TargetPlayer.global_position.x-global_position.x)<30
		var RandomJump=randf()<0.001
		if IsOnEdge:
			farther_ground_detector.force_shapecast_update()
			if farther_ground_detector.is_colliding():
				var Normal=farther_ground_detector.get_collision_normal(0)
				if Normal.y>-0.5:
						velocity.x=0
						PlayAnimation.rpc("Idle")
						return
						
				var CollidingPoint=farther_ground_detector.get_collision_point(0)
				var DistanceX=abs(CollidingPoint.x-global_position.x)
				var DistanceY=CollidingPoint.y-global_position.y-20
				var Gravity=get_gravity().y
				var Discriminant=JumpVelocity*JumpVelocity+2*Gravity*DistanceY
				if Discriminant>=0:
					var TimeOfFlight= (-JumpVelocity+sqrt(Discriminant))/(Gravity)
					if TimeOfFlight>0.0001:
						velocity.y=JumpVelocity
						velocity.x=(DistanceX/TimeOfFlight)*Direction
					else:
						velocity.x=0
						PlayAnimation.rpc("Idle")
						return
				else:
					var TimeOfFlight=0.6
					velocity.y=(DistanceY-(0.5*Gravity*TimeOfFlight*TimeOfFlight))/TimeOfFlight
					velocity.x=(DistanceX/TimeOfFlight)*Direction
			else:
				velocity.x=0
				PlayAnimation.rpc("Idle")
				TargetPlayer=null
				CurrentState=State.IDLE
				return
		else:
			var IsBlockedByPlayer=HorizontalDistance<=MeleeRange
			if (IsStuck and not IsBlockedByPlayer) or IsPlayerHigher or RandomJump:
				velocity.y=JumpVelocity
			
	if PlannedAttack=="Melee":
		if HorizontalDistance<=MeleeRange and is_on_floor() and not IsOnEdge:
			velocity.x=0
			if is_on_floor():
				OnCooldown=true
				LastAttack="Melee"
				TriggerAttack.rpc("Melee")
		else:
			if TargetPlayer!=null:
				if is_on_floor() and not IsOnEdge:
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
	if Health<=50 and CurrentPhase==1:
		CurrentPhase=2
		Speed=100
	if CurrentPhase==2:
		Speed=randi_range(200,250)
	else:
		Speed=randi_range(200,220)
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
		if TargetPlayer!=ClosestPlayer:
			SyncTarget.rpc(ClosestPlayer.get_path())
	else:
		CurrentState=State.IDLE
		TargetPlayer=null
		

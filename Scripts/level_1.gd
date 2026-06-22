extends Node2D

const MUSHROOM_ENEMY = preload("uid://dr5ubqx61w6o4")
@onready var trap_1_enemy_spawn: Node2D = $Trap1/Trap1EnemySpawn
@onready var trap_1_collision_shape_2d: CollisionShape2D = %Trap1CollisionShape2D
@onready var Lasers = [$Laser1,$Laser2,$Laser3]
var LaserOnLength=146
var LaserOffLength=0
var IsLaserOn=false
var LaserCurrentLenght=0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for Laser in Lasers:
		var LaserArea=Laser.get_node("Area2D")
		LaserArea.body_entered.connect(OnLaserEntered)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_trap_1_body_entered(body: Node2D) -> void:
	if body.is_in_group("Players"):
		SpawnEnemies(3)
		trap_1_collision_shape_2d.set_deferred(&"disabled",true)
		
func SpawnEnemies(NoOfEnemies):
	for i in range(NoOfEnemies):
		var Enemy=MUSHROOM_ENEMY.instantiate()
		Enemy.global_position=trap_1_enemy_spawn.global_position
		get_tree().current_scene.add_child(Enemy)
		await get_tree().create_timer(0.8).timeout


func _on_barrier_1_body_entered(body: Node2D) -> void:
	if  body.is_in_group("Players"):
		body.GiveDamage(body.get_path(),100000)


func _on_laser_timer_timeout() -> void:
	IsLaserOn=!IsLaserOn
	if IsLaserOn:
		LaserCurrentLenght=LaserOnLength
	else:
		LaserCurrentLenght=LaserOffLength
	var LaserTween=create_tween().set_parallel(true)
	for LaserNo in range(Lasers.size()):
		LaserTween.tween_property(Lasers[LaserNo],"scale:y",LaserCurrentLenght,randf_range(0.2,0.8))

func OnLaserEntered(body):
	if body.is_in_group("Players"):
		body.GiveDamage(body.get_path(),15)
		
	

	
	

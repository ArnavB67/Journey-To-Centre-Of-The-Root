extends Node2D

const MUSHROOM_ENEMY = preload("uid://dr5ubqx61w6o4")
@onready var trap_1_enemy_spawn: Node2D = $Trap1/Trap1EnemySpawn
@onready var trap_1_collision_shape_2d: CollisionShape2D = %Trap1CollisionShape2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


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

extends Node3D

@export var speed : float = 5
@onready var mesh = $Sound_Token/Circle
var collision_area: Area3D

func _ready() -> void:
	TokenTracker.register_token()
	setup_collision_area()
	if collision_area:
		collision_area.body_entered.connect(_on_body_entered)

func setup_collision_area() -> void:
	collision_area = Area3D.new()
	collision_area.name = "Area3D"

	var collision_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 0.5
	collision_shape.shape = sphere_shape

	collision_area.add_child(collision_shape)
	add_child(collision_area)

	if mesh:
		collision_area.position = mesh.position

func _process(delta: float) -> void:
	rotate_object_local(Vector3.UP, (speed * delta))

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		collect_token()

func collect_token() -> void:
	TokenTracker.collect_token()
	var tween = create_tween()
	tween.tween_property(mesh, "scale", Vector3.ZERO, 0.3)
	tween.tween_callback(queue_free)
	$CollisionShape3D/FmodEventEmitter3D_Collect.play()

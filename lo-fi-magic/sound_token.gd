extends Node3D

@export var speed : float = 5
@onready var mesh = $Sound_Token/Circle

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	rotate_object_local(Vector3.UP, (speed * delta)) 
	pass

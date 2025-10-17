extends Node3D

@export var speed : float = 5
#@export var tokenColor : Color = Color(251,63, 255, 255)
#@onready var mesh = $Sound_Token/Circle
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#mesh.get_material_override().albedo_color = tokenColor
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	rotate_object_local(Vector3.UP, (speed * delta)) 
	pass

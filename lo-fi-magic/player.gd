extends RigidBody3D

var mouse_sensitivity := 0.001
var twist_input := 0.0
var pitch_input := 0.0
var is_running := false

@onready var twist_pivot := $TwistPivot
@onready var pitch_pivot := $TwistPivot/PitchPivot

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var input := Vector3.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.z = Input.get_axis("move_forward", "move_back")
	
	# Check if shift is pressed for running
	is_running = Input.is_action_pressed("sprint")
	var move_speed = 1200.0 * (1.5 if is_running else 1.0)
	
	apply_central_force(twist_pivot.basis * input * move_speed * delta)

	# Jump command
	if Input.is_action_just_pressed("jump") and is_on_floor():
		apply_central_force(Vector3.UP * 1000.0)

	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	twist_pivot.rotate_y(twist_input)
	pitch_pivot.rotate_x(pitch_input)
	pitch_pivot.rotation.x = clamp(pitch_pivot.rotation.x,
		deg_to_rad(-30),
		deg_to_rad(30)
	)
	
	# Rotate player model to match camera's horizontal rotation
	$LoFi_Magic_Temp_Character.rotation.y = twist_pivot.rotation.y
	
	twist_input = 0.0
	pitch_input = 0.0
	
	# Update animation conditions
	$LoFi_Magic_Temp_Character/AnimationTree.set("parameters/conditions/idle", is_on_floor() && input.length() == 0)
	$LoFi_Magic_Temp_Character/AnimationTree.set("parameters/conditions/walk", is_on_floor() && input.length() > 0 && !is_running)
	$LoFi_Magic_Temp_Character/AnimationTree.set("parameters/conditions/run", is_on_floor() && input.length() > 0 && is_running)
	$LoFi_Magic_Temp_Character/AnimationTree.set("parameters/conditions/Jump", Input.is_action_just_pressed("jump") && is_on_floor())
	$LoFi_Magic_Temp_Character/AnimationTree.set("parameters/conditions/InAir", !is_on_floor())

func is_on_floor() -> bool:
	# Simple ground check using raycast
	var space_state = get_world_3d().direct_space_state
	var origin = global_position
	var end = origin + Vector3.DOWN * 1.1
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	return !result.is_empty()
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			twist_input = - event.relative.x * mouse_sensitivity
			pitch_input = - event.relative.y * mouse_sensitivity

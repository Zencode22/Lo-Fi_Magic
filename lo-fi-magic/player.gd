extends RigidBody3D

var mouse_sensitivity := 0.001
var twist_input := 0.0
var pitch_input := 0.0
var is_running := false

@onready var twist_pivot := $TwistPivot
@onready var pitch_pivot := $TwistPivot/PitchPivot

var last_direction = Vector3.FORWARD
@export var rotation_speed = 8
var move_direction : Vector3

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var input := Vector3.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.z = Input.get_axis("move_forward", "move_back")
	
	# Check if shift is pressed for running
	is_running = Input.is_action_pressed("run")
	var move_speed = 1200.0 * (1.5 if is_running else 1.0)
	
	apply_central_force(twist_pivot.basis * input * move_speed * delta)

	# Jump command
	if Input.is_action_just_pressed("jump") and is_on_floor():
		var jump_height = 5.0
		var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
		var initial_velocity = sqrt(2 * gravity * jump_height)
		var jump_impulse = mass * initial_velocity
		apply_central_impulse(Vector3.UP * jump_impulse)

	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	twist_pivot.rotate_y(twist_input)
	pitch_pivot.rotate_x(pitch_input)
	pitch_pivot.rotation.x = clamp(pitch_pivot.rotation.x,
		deg_to_rad(-30),
		deg_to_rad(30)
	)
	var direction = ($TwistPivot.transform.basis * Vector3(input.x, 0, input.z)).normalized()
	if direction:
		last_direction = direction
		# Rotate player model to match camera's horizontal rotation
		#$LoFi_Magic_Temp_Character.rotation.y = twist_pivot.rotation.y
		var target_rotation = atan2(last_direction.x, last_direction.z)
		var current_rotation = $LoFi_Magic_Temp_Character.rotation
		$LoFi_Magic_Temp_Character.rotation.y = lerp_angle(current_rotation.y, target_rotation, delta * rotation_speed)
	
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

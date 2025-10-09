extends RigidBody3D

var mouse_sensitivity := 0.001
var twist_input := 0.0
var pitch_input := 0.0
var is_running := false
var is_grabbing := false
var default_movespeed := 1200.0

@onready var twist_pivot := $TwistPivot
@onready var pitch_pivot := $TwistPivot/PitchPivot

var last_direction = Vector3.FORWARD
@export var rotation_speed = 8

@onready var state_machine = $LoFi_Magic_Temp_Character/AnimationTree.get("parameters/playback")
@onready var anim_tree = $LoFi_Magic_Temp_Character/AnimationTree

var grabbed_object: RigidBody3D = null
var grab_range: float = 5.0

# Add these new variables for the grab prompt
@onready var grab_prompt_label = $GrabPromptLabel
var can_grab_object: bool = false
var current_grab_target: Node3D = null

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Initialize grab prompt as hidden
	if grab_prompt_label:
		grab_prompt_label.hide()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var input := Vector3.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.z = Input.get_axis("move_forward", "move_back")
	
	# Check for grab-able objects
	check_for_grab_objects()
	
	# Check if shift is pressed for running
	is_running = Input.is_action_pressed("run")
	var move_speed = default_movespeed * (1.5 if is_running else 1.0)
	
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
		if is_grabbing && grabbed_object != null:
			last_direction = grabbed_object.position
		else:
			last_direction = direction
		# Rotate player model to match camera's horizontal rotation
		#$LoFi_Magic_Temp_Character.rotation.y = twist_pivot.rotation.y
		var target_rotation = atan2(last_direction.x, last_direction.z)
		var current_rotation = $LoFi_Magic_Temp_Character.rotation
		$LoFi_Magic_Temp_Character.rotation.y = lerp_angle(current_rotation.y, target_rotation, delta * rotation_speed)
	
	if is_grabbing:
		anim_tree.set("parameters/IdlePushPull/blend_position", Vector2(direction.x,direction.z).normalized())
	else:
		anim_tree.set("parameters/IdleWalkRun/blend_position", (Vector2(direction.x,direction.z).normalized()) * (2 if is_running else 1))
		
	twist_input = 0.0
	pitch_input = 0.0
	

# Handle grab input
	if Input.is_action_just_pressed("grab"):
		if grabbed_object:
			release_object()
		else:
			try_grab_object()
	
	if grabbed_object and not Input.is_action_pressed("grab"):
		release_object()

	# Update animation conditions
	anim_tree.set("parameters/conditions/grounded", is_on_floor())
	#anim_tree.set("parameters/conditions/walk", is_on_floor() && input.length() > 0 && !is_running)
	#anim_tree.set("parameters/conditions/run", is_on_floor() && input.length() > 0 && is_running)
	anim_tree.set("parameters/conditions/jump", Input.is_action_just_pressed("jump") && is_on_floor())
	anim_tree.set("parameters/conditions/InAir", !is_on_floor())
	
	# Update grab prompt visibility
	update_grab_prompt()
	
	
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

# Add this new function to check for grab-able objects
func check_for_grab_objects() -> void:
	var space_state = get_world_3d().direct_space_state
	var camera = $TwistPivot/PitchPivot/Camera3D
	var from = camera.global_position
	var to = from + camera.global_transform.basis.z * -grab_range
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.exclude = [self]
	query.collision_mask = 1
	
	var result = space_state.intersect_ray(query)
	
	if result and not is_grabbing:
		var collider = result["collider"]
		if collider.has_method("grab"):
			can_grab_object = true
			current_grab_target = collider
			return
	
	can_grab_object = false
	current_grab_target = null

# Add this function to update the grab prompt
func update_grab_prompt() -> void:
	if grab_prompt_label:
		if can_grab_object and not is_grabbing and current_grab_target != null:
			grab_prompt_label.text = "Press [Grab] to grab"
			grab_prompt_label.show()
		else:
			grab_prompt_label.hide()

# Grab functionality
func try_grab_object() -> void:
	if current_grab_target and current_grab_target.has_method("grab"):
		grabbed_object = current_grab_target
		current_grab_target.grab(self)
		print("Grabbed object: ", current_grab_target.name)
		is_grabbing = true
		can_grab_object = false
		anim_tree.set("parameters/conditions/grabbing", is_grabbing)
		anim_tree.set("parameters/conditions/grounded", false)
		state_machine.travel("IdlePushPull")
	else:
		# Fallback to original method if no current target
		var space_state = get_world_3d().direct_space_state
		var camera = $TwistPivot/PitchPivot/Camera3D
		var from = camera.global_position
		var to = from + camera.global_transform.basis.z * -grab_range
		
		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.collide_with_areas = true
		query.exclude = [self]
		query.collision_mask = 1
		
		var result = space_state.intersect_ray(query)
		
		if result:
			var collider = result["collider"]
			if collider.has_method("grab"):
				grabbed_object = collider
				collider.grab(self)
				print("Grabbed object: ", collider.name)
				is_grabbing = true
				anim_tree.set("parameters/conditions/grabbing", is_grabbing)
				anim_tree.set("parameters/conditions/grounded", false)
				state_machine.travel("IdlePushPull")

func release_object() -> void:
	if grabbed_object and grabbed_object.has_method("release"):
		grabbed_object.release()
		print("Released object: ", grabbed_object.name)
		grabbed_object = null
		is_grabbing = false
		anim_tree.set("parameters/conditions/grabbing", is_grabbing)
		anim_tree.set("parameters/conditions/grounded", true)
		state_machine.travel("IdleWalkRun")

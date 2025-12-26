extends RigidBody3D

var mouse_sensitivity := 0.001
var twist_input := 0.0
var pitch_input := 0.0
var is_grabbing := false

@onready var twist_pivot := $TwistPivot
@onready var pitch_pivot := $TwistPivot/PitchPivot

var last_direction = Vector3.FORWARD
@export var rotation_speed = 8

@onready var state_machine = $LoFi_Magic_Temp_Character/AnimationTree.get("parameters/playback")
@onready var anim_tree = $LoFi_Magic_Temp_Character/AnimationTree

var grabbed_object: RigidBody3D = null
var grab_range: float = 1.3

@onready var grab_prompt_label = $GrabPromptLabel
var can_grab_object: bool = false
var current_grab_target: Node3D = null

var jump_count := 0
var max_jumps := 1

# Movement variables
var move_force = 600.0
var max_speed = 5.0
var jump_height_limit := 5.0
var is_above_jump_limit := false

# Jump physics
var jump_height: float = 5.0  # Desired jump height in units
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	freeze = false
	sleeping = false
	can_sleep = false
	continuous_cd = 1
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if grab_prompt_label:
		grab_prompt_label.hide()
	
	add_to_group("player")
	
	collision_layer = 0xFFFFFFFF
	collision_mask = 0xFFFFFFFF
	
	setup_collision_shape()

func setup_collision_shape() -> void:
	if not has_node("CollisionShape3D"):
		var collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		collision_shape.shape = CapsuleShape3D.new()
		collision_shape.shape.height = 1.8
		collision_shape.shape.radius = 0.4
		collision_shape.position = Vector3(0, 0.9, 0)
		add_child(collision_shape)

func _process(delta: float) -> void:
	freeze = false
	
	var input := Vector3.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.z = Input.get_axis("move_forward", "move_back")
	
	check_for_grab_objects()
	
	if is_grabbing and grabbed_object != null and abs(linear_velocity.y) > 0.5:
		release_object()
	
	twist_pivot.rotate_y(twist_input)
	pitch_pivot.rotate_x(pitch_input)
	pitch_pivot.rotation.x = clamp(pitch_pivot.rotation.x,
		deg_to_rad(-30),
		deg_to_rad(30)
	)
	
	var direction = ($TwistPivot.transform.basis * Vector3(input.x, 0, input.z)).normalized()
	
	if direction.length() > 0.1 and not is_grabbing:
		last_direction = direction
		var target_rotation = atan2(last_direction.x, last_direction.z)
		var current_rotation = $LoFi_Magic_Temp_Character.rotation
		$LoFi_Magic_Temp_Character.rotation.y = lerp_angle(current_rotation.y, target_rotation, delta * rotation_speed)
	
	if is_grabbing:
		anim_tree.set("parameters/IdlePushPull/blend_position", Vector2(input.x, input.z))
	else:
		anim_tree.set("parameters/IdleWalkRun/blend_position", Vector2(input.x, input.z))
	
	twist_input = 0.0
	pitch_input = 0.0

	if Input.is_action_just_pressed("grab"):
		if is_grabbing:
			release_object()
		else:
			try_grab_object()
	
	# Check ground height for jump limit
	var space_state = get_world_3d().direct_space_state
	var origin = global_position
	var end = origin + Vector3.DOWN * 100.0
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [self]
	query.collision_mask = 0xFFFFFFFF
	var result = space_state.intersect_ray(query)
	
	if !result.is_empty():
		var current_height = global_position.y - result.position.y
		is_above_jump_limit = current_height >= jump_height_limit
	else:
		is_above_jump_limit = false
	
	# Jump input
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_above_jump_limit:
		perform_jump()
		jump_count = 1

	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Reset jump count when on floor
	if is_on_floor():
		jump_count = 0
		is_above_jump_limit = false
	
	# Animation conditions
	anim_tree.set("parameters/conditions/grounded", is_on_floor())
	anim_tree.set("parameters/conditions/walk", is_on_floor() && input.length() > 0)
	anim_tree.set("parameters/conditions/jump", Input.is_action_just_pressed("jump") && is_on_floor())
	anim_tree.set("parameters/conditions/InAir", !is_on_floor())
	
	update_grab_prompt()

func _physics_process(delta: float) -> void:
	# Always ensure we're not frozen
	freeze = false
	sleeping = false
	
	# Get movement input
	var input := Vector3.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.z = Input.get_axis("move_forward", "move_back")
	
	# Normalize input for consistent speed in all directions
	if input.length() > 1.0:
		input = input.normalized()
	
	# Calculate movement direction based on camera
	var move_direction = twist_pivot.global_transform.basis * Vector3(input.x, 0, input.z)
	move_direction = move_direction.normalized()
	
	# Apply movement force (only if we have input)
	if input.length() > 0.1:
		# Get current horizontal velocity
		var current_horizontal_velocity = Vector3(linear_velocity.x, 0, linear_velocity.z)
		var target_horizontal_velocity = move_direction * max_speed
		
		# Calculate velocity difference
		var velocity_diff = target_horizontal_velocity - current_horizontal_velocity
		
		# Apply force to achieve target velocity
		var force = velocity_diff * move_force * delta
		apply_central_force(force)
	else:
		# Apply damping when no input
		var current_horizontal_velocity = Vector3(linear_velocity.x, 0, linear_velocity.z)
		if current_horizontal_velocity.length() > 0.1:
			var damping_force = -current_horizontal_velocity.normalized() * move_force * 0.5 * delta
			apply_central_force(damping_force)
	
	# Apply downward force when above jump limit
	if is_above_jump_limit and linear_velocity.y > 0:
		var downward_force = Vector3(0, -gravity * mass * 3.0, 0)
		apply_central_force(downward_force)

func perform_jump() -> void:
	if not is_on_floor() or is_above_jump_limit:
		return
	
	# Calculate the required initial velocity to reach jump_height
	# Using physics formula: v = sqrt(2 * g * h)
	var required_velocity = sqrt(2 * gravity * jump_height)
	
	# Set the vertical velocity directly for precise jump height
	# This ensures exactly 5 units jump height
	var current_vel = linear_velocity
	current_vel.y = required_velocity
	linear_velocity = current_vel
	
	is_above_jump_limit = false
	
func is_on_floor() -> bool:
	var space_state = get_world_3d().direct_space_state
	var origin = global_position
	var end = origin + Vector3.DOWN * 1.1
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [self]
	query.collision_mask = 0xFFFFFFFF
	var result = space_state.intersect_ray(query)
	return !result.is_empty()
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			twist_input = - event.relative.x * mouse_sensitivity
			pitch_input = - event.relative.y * mouse_sensitivity
	if event is InputEventMouseButton:
		if event.pressed and Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func check_for_grab_objects() -> void:
	var closest_object = null
	var closest_distance = grab_range
	
	var movable_objects = get_tree().get_nodes_in_group("movable")
	
	for node in movable_objects:
		if node != self and node.has_method("grab") and node.has_method("can_be_grabbed_by"):
			if node.can_be_grabbed_by(self):
				var distance = global_position.distance_to(node.global_position)
				if distance < closest_distance:
					closest_object = node
					closest_distance = distance
	
	if closest_object:
		can_grab_object = true
		current_grab_target = closest_object
	else:
		can_grab_object = false
		current_grab_target = null

func update_grab_prompt() -> void:
	if grab_prompt_label:
		if can_grab_object and not is_grabbing and current_grab_target != null:
			grab_prompt_label.text = "Press [E] to grab"
			grab_prompt_label.show()
		elif is_grabbing and grabbed_object != null:
			grab_prompt_label.text = "Press [E] to release"
			grab_prompt_label.show()
		else:
			grab_prompt_label.hide()

func try_grab_object() -> void:
	if current_grab_target != null and current_grab_target.has_method("grab"):
		if current_grab_target.has_method("can_be_grabbed_by") and current_grab_target.can_be_grabbed_by(self):
			grabbed_object = current_grab_target
			current_grab_target.grab(self)
			is_grabbing = true
			can_grab_object = false
			anim_tree.set("parameters/conditions/grabbing", is_grabbing)
			state_machine.travel("IdlePushPull")

func release_object() -> void:
	if grabbed_object and grabbed_object.has_method("release"):
		grabbed_object.release()
		grabbed_object = null
		is_grabbing = false
		anim_tree.set("parameters/conditions/grabbing", is_grabbing)
		anim_tree.set("parameters/conditions/grounded", true)
		state_machine.travel("IdleWalkRun")

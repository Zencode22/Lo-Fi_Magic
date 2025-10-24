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
var grab_range: float = 1.5

@onready var grab_prompt_label = $GrabPromptLabel
var can_grab_object: bool = false
var current_grab_target: Node3D = null

func _ready() -> void:
	sleeping = false
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
	var input := Vector3.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.z = Input.get_axis("move_forward", "move_back")
	
	check_for_grab_objects()
	
	is_running = Input.is_action_pressed("run")
	var move_speed_multiplier = 1.5
	if not is_running:
		move_speed_multiplier = 1.0
	var move_speed = default_movespeed * move_speed_multiplier
	
	apply_central_force(twist_pivot.basis * input * move_speed * delta)

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
			var look_direction = (grabbed_object.global_position - global_position).normalized()
			if look_direction.length() > 0.1:
				last_direction = Vector3(look_direction.x, 0, look_direction.z).normalized()
		else:
			last_direction = direction

		var target_rotation = atan2(last_direction.x, last_direction.z)
		var current_rotation = $LoFi_Magic_Temp_Character.rotation
		$LoFi_Magic_Temp_Character.rotation.y = lerp_angle(current_rotation.y, target_rotation, delta * rotation_speed)
	
	if is_grabbing:
		anim_tree.set("parameters/IdlePushPull/blend_position", Vector2(direction.x,direction.z).normalized())
	else:
		var blend_multiplier = 1
		if is_running:
			blend_multiplier = 2
		anim_tree.set("parameters/IdleWalkRun/blend_position", (Vector2(direction.x,direction.z).normalized()) * blend_multiplier)
		
	twist_input = 0.0
	pitch_input = 0.0

	# Toggle grab on key press - no need to hold the key
	if Input.is_action_just_pressed("grab"):
		if is_grabbing:
			release_object()
		else:
			try_grab_object()
	
	# Removed the continuous check for grab key release
	
	anim_tree.set("parameters/conditions/grounded", is_on_floor())
	anim_tree.set("parameters/conditions/walk", is_on_floor() && input.length() > 0 && !is_running)
	anim_tree.set("parameters/conditions/run", is_on_floor() && input.length() > 0 && is_running)
	anim_tree.set("parameters/conditions/jump", Input.is_action_just_pressed("jump") && is_on_floor())
	anim_tree.set("parameters/conditions/InAir", !is_on_floor())
	
	update_grab_prompt()
	
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
	
	# Add this section to recapture mouse when clicking
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
			anim_tree.set("parameters/conditions/grounded", false)
			state_machine.travel("IdlePushPull")

func release_object() -> void:
	if grabbed_object and grabbed_object.has_method("release"):
		grabbed_object.release()
		grabbed_object = null
		is_grabbing = false
		anim_tree.set("parameters/conditions/grabbing", is_grabbing)
		anim_tree.set("parameters/conditions/grounded", true)
		state_machine.travel("IdleWalkRun")

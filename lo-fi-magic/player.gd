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

var move_force = 600.0
var max_speed = 5.0
var jump_height_limit := 5.0
var is_above_jump_limit := false

var jump_height: float = 5.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var token_counter_label: Label
var gate2_token_label: Label  # Changed from gate1_token_label to gate2_token_label
var gate_message_label: Label

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
	setup_token_ui()

	var token_tracker = get_node("/root/TokenTracker")
	if token_tracker:
		token_tracker.token_collected_updated.connect(_on_token_collected_updated)
		token_tracker.all_tokens_collected.connect(_on_all_tokens_collected)

func setup_collision_shape() -> void:
	if not has_node("CollisionShape3D"):
		var collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		collision_shape.shape = CapsuleShape3D.new()
		collision_shape.shape.height = 1.8
		collision_shape.shape.radius = 0.4
		collision_shape.position = Vector3(0, 0.9, 0)
		add_child(collision_shape)

func setup_token_ui() -> void:
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "TokenCanvasLayer"
	canvas_layer.layer = 10
	add_child(canvas_layer)

	var control = Control.new()
	control.name = "TokenUIControl"
	canvas_layer.add_child(control)

	var vbox = VBoxContainer.new()
	vbox.name = "TokenVBox"
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 20
	vbox.offset_top = 20
	control.add_child(vbox)

	token_counter_label = Label.new()
	token_counter_label.name = "TokenCounterLabel"
	token_counter_label.text = "Gate 1: 0/4"  # Updated to show 0/4 initially
	token_counter_label.add_theme_font_size_override("font_size", 24)
	token_counter_label.add_theme_color_override("font_color", Color.WHITE)
	token_counter_label.add_theme_constant_override("outline_size", 4)
	token_counter_label.add_theme_color_override("font_outline_color", Color.BLACK)
	vbox.add_child(token_counter_label)

	gate2_token_label = Label.new()  # Changed to gate2_token_label
	gate2_token_label.name = "Gate2TokenLabel"
	gate2_token_label.text = "Gate 2: 0/6"  # Updated to show 0/6 initially
	gate2_token_label.add_theme_font_size_override("font_size", 24)
	gate2_token_label.add_theme_color_override("font_color", Color.CYAN)
	gate2_token_label.add_theme_constant_override("outline_size", 4)
	gate2_token_label.add_theme_color_override("font_outline_color", Color.BLACK)
	vbox.add_child(gate2_token_label)

	gate_message_label = Label.new()
	gate_message_label.name = "GateMessageLabel"
	gate_message_label.text = "Gate opened!"
	gate_message_label.add_theme_font_size_override("font_size", 32)
	gate_message_label.add_theme_color_override("font_color", Color.GREEN)
	gate_message_label.add_theme_constant_override("outline_size", 6)
	gate_message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	gate_message_label.hide()
	vbox.add_child(gate_message_label)

func _on_token_collected_updated(set_name: String, current: int, total: int) -> void:
	# Update the appropriate label based on the token set
	if set_name == "default":
		if token_counter_label:
			token_counter_label.text = "Gate 1: %d/%d" % [current, total]
			if current > 0:
				var tween = create_tween()
				tween.tween_property(token_counter_label, "scale", Vector2(1.3, 1.3), 0.1)
				tween.tween_property(token_counter_label, "scale", Vector2(1.0, 1.0), 0.1)
	elif set_name == "set_1":
		if gate2_token_label:  # Changed to gate2_token_label
			gate2_token_label.text = "Gate 2: %d/%d" % [current, total]
			if current > 0:
				var tween = create_tween()
				tween.tween_property(gate2_token_label, "scale", Vector2(1.3, 1.3), 0.1)
				tween.tween_property(gate2_token_label, "scale", Vector2(1.0, 1.0), 0.1)

func _on_all_tokens_collected(set_name: String) -> void:
	if gate_message_label:
		if set_name == "default":
			gate_message_label.text = "Gate 1 opened!"
		elif set_name == "set_1":
			gate_message_label.text = "Gate 2 opened!"
		
		gate_message_label.show()

		var tween = create_tween()
		tween.tween_property(gate_message_label, "modulate:a", 1.0, 0.5).from(0.0)
		tween.tween_property(gate_message_label, "scale", Vector2(1.2, 1.2), 0.3)
		tween.tween_property(gate_message_label, "scale", Vector2(1.0, 1.0), 0.3)
		tween.tween_interval(3.0)
		tween.tween_property(gate_message_label, "modulate:a", 0.0, 1.0)
		tween.tween_callback(gate_message_label.hide)

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

	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_above_jump_limit:
		perform_jump()
		jump_count = 1

	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if is_on_floor():
		jump_count = 0
		is_above_jump_limit = false

	anim_tree.set("parameters/conditions/grounded", is_on_floor())
	anim_tree.set("parameters/conditions/walk", is_on_floor() && input.length() > 0)
	anim_tree.set("parameters/conditions/jump", Input.is_action_just_pressed("jump") && is_on_floor())
	anim_tree.set("parameters/conditions/InAir", !is_on_floor())
	
	update_grab_prompt()

func _physics_process(delta: float) -> void:
	freeze = false
	sleeping = false

	var input := Vector3.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.z = Input.get_axis("move_forward", "move_back")

	if input.length() > 1.0:
		input = input.normalized()

	var move_direction = twist_pivot.global_transform.basis * Vector3(input.x, 0, input.z)
	move_direction = move_direction.normalized()

	if input.length() > 0.1:
		var current_horizontal_velocity = Vector3(linear_velocity.x, 0, linear_velocity.z)
		var target_horizontal_velocity = move_direction * max_speed

		var velocity_diff = target_horizontal_velocity - current_horizontal_velocity

		var force = velocity_diff * move_force * delta
		apply_central_force(force)
	else:
		var current_horizontal_velocity = Vector3(linear_velocity.x, 0, linear_velocity.z)
		if current_horizontal_velocity.length() > 0.1:
			var damping_force = -current_horizontal_velocity.normalized() * move_force * 0.5 * delta
			apply_central_force(damping_force)

	if is_above_jump_limit and linear_velocity.y > 0:
		var downward_force = Vector3(0, -gravity * mass * 3.0, 0)
		apply_central_force(downward_force)

func perform_jump() -> void:
	if not is_on_floor() or is_above_jump_limit:
		return

	var required_velocity = sqrt(2 * gravity * jump_height)

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

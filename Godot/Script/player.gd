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
var set2_token_label: Label
var gate_message_label: Label

var is_grounded := true
var ground_check_distance: float = 0.5

var can_jump := true
var jump_cooldown_timer: float = 0.0
var jump_cooldown_duration: float = 0.2

@onready var jump_sound = $LoFi_Magic_Temp_Character/FmodJumpEmitter3D
@onready var landing_sound = $LoFi_Magic_Temp_Character/FmodLandingEmitter3D
@onready var footstep_sound = $LoFi_Magic_Temp_Character/FmodFootstepEmitter3D
@onready var grab_sound = $LoFi_Magic_Temp_Character/FmodGrabEmitter3D

func _ready() -> void:
	freeze = false
	sleeping = false
	can_sleep = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if grab_prompt_label:
		grab_prompt_label.hide()
	
	add_to_group("player")
	
	collision_layer = 0xFFFFFFFF
	collision_mask = 0xFFFFFFFF
	
	setup_collision_shape()
	setup_token_ui()
	
	initialize_animations()

	var token_tracker = get_node("/root/TokenTracker")
	if token_tracker:
		token_tracker.token_collected_updated.connect(_on_token_collected_updated)
		token_tracker.all_tokens_collected.connect(_on_all_tokens_collected)
		
		if has_node("LoFi_Magic_Temp_Character/FmodMusicPlayer"):
			var music_player = $LoFi_Magic_Temp_Character/FmodMusicPlayer
			token_tracker.set_music_player("Set 1", music_player)
			token_tracker.set_music_player("Set 2", music_player)
			print("Music player connected successfully at: LoFi_Magic_Temp_Character/FmodMusicPlayer")
		else:
			print("FmodMusicPlayer not found at LoFi_Magic_Temp_Character/FmodMusicPlayer")

func initialize_animations() -> void:
	anim_tree.set("parameters/conditions/grounded", true)
	anim_tree.set("parameters/conditions/walk", false)
	anim_tree.set("parameters/conditions/jump", false)
	anim_tree.set("parameters/conditions/InAir", false)
	anim_tree.set("parameters/conditions/grabbing", false)

	state_machine.travel("IdleWalkRun")

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
	token_counter_label.text = "Set 1: 0/4"
	token_counter_label.add_theme_font_size_override("font_size", 24)
	token_counter_label.add_theme_color_override("font_color", Color.WHITE)
	token_counter_label.add_theme_constant_override("outline_size", 4)
	token_counter_label.add_theme_color_override("font_outline_color", Color.BLACK)
	vbox.add_child(token_counter_label)

	set2_token_label = Label.new()
	set2_token_label.name = "Set2TokenLabel"
	set2_token_label.text = "Set 2: 0/6"
	set2_token_label.add_theme_font_size_override("font_size", 24)
	set2_token_label.add_theme_color_override("font_color", Color.CYAN)
	set2_token_label.add_theme_constant_override("outline_size", 4)
	set2_token_label.add_theme_color_override("font_outline_color", Color.BLACK)
	vbox.add_child(set2_token_label)

	gate_message_label = Label.new()
	gate_message_label.name = "GateMessageLabel"
	gate_message_label.text = "Gate opened!"
	gate_message_label.add_theme_font_size_override("font_size", 32)
	gate_message_label.add_theme_color_override("font_color", Color.GREEN)
	gate_message_label.add_theme_constant_override("outline_size", 6)
	gate_message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	gate_message_label.hide()
	vbox.add_child(gate_message_label)

func _on_token_collected_updated(token_set: String, current: int, total: int) -> void:
	if token_set == "Set 1":
		if token_counter_label:
			token_counter_label.text = "Set 1: %d/%d" % [current, total]
			if current > 0:
				var tween = create_tween()
				tween.tween_property(token_counter_label, "scale", Vector2(1.3, 1.3), 0.1)
				tween.tween_property(token_counter_label, "scale", Vector2(1.0, 1.0), 0.1)
	elif token_set == "Set 2":
		if set2_token_label:
			set2_token_label.text = "Set 2: %d/%d" % [current, total]
			if current > 0:
				var tween = create_tween()
				tween.tween_property(set2_token_label, "scale", Vector2(1.3, 1.3), 0.1)
				tween.tween_property(set2_token_label, "scale", Vector2(1.0, 1.0), 0.1)

func _on_all_tokens_collected(token_set: String) -> void:
	if gate_message_label:
		if token_set == "Set 1":
			gate_message_label.text = "Set 1 Complete! Gate 1 opened!"
		elif token_set == "Set 2":
			gate_message_label.text = "Set 2 Complete! Gate 2 opened!"
		
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
		var move_intensity = input.length()
		anim_tree.set("parameters/IdlePushPull/blend_position", Vector2(move_intensity, 0))
	else:
		anim_tree.set("parameters/IdleWalkRun/blend_position", Vector2(input.x, input.z))
	
	twist_input = 0.0
	pitch_input = 0.0

	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if Input.is_action_just_pressed("grab"):
		if is_grabbing:
			release_object()
		else:
			try_grab_object()

	update_grab_prompt()

	if not can_jump:
		jump_cooldown_timer -= delta
		if jump_cooldown_timer <= 0:
			can_jump = true

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

	if input.length() > 0.1 and not is_grounded:
		var space_state_air = get_world_3d().direct_space_state
		var ray_origin = global_position
		
		var ray_heights = [0.0, 0.5, 1.0]
		var hit_wall = false
		var ray_distance = 0.6
		var wall_normal = Vector3.ZERO
		
		for height in ray_heights:
			var origin_offset = Vector3(0, height, 0)
			var ray_start = ray_origin + origin_offset
			var ray_end = ray_start + (move_direction * ray_distance)
			
			var ray_query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
			ray_query.exclude = [self]
			ray_query.collision_mask = 0xFFFFFFFF
			
			var ray_result = space_state_air.intersect_ray(ray_query)
			
			if not ray_result.is_empty():
				hit_wall = true
				wall_normal = ray_result.normal
				break
		
		if hit_wall:
			var current_horizontal_velocity = Vector3(linear_velocity.x, 0, linear_velocity.z)
			
			var damping_strength = 15.0
			var damping_force = -current_horizontal_velocity * damping_strength * mass * delta
			apply_central_force(damping_force)
			
			var push_away_force = wall_normal * mass * 2.0 * delta
			apply_central_force(push_away_force)
			
			pass
		else:
			var current_horizontal_velocity = Vector3(linear_velocity.x, 0, linear_velocity.z)
			var target_horizontal_velocity = move_direction * max_speed
			var velocity_diff = target_horizontal_velocity - current_horizontal_velocity
			var force = velocity_diff * move_force * delta
			apply_central_force(force)
	
	elif input.length() > 0.1 and is_grounded:
		var current_horizontal_velocity = Vector3(linear_velocity.x, 0, linear_velocity.z)
		var target_horizontal_velocity = move_direction * max_speed
		var velocity_diff = target_horizontal_velocity - current_horizontal_velocity
		var force = velocity_diff * move_force * delta
		apply_central_force(force)
	
	else:
		var current_horizontal_velocity = Vector3(linear_velocity.x, 0, linear_velocity.z)
		if current_horizontal_velocity.length() > 0.1:
			var damping_force = -current_horizontal_velocity.normalized() * move_force * 0.8 * delta
			apply_central_force(damping_force)

	var new_grounded = check_grounded()

	if new_grounded and not is_grounded:
		is_grounded = true
		if landing_sound and linear_velocity.y < -2.0:
			landing_sound.play()
		
		can_jump = false
		jump_cooldown_timer = jump_cooldown_duration
		jump_count = 0
		is_above_jump_limit = false
	elif not new_grounded and is_grounded:
		is_grounded = false

	if Input.is_action_just_pressed("jump") and is_grounded and not is_above_jump_limit and can_jump:
		perform_jump()
		jump_sound.play()
		can_jump = false

	var space_state_height = get_world_3d().direct_space_state
	var height_origin = global_position
	var height_end = height_origin + Vector3.DOWN * 100.0
	var height_query = PhysicsRayQueryParameters3D.create(height_origin, height_end)
	height_query.exclude = [self]
	height_query.collision_mask = 0xFFFFFFFF
	var height_result = space_state_height.intersect_ray(height_query)
	
	if !height_result.is_empty():
		var current_height = global_position.y - height_result.position.y
		is_above_jump_limit = current_height >= jump_height_limit
	else:
		is_above_jump_limit = false

	if not is_grabbing:
		anim_tree.set("parameters/conditions/grounded", is_grounded)
		anim_tree.set("parameters/conditions/walk", is_grounded and input.length() > 0)
		anim_tree.set("parameters/conditions/InAir", not is_grounded)
	
	if is_above_jump_limit and linear_velocity.y > 0:
		var downward_force = Vector3(0, -gravity * mass * 3.0, 0)
		apply_central_force(downward_force)

func check_grounded() -> bool:
	var space_state = get_world_3d().direct_space_state

	var ray_offsets = [
		Vector3(0, 0, 0),
		Vector3(0.2, 0, 0),
		Vector3(-0.2, 0, 0),
		Vector3(0, 0, 0.2),
		Vector3(0, 0, -0.2)
	]
	
	var ray_distance = 0.5
	var max_ground_distance = 0.3
	
	for offset in ray_offsets:
		var ray_origin = global_position + offset
		var ray_end = ray_origin + Vector3.DOWN * ray_distance
		
		var ray_query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		ray_query.exclude = [self]
		ray_query.collision_mask = 0xFFFFFFFF
		
		var ray_result = space_state.intersect_ray(ray_query)
		
		if not ray_result.is_empty():
			var floor_normal = ray_result.normal
			var floor_angle = floor_normal.angle_to(Vector3.UP)
			var max_slope_angle = deg_to_rad(45)

			if floor_angle <= max_slope_angle:
				var distance_to_ground = global_position.y - ray_result.position.y
				if distance_to_ground <= max_ground_distance:
					return true
	
	return false

func perform_jump() -> void:
	if not is_grounded or is_above_jump_limit or not can_jump:
		return

	var required_velocity = sqrt(2 * gravity * jump_height)
 
	var current_vel = linear_velocity
	current_vel.y = required_velocity
	linear_velocity = current_vel
	
	is_above_jump_limit = false
	
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
			grab_sound.play()
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
			
func get_surface_index() -> int:
	var space_state = get_world_3d().direct_space_state
	var ray_start = global_position
	var ray_end = ray_start + Vector3.DOWN *1.5
	
	var query = PhysicsRayQueryParameters3D.create(ray_start,ray_end)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	
	if result.is_empty():
		return 0
	
	var collider = result.collider
	if collider and collider.has_meta("SurfaceIndex"):
		return collider.get_meta("SurfaceIndex")
	
	return 0
	
func play_footstep():
	if not is_grounded:
		return
	var surface_index = get_surface_index()
	if footstep_sound:
		footstep_sound.set_parameter("SurfaceIndex", surface_index)
		footstep_sound.play()

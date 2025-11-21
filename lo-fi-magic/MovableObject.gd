extends RigidBody3D

var is_grabbed: bool = false
var grabber: Node3D = null
var grab_point: Vector3 = Vector3.ZERO
var grab_distance: float = 1.3
var grab_force: float = 80.0
var grab_angular_damp: float = 8.0

var players_in_contact: Array[Node3D] = []

var original_linear_damp: float = 0.0
var original_angular_damp: float = 0.0

var player_has_moved: bool = false
var last_player_position: Vector3 = Vector3.ZERO
var last_player_rotation: Basis = Basis.IDENTITY

var ground_height: float = 0.0
var object_height: float = 1.0
var stay_on_ground: bool = true

var grab_allowed_angle: float = 0.5
var grab_side: Vector3 = Vector3.BACK

func _ready() -> void:
	sleeping = false
	freeze = true
	can_sleep = false
	original_linear_damp = linear_damp
	original_angular_damp = angular_damp
	
	collision_layer = 0xFFFFFFFF
	collision_mask = 0xFFFFFFFF
	
	add_to_group("movable")
	calculate_object_height()

func calculate_object_height() -> void:
	var collision_shape = get_node_or_null("CollisionShape3D")
	if collision_shape and collision_shape.shape:
		if collision_shape.shape is BoxShape3D:
			object_height = collision_shape.shape.size.y
		elif collision_shape.shape is SphereShape3D:
			object_height = collision_shape.shape.radius * 2
		elif collision_shape.shape is CapsuleShape3D:
			object_height = collision_shape.shape.height
		else:
			object_height = 1.0

func _physics_process(delta: float) -> void:
	if is_grabbed and grabber:
		if grabber.grabbed_object == self:
			if freeze:
				freeze = false

			if last_player_position == Vector3.ZERO:
				last_player_position = grabber.global_position
				return
			
			var input_dir = Vector3.ZERO
			if grabber.has_method("get_movement_input"):
				input_dir = grabber.get_movement_input()
			
			var player_movement = grabber.global_position - last_player_position
			var player_moved = player_movement.length() > 0.001
			
			if input_dir.length() > 0.1:
				var world_input_dir = grabber.global_transform.basis * input_dir
				
				var target_velocity = world_input_dir * 5.0
				var current_velocity = linear_velocity
				
				var velocity_difference = Vector3(target_velocity.x - current_velocity.x, 0, target_velocity.z - current_velocity.z)
				var force = velocity_difference * mass * grab_force * delta
				
				apply_central_force(force)
			elif player_moved:
				# FIXED: Use player's forward direction (basis.z) instead of backward (-basis.z)
				var player_forward = grabber.global_transform.basis.z
				var target_position = grabber.global_position + player_forward * grab_distance
				
				if stay_on_ground:
					target_position.y = get_ground_height_at_position(target_position) + (object_height / 2)
				else:
					target_position.y = grabber.global_position.y + 0.5
				
				var desired_movement = target_position - global_position
				
				if desired_movement.length() > 0.01:
					var target_velocity = desired_movement / delta
					var current_velocity = linear_velocity

					var velocity_difference = target_velocity - current_velocity
					var force = velocity_difference * mass
					
					if stay_on_ground:
						force.y = 0
					
					apply_central_force(force)
			
			last_player_position = grabber.global_position

			angular_velocity = angular_velocity.lerp(Vector3.ZERO, grab_angular_damp * delta)
			
			if input_dir.length() <= 0.1 and !player_moved:
				linear_velocity.x = lerp(linear_velocity.x, 0.0, linear_damp * delta)
				linear_velocity.z = lerp(linear_velocity.z, 0.0, linear_damp * delta)
			
			if stay_on_ground:
				var current_ground_height = get_ground_height_at_position(global_position)
				var height_above_ground = global_position.y - (current_ground_height + object_height / 2)
				
				if abs(height_above_ground) > 0.05:
					var vertical_force = Vector3(0, -height_above_ground * mass * 20.0, 0)
					apply_central_force(vertical_force)
		else:
			release()

func grab(by: Node3D) -> void:
	if not is_grabbed and by != null:
		var distance = global_position.distance_to(by.global_position)
		var in_proximity = distance < 1.3
		var can_grab = false
		
		if players_in_contact.has(by) or in_proximity:
			can_grab = true
		
		if can_grab:
			is_grabbed = true
			grabber = by
			freeze = false
			can_sleep = false

			last_player_position = Vector3.ZERO
			last_player_rotation = Basis.IDENTITY

			grab_point = global_position
			
			linear_damp = 2.0
			angular_damp = 6.0

func can_be_grabbed_by(player: Node3D) -> bool:
	if player is RigidBody3D:
		if abs(player.linear_velocity.y) > 0.5:
			return false
	
	var distance = global_position.distance_to(player.global_position)
	var in_proximity = distance < 1.3
	var can_grab_from_correct_side = is_player_on_allowed_side(player)
	var can_grab = false
	
	if not is_grabbed and can_grab_from_correct_side:
		if players_in_contact.has(player) or in_proximity:
			can_grab = true
	return can_grab

func is_player_on_allowed_side(player: Node3D) -> bool:
	var to_player = (player.global_position - global_position).normalized()
	var world_allowed_side = global_transform.basis * grab_side
	var dot_product = to_player.dot(world_allowed_side)

	return dot_product > grab_allowed_angle

func get_ground_height_at_position(_pos: Vector3) -> float:
	var space_state = get_world_3d().direct_space_state
	var origin = Vector3(_pos.x, _pos.y + 10.0, _pos.z)
	var end = Vector3(_pos.x, _pos.y - 10.0, _pos.z)
	
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [self]
	query.collision_mask = 1
	
	var result = space_state.intersect_ray(query)
	if result:
		return result.position.y
	else:
		return _pos.y 

func release() -> void:
	if is_grabbed:
		is_grabbed = false
		grabber = null
		freeze = true
		can_sleep = true
		player_has_moved = false
		linear_damp = original_linear_damp
		angular_damp = original_angular_damp
		last_player_position = Vector3.ZERO
		last_player_rotation = Basis.IDENTITY

func set_stay_on_ground(should_stay: bool) -> void:
	stay_on_ground = should_stay

func set_grab_side(side: Vector3) -> void:
	grab_side = side.normalized()

func set_grab_angle_threshold(threshold: float) -> void:
	grab_allowed_angle = clamp(threshold, 0.0, 1.0)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if not players_in_contact.has(body):
			players_in_contact.append(body)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		if players_in_contact.has(body):
			players_in_contact.erase(body)

extends RigidBody3D

var is_grabbed: bool = false
var grabber: Node3D = null
var local_grab_offset: Vector3 = Vector3.ZERO

var players_in_contact: Array[Node3D] = []

func _ready() -> void:
	sleeping = false
	freeze = true
	can_sleep = false
	
	collision_layer = 0xFFFFFFFF
	collision_mask = 0xFFFFFFFF
	
	add_to_group("movable")

func _physics_process(delta: float) -> void:
	if is_grabbed and grabber:
		if grabber.grabbed_object == self:
			if freeze:
				freeze = false
			
			# Calculate where the object should be relative to the player
			var current_player_basis = grabber.global_transform.basis
			var target_position = grabber.global_position + (current_player_basis * local_grab_offset)
			
			# Smoothly move toward target position for natural feel
			var move_speed = 15.0
			var new_position = global_position.lerp(target_position, move_speed * delta)
			global_position = new_position
			
			# Apply small damping to prevent wild movement
			linear_velocity = linear_velocity.lerp(Vector3.ZERO, 10.0 * delta)
			angular_velocity = angular_velocity.lerp(Vector3.ZERO, 10.0 * delta)
		else:
			release()

func grab(by: Node3D) -> void:
	if not is_grabbed and by != null:
		var can_grab = players_in_contact.has(by) or global_position.distance_to(by.global_position) < 2.0
		
		if can_grab:
			is_grabbed = true
			grabber = by
			freeze = false
			can_sleep = false
			
			# Calculate offset from player - this determines both push and pull position
			var initial_player_basis = by.global_transform.basis
			var world_offset = global_position - by.global_position
			local_grab_offset = initial_player_basis.inverse() * world_offset
			
			# Set a consistent grab distance for both push and pull
			# This will make the object stay at a fixed distance from player
			var grab_distance = 1.5
			local_grab_offset = local_grab_offset.normalized() * grab_distance

func can_be_grabbed_by(player: Node3D) -> bool:
	var distance = global_position.distance_to(player.global_position)
	return not is_grabbed and (players_in_contact.has(player) or distance < 2.0)

func release() -> void:
	if is_grabbed:
		is_grabbed = false
		grabber = null
		freeze = true
		can_sleep = true
		local_grab_offset = Vector3.ZERO

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if not players_in_contact.has(body):
			players_in_contact.append(body)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		if players_in_contact.has(body):
			players_in_contact.erase(body)

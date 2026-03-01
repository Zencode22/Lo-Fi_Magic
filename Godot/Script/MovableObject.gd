extends RigidBody3D

var is_grabbed: bool = false
var grabber: Node3D = null
var local_grab_offset: Vector3 = Vector3.ZERO

var players_in_contact: Array[Node3D] = []

var previous_position: Vector3
var movement_threshold := 0.02
var stop_threshold := 0.015
var is_drag_sound_playing := false

@onready var drag_emitter = $FmodDragEmitter3D

func _ready() -> void:
	sleeping = false
	freeze = true
	can_sleep = false
	
	collision_layer = 0xFFFFFFFF
	collision_mask = 0xFFFFFFFF
	previous_position = global_position
	add_to_group("movable")

func _physics_process(delta: float) -> void:
	if is_grabbed and grabber:
		if grabber.grabbed_object == self:
			if freeze:
				freeze = false
			
			var current_player_basis = grabber.global_transform.basis
			var target_position = grabber.global_position + (current_player_basis * local_grab_offset)
			
			var move_speed = 15.0
			var new_position = global_position.lerp(target_position, move_speed * delta)
			global_position = new_position
			
			linear_velocity = linear_velocity.lerp(Vector3.ZERO, 10.0 * delta)
			angular_velocity = angular_velocity.lerp(Vector3.ZERO, 10.0 * delta)
			
		else:
			release()
	_handle_drag_audio(delta)
	
func grab(by: Node3D) -> void:
	if not is_grabbed and by != null:
		var can_grab = players_in_contact.has(by) or global_position.distance_to(by.global_position) < 2.0
		
		if can_grab:
			is_grabbed = true
			grabber = by
			freeze = false
			can_sleep = false
			
			var initial_player_basis = by.global_transform.basis
			var world_offset = global_position - by.global_position
			local_grab_offset = initial_player_basis.inverse() * world_offset
			
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
		if is_drag_sound_playing:
			drag_emitter.stop()
			is_drag_sound_playing = false

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if not players_in_contact.has(body):
			players_in_contact.append(body)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		if players_in_contact.has(body):
			players_in_contact.erase(body)
			
func _handle_drag_audio(delta: float) -> void:
	var displacement = global_position.distance_to(previous_position)
	var speed = displacement / delta
	
	previous_position = global_position
	
	if is_grabbed and speed > movement_threshold:
		if not is_drag_sound_playing:
			drag_emitter.play()
			is_drag_sound_playing = true
	
	elif not is_grabbed or speed < stop_threshold:
		if is_drag_sound_playing:
			drag_emitter.stop()
			is_drag_sound_playing = false

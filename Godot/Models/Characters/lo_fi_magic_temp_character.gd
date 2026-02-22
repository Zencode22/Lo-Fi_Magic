extends Node3D
func play_footstep():
	var player = get_parent()
	if player and player.has_method("play_footstep"):
		player.play_footstep()
		

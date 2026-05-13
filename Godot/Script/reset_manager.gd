extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			reset_game()

func reset_game() -> void:
	var token_tracker = get_node("/root/TokenTracker")
	if token_tracker:
		token_tracker.full_reset()
	
	var music_manager = get_node("/root/MusicManager")
	if music_manager:
		music_manager.token_count = 0
	
	get_tree().reload_current_scene()

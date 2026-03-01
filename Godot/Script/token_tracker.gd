extends Node

signal all_tokens_collected(token_set: String)
signal token_collected_updated(token_set: String, current: int, total: int)
signal music_layer_activated(token_set: String, layer_name: String, layer_value: float)

var token_sets := {
	"Set 1": {
		"total": 0,
		"collected": 0,
		"stack": [],
		"layers": {},
		"music_player": null,
		"master_volume_param": "Volume_Set1"
	},
	"Set 2": {
		"total": 0,
		"collected": 0,
		"stack": [],
		"layers": {},
		"music_player": null,
		"master_volume_param": "Volume_Set2"
	}
}

const BACKGROUND_MUSIC_EVENT = "event:/Music/BackgroundLoop"

func register_token(token_set: String, token_node = null) -> void:
	if not token_sets.has(token_set):
		token_sets[token_set] = {
			"total": 0, 
			"collected": 0,
			"stack": [],
			"layers": {},
			"music_player": null,
			"master_volume_param": "Volume_" + token_set.replace(" ", "")
		}
	
	token_sets[token_set].total += 1
	if token_node:
		token_sets[token_set].stack.append(token_node)
	
	token_collected_updated.emit(token_set, token_sets[token_set].collected, token_sets[token_set].total)

func get_stack_position(token_set: String, token_node) -> int:
	if token_sets.has(token_set):
		return token_sets[token_set].stack.find(token_node)
	return -1

func set_music_player(token_set: String, player_node) -> void:
	if token_sets.has(token_set):
		token_sets[token_set].music_player = player_node
		
		if player_node and not player_node.is_playing:
			player_node.background_music_event = BACKGROUND_MUSIC_EVENT
			player_node.play_background_music()

func collect_token(token_set: String, _stack_position: int = -1, layer_name: String = "", fmod_parameter: String = "") -> void:
	if not token_sets.has(token_set):
		return
	
	var set_data = token_sets[token_set]
	
	if layer_name != "" and fmod_parameter != "":
		set_data.layers[layer_name] = {
			"enabled": true,
			"parameter": fmod_parameter,
			"value": 1.0
		}
		
		if set_data.music_player:
			set_data.music_player.activate_layer(fmod_parameter, 1.0)
		
		music_layer_activated.emit(token_set, layer_name, 1.0)
	
	set_data.collected += 1
	token_collected_updated.emit(token_set, set_data.collected, set_data.total)
	
	update_master_volume(token_set)
	
	if set_data.collected >= set_data.total:
		all_tokens_collected.emit(token_set)

func update_master_volume(token_set: String) -> void:
	var set_data = token_sets[token_set]
	if not set_data.music_player:
		return
	
	var progress = float(set_data.collected) / float(set_data.total)
	var volume_value = progress
	
	set_data.music_player.set_parameter(set_data.master_volume_param, volume_value)

func get_collected_count(token_set: String) -> int:
	if token_sets.has(token_set):
		return token_sets[token_set].collected
	return 0

func get_total_count(token_set: String) -> int:
	if token_sets.has(token_set):
		return token_sets[token_set].total
	return 0

func reset_token_set(token_set: String) -> void:
	if token_sets.has(token_set):
		var set_data = token_sets[token_set]
		
		for layer_data in set_data.layers.values():
			if set_data.music_player:
				set_data.music_player.activate_layer(layer_data.parameter, 0.0)
		
		set_data.collected = 0
		set_data.layers.clear()
		set_data.stack.clear()
		
		update_master_volume(token_set)
		
		token_collected_updated.emit(token_set, 0, set_data.total)

extends Node

signal all_tokens_collected(set_name: String)
signal token_collected_updated(set_name: String, current: int, total: int)

var token_sets := {
	"default": {
		"total": 0,
		"collected": 0
	},
	"set_1": {
		"total": 0,
		"collected": 0
	}
}

func register_token(set_name: String = "default") -> void:
	if not token_sets.has(set_name):
		token_sets[set_name] = {"total": 0, "collected": 0}
	
	token_sets[set_name].total += 1
	token_collected_updated.emit(set_name, token_sets[set_name].collected, token_sets[set_name].total)

func collect_token(set_name: String = "default") -> void:
	if not token_sets.has(set_name):
		return
	
	token_sets[set_name].collected += 1
	token_collected_updated.emit(set_name, token_sets[set_name].collected, token_sets[set_name].total)
	
	if token_sets[set_name].collected >= token_sets[set_name].total:
		all_tokens_collected.emit(set_name)

func get_collected_count(set_name: String = "default") -> int:
	if token_sets.has(set_name):
		return token_sets[set_name].collected
	return 0

func get_total_count(set_name: String = "default") -> int:
	if token_sets.has(set_name):
		return token_sets[set_name].total
	return 0

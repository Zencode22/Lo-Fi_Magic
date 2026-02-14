extends Node

signal all_tokens_collected(token_set: String)
signal token_collected_updated(token_set: String, current: int, total: int)

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

func register_token(token_set: String = "default") -> void:
	if not token_sets.has(token_set):
		token_sets[token_set] = {"total": 0, "collected": 0}
	
	token_sets[token_set].total += 1
	token_collected_updated.emit(token_set, token_sets[token_set].collected, token_sets[token_set].total)

func collect_token(token_set: String = "default") -> void:
	if not token_sets.has(token_set):
		return
	
	token_sets[token_set].collected += 1
	token_collected_updated.emit(token_set, token_sets[token_set].collected, token_sets[token_set].total)
	
	if token_sets[token_set].collected >= token_sets[token_set].total:
		all_tokens_collected.emit(token_set)

func get_collected_count(token_set: String = "default") -> int:
	if token_sets.has(token_set):
		return token_sets[token_set].collected
	return 0

func get_total_count(token_set: String = "default") -> int:
	if token_sets.has(token_set):
		return token_sets[token_set].total
	return 0

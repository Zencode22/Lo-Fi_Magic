extends Node

signal all_tokens_collected
signal token_collected_updated(current: int, total: int)

var total_tokens := 0
var collected_tokens := 0

func register_token() -> void:
	total_tokens += 1
	token_collected_updated.emit(collected_tokens, total_tokens)

func collect_token() -> void:
	collected_tokens += 1
	token_collected_updated.emit(collected_tokens, total_tokens)
	if collected_tokens >= total_tokens:
		all_tokens_collected.emit()

extends Node
var token_count := 0
var music_player = null

func set_music_player(player):
	music_player = player

func add_token():

	token_count += 1

	#print("TOKEN COUNT: ", token_count)

	if music_player:
		music_player.set_parameter("Token Count", token_count)

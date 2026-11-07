class_name Sfx
extends Node
## Efectos de sonido: pool de players. Los .wav se generan con tools/gen_sfx.py.

const NAMES := ["shot", "empty", "kill", "headshot", "clank", "hurt", "boing", "chest_hit", "chest_open",
	"pickup", "powerup", "screech", "squeak", "chomp", "game_over", "land", "slowmo", "flap", "explosion", "engine"]
const POOL := 14

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var played: Array[String] = [] # últimos sonidos (para los tests)


func _ready() -> void:
	for n in NAMES:
		var s = load("res://assets/sfx/%s.wav" % n)
		if s:
			_streams[n] = s
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


## pitch_jitter: variación random de tono (± fracción) para que no suene repetido.
func play(sound: String, volume_db := 0.0, pitch := 1.0, pitch_jitter := 0.06) -> void:
	played.append(sound)
	if played.size() > 32:
		played.pop_front()
	if not _streams.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = _streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_jitter, pitch_jitter))
	p.play()

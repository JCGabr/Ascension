extends Node

var sfx_library = {
	"submarine": preload("res://audio/submarine.mp3"),
	"sonar_ping-1": preload("res://audio/submarine-sonar-1.mp3"),
	"sonar_ping_2": preload("res://audio/submarine-sonar-2.mp3"),
	"alarma_inmersion": preload("res://audio/submarine-submersion-alarm.mp3"),
	"monster-roar": preload("res://audio/monster-roar-deep-sea.mp3"),
}

var ambient_library = {
	"underwater_deep": preload("res://audio/deep-sea.mp3"),
	"cinematic-sound": preload("res://audio/cinematic-soundscape.mp3"),
}
var sfx_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer

func _ready():
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "SFX"
	add_child(sfx_player)

	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = "Ambiente"
	add_child(ambient_player)


func play_sfx(sound_name: String) -> void:
	if sfx_library.has(sound_name):
		sfx_player.stream = sfx_library[sound_name]
		sfx_player.play()
	else:
		push_warning("AudioManager: SFX '%s' no encontrado" % sound_name)


func play_ambient(sound_name: String, loop: bool = true) -> void:
	if not ambient_library.has(sound_name):
		push_warning("AudioManager: Ambiente '%s' no encontrado" % sound_name)
		return
	var stream = ambient_library[sound_name]
	stream.loop = loop
	ambient_player.stream = stream
	ambient_player.play()


func stop_ambient() -> void:
	ambient_player.stop()
	
func set_bus_volume(bus_name: String, valor_0_a_100: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		push_warning("Bus '%s' no existe" % bus_name)
		return
	var db = linear_to_db(valor_0_a_100 / 100.0)
	AudioServer.set_bus_volume_db(idx, db)

func mute_bus(bus_name: String, mute: bool) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_mute(idx, mute)

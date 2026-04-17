extends Node

var musicPlayer: AudioStreamPlayer
var sfxPlayer: AudioStreamPlayer

var masterVolume: float = 0.5
var musicVolume: float = 0.5
var sfxVolume: float = 0.5

# Music tracks — fill in your file paths
const MUSIC = {
	"menu":         preload("res://audio/music/Peachtea - Somewhere in the Elevator.wav"),
	"level_select": preload("res://audio/music/8bit Bossa.mp3"),
	"1-1":          preload("res://audio/music/Slow Stride Loop.ogg"),
	"2-1":          preload("res://audio/music/caravan.ogg.ogg"),
	"3-1":          preload("res://audio/music/lo-fi_fall.mp3"),
	"4-1":          preload("res://audio/music/lord_of_the_mountain.mp3"),
	"4-2":          preload("res://audio/music/Peachtea - Somewhere in the Elevator.wav"),
}

# SFX — fill in your file paths
const SFX = {
	"task_complete":  preload("res://audio/sfx/656393__nikos34__select.wav"),
	"code_run":       preload("res://audio/sfx/vgmenuselect.wav"),
	"swap":           preload("res://audio/sfx/733021__geoff-bremner-audio__whip-6.wav"),
	"error":          preload("res://audio/sfx/242503__gabrielaraujo__failurewrong-action.wav"),
	"level_complete": preload("res://audio/sfx/705174__digimistic__game-menu-select-sound-2.wav"),
	"jump":           preload("res://audio/sfx/264828__cmdrobot__text-message-or-videogame-jump.ogg"),
	"coin":           preload("res://audio/sfx/320181__dland__hint.wav"),
}

func _ready():
	musicPlayer = AudioStreamPlayer.new()
	musicPlayer.bus = "Music"
	musicPlayer.volume_db = 0.0
	add_child(musicPlayer)

	sfxPlayer = AudioStreamPlayer.new()
	sfxPlayer.bus = "SFX"
	add_child(sfxPlayer)

func playMusic(key: String):
	if not MUSIC.has(key):
		push_warning("[AudioManager] No music track for key: " + key)
		return
	# Don't restart if already playing this track
	if musicPlayer.stream == MUSIC[key] and musicPlayer.playing:
		return
	musicPlayer.stream = MUSIC[key]
	musicPlayer.play()

func stopMusic():
	musicPlayer.stop()

func playSFX(key: String):
	if not SFX.has(key):
		push_warning("[AudioManager] No SFX for key: " + key)
		return
	sfxPlayer.stream = SFX[key]
	sfxPlayer.play()

func setMusicVolume(linear: float):
	musicVolume = linear
	musicPlayer.volume_db = linear_to_db(linear)

func setSFXVolume(linear: float):
	sfxVolume = linear
	sfxPlayer.volume_db = linear_to_db(linear)

func setMasterVolume(linear: float):
	masterVolume = linear
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(linear))

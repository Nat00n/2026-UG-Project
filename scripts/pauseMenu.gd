extends CanvasLayer # Pause Menu Script
# Pause overlay with resume, settings (volume sliders), leaderboard display and navigation shortcuts to level select and the start menu
# PROCESS_MODE_ALWAYS ensures the menu responds to input even when the tree is paused
 
@onready var resumeButton: Button = $Control/HBoxContainer/LeftHalf/CenterContainer/VBoxContainer/ResumeButton
@onready var settingsButton: Button = $Control/HBoxContainer/LeftHalf/CenterContainer/VBoxContainer/SettingsButton
@onready var quitButton: Button = $Control/HBoxContainer/LeftHalf/CenterContainer/VBoxContainer/QuitButton
@onready var settingsPanel: PanelContainer = $Control/HBoxContainer/LeftHalf/CenterContainer/VBoxContainer/SettingsPanel
@onready var masterVolumeSlider: HSlider = $Control/HBoxContainer/LeftHalf/CenterContainer/VBoxContainer/SettingsPanel/VBoxContainer/MasterVolumeSlider
@onready var musicVolumeSlider: HSlider = $Control/HBoxContainer/LeftHalf/CenterContainer/VBoxContainer/SettingsPanel/VBoxContainer/MusicVolumeSlider
@onready var sfxVolumeSlider: HSlider = $Control/HBoxContainer/LeftHalf/CenterContainer/VBoxContainer/SettingsPanel/VBoxContainer/SFXVolumeSlider
@onready var settingsBackButton: Button = $Control/HBoxContainer/LeftHalf/CenterContainer/VBoxContainer/SettingsPanel/VBoxContainer/SettingsBackButton
@onready var leaderboardBox: VBoxContainer = $Control/HBoxContainer/RightHalf/CenterContainer/LeaderboardContainer/leaderboardBox
@onready var levelSelectButton: Button = $Control/HBoxContainer/LeftHalf/CenterContainer/VBoxContainer/LevelSelectButton
 
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keep processing while game is paused
	settingsPanel.visible = false
	hide()
 
	resumeButton.pressed.connect(onResume)
	settingsButton.pressed.connect(onSettings)
	quitButton.pressed.connect(onQuit)
	settingsBackButton.pressed.connect(onSettingsBack)
	levelSelectButton.pressed.connect(onLevelSelect)
 
	# Configure sliders with 0–1 range and apply sensible defaults immediately
	for slider in [masterVolumeSlider, musicVolumeSlider, sfxVolumeSlider]:
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
	masterVolumeSlider.value = AudioManager.masterVolume
	musicVolumeSlider.value = AudioManager.musicVolume
	sfxVolumeSlider.value = AudioManager.sfxVolume
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(0.5))
	AudioManager.setMusicVolume(0.5)
	AudioManager.setSFXVolume(0.5)
 
	masterVolumeSlider.value_changed.connect(onMasterVolumeChanged)
	musicVolumeSlider.value_changed.connect(onMusicVolumeChanged)
	sfxVolumeSlider.value_changed.connect(onSFXVolumeChanged)
 
	await get_tree().process_frame
	Global.populateLeaderboard(leaderboardBox)
 
func _exit_tree():
	Global.cancelLeaderboard()
 
func _input(event):
	# Toggle pause with the Escape key from anywhere
	if event.is_action_pressed("escape"):
		if visible:
			onResume()
		else:
			openPause()
 
func openPause():
	show()
	get_tree().paused = true
	Global.populateLeaderboard(leaderboardBox)
 
func onResume():
	hide()
	get_tree().paused = false
 
func _setMainButtonsVisible(value: bool):
	resumeButton.visible = value
	settingsButton.visible = value
	quitButton.visible = value
	levelSelectButton.visible = value
 
func onSettings():
	_setMainButtonsVisible(false)
	settingsPanel.visible = true
 
func onSettingsBack():
	settingsPanel.visible = false
	_setMainButtonsVisible(true)
 
func onQuit():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/StartMenu.tscn")
 
func onLevelSelect():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/LevelSelectionScreen.tscn")
 
func onMasterVolumeChanged(value: float):
	AudioManager.setMasterVolume(value)
 
func onMusicVolumeChanged(value: float):
	AudioManager.setMusicVolume(value)
 
func onSFXVolumeChanged(value: float):
	AudioManager.setSFXVolume(value)

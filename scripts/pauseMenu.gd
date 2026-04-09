extends CanvasLayer

@onready var resumeButton: Button = $Control/HBoxContainer/LeftHalf/CenterContainer/VBoxContainer/ResumeButton
@onready var settingsButton: Button = $Control/HBoxContainer/LeftHalf/CenterContainer/VBoxContainer/SettingsButton
@onready var quitButton: Button = $Control/HBoxContainer/LeftHalf/CenterContainer/VBoxContainer/QuitButton
@onready var settingsPanel: PanelContainer = $Control/HBoxContainer/LeftHalf/CenterContainer/VBoxContainer/SettingsPanel
@onready var volumeSlider: HSlider = $Control/HBoxContainer/LeftHalf/CenterContainer/VBoxContainer/SettingsPanel/VBoxContainer/VolumeSlider
@onready var settingsBackButton: Button = $Control/HBoxContainer/LeftHalf/CenterContainer/VBoxContainer/SettingsPanel/VBoxContainer/SettingsBackButton
@onready var leaderboardLabel: RichTextLabel = $Control/HBoxContainer/RightHalf/CenterContainer/VBoxContainer/leaderboardLabel


func _ready():
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	settingsPanel.visible = false
	hide()

	resumeButton.pressed.connect(onResume)
	settingsButton.pressed.connect(onSettings)
	quitButton.pressed.connect(onQuit)
	volumeSlider.value_changed.connect(onVolumeChanged)
	settingsBackButton.pressed.connect(onSettingsBack)

	# Set slider range
	volumeSlider.min_value = 0.0
	volumeSlider.max_value = 1.0
	volumeSlider.step = 0.01
	volumeSlider.value = AudioServer.get_bus_volume_db(0)
	
func _input(event):
	if event.is_action_pressed("escape"):
		if visible:
			onResume()
		else:
			openPause()

func openPause():
	show()
	get_tree().paused = true
	_fetchLeaderboard()

func onResume():
	hide()
	get_tree().paused = false

func _setMainButtonsVisible(value: bool):
	resumeButton.visible = value
	settingsButton.visible = value
	quitButton.visible = value

func onSettings():
	_setMainButtonsVisible(false)
	settingsPanel.visible = true

func onSettingsBack():
	settingsPanel.visible = false
	_setMainButtonsVisible(true)

func onQuit():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/StartMenu.tscn")

func onVolumeChanged(value: float):
	AudioServer.set_bus_volume_db(0, linear_to_db(value))

func _fetchLeaderboard():
	await Global.populateLeaderboard(leaderboardLabel)

func _onScoresReceived():
	await Global.populateLeaderboard(leaderboardLabel)

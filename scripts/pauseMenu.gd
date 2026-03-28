extends CanvasLayer

@onready var resumeButton: Button = $PanelContainer/VBoxContainer/ResumeButton
@onready var settingsButton: Button = $PanelContainer/VBoxContainer/SettingsButton
@onready var quitButton: Button = $PanelContainer/VBoxContainer/QuitButton
@onready var settingsPanel: PanelContainer = $PanelContainer/VBoxContainer/SettingsPanel
@onready var volumeSlider: HSlider = $PanelContainer/VBoxContainer/SettingsPanel/VBoxContainer/VolumeSlider
@onready var settingsBackButton: Button = $PanelContainer/VBoxContainer/SettingsPanel/VBoxContainer/SettingsBackButton
@onready var vBoxContainer: VBoxContainer = $PanelContainer/VBoxContainer

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

func onResume():
	hide()
	get_tree().paused = false

func onSettings():
	settingsPanel.visible = true
	# Hide the main buttons
	resumeButton.visible = false
	settingsButton.visible = false
	quitButton.visible = false
	
func onSettingsBack():
	settingsPanel.visible = false
	# Show the main buttons again
	resumeButton.visible = true
	settingsButton.visible = true
	quitButton.visible = true

func onQuit():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/StartMenu.tscn")

func onVolumeChanged(value: float):
	# Convert linear 0-1 to decibels
	AudioServer.set_bus_volume_db(0, linear_to_db(value))

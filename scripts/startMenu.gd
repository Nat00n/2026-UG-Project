extends CanvasLayer

@onready var playButton: Button = $Control/HBoxContainer/LeftHalf/CenterContainer/VBoxContainer/PlayButton
@onready var errorLabel: Label = $Control/HBoxContainer/LeftHalf/CenterContainer/VBoxContainer/ErrorLabel
@onready var usernameInput: LineEdit = $Control/HBoxContainer/LeftHalf/CenterContainer/VBoxContainer/UsernameInput
@onready var leaderboardBox: VBoxContainer = $Control/HBoxContainer/RightHalf/CenterContainer/LeaderboardContainer/LeaderboardBox

func _ready():
	errorLabel.visible = false
	playButton.pressed.connect(onPlay)
	usernameInput.grab_focus()
	await get_tree().process_frame
	AudioManager.playMusic("menu")
	Global.populateLeaderboard(leaderboardBox)

func _exit_tree():
	# Cancel leaderboard when leaving this scene
	Global.cancelLeaderboard()

func onPlay():
	var username = usernameInput.text.strip_edges()
	if username.length() < 2:
		errorLabel.text = "Name must be at least 2 characters."
		errorLabel.visible = true
		return
	if username.length() > 20:
		errorLabel.text = "Name must be 20 characters or fewer."
		errorLabel.visible = true
		return
	Global.username = username
	Global.startTimer()
	Global.initScoreFromProgression()
	get_tree().change_scene_to_file("res://scenes/LevelSelectionScreen.tscn")

extends CanvasLayer

@onready var playButton: Button = $Control/HBoxContainer/LeftHalf/CenterContainer/VBoxContainer/PlayButton
@onready var errorLabel: Label = $Control/HBoxContainer/LeftHalf/CenterContainer/VBoxContainer/ErrorLabel
@onready var usernameInput: LineEdit = $Control/HBoxContainer/LeftHalf/CenterContainer/VBoxContainer/UsernameInput
@onready var leaderboardLabel: RichTextLabel = $Control/HBoxContainer/RightHalf/CenterContainer/VBoxContainer/LeaderboardLabel

@export var mainScene: PackedScene

func _ready():
	errorLabel.visible = false
	playButton.pressed.connect(onPlay)
	usernameInput.grab_focus()
	_fetchLeaderboard()

func onPlay():
	var name = usernameInput.text.strip_edges()
	if name.length() < 2:
		errorLabel.text = "Name must be at least 2 characters."
		errorLabel.visible = true
		return
	if name.length() > 20:
		errorLabel.text = "Name must be 20 characters or fewer."
		errorLabel.visible = true
		return
	Global.username = name
	Global.startTimer()
	get_tree().change_scene_to_packed(mainScene)

func _fetchLeaderboard():
	await Global.populateLeaderboard(leaderboardLabel)
	

func _onScoresReceived():
	await Global.populateLeaderboard(leaderboardLabel)

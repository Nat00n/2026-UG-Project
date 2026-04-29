extends CanvasLayer # Start Menu Script
# The game's entry point. Validates the player's chosen username, initialises the
# session, and navigates to the level selection screen on success
# Also displays the global leaderboard while the player is on this screen
 
@onready var playButton: Button = $Control/HBoxContainer/LeftHalf/CenterContainer/VBoxContainer/PlayButton
@onready var errorLabel: Label = $Control/HBoxContainer/LeftHalf/CenterContainer/VBoxContainer/ErrorLabel
@onready var usernameInput: LineEdit = $Control/HBoxContainer/LeftHalf/CenterContainer/VBoxContainer/UsernameInput
@onready var leaderboardBox: VBoxContainer = $Control/HBoxContainer/RightHalf/CenterContainer/LeaderboardContainer/LeaderboardBox
 
func _ready():
	errorLabel.visible = false
	playButton.pressed.connect(onPlay)
	usernameInput.grab_focus()  # player can type immediately without clicking
	await get_tree().process_frame
	AudioManager.playMusic("menu")
	Global.populateLeaderboard(leaderboardBox)
 
func _exit_tree():
	# Cancel any pending leaderboard fetch to avoid writing into freed nodes
	Global.cancelLeaderboard()
 
func onPlay():
	var username = usernameInput.text.strip_edges()
	# Enforce minimum and maximum name length before proceeding
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
	Global.initScoreFromProgression()  # Restore score from any previously saved progress
	get_tree().change_scene_to_file("res://scenes/LevelSelectionScreen.tscn")

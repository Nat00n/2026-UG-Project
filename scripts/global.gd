extends Node # Global Script - Autoload
# Singleton accessible from any script via the 'Global' autoload name
# Responsible for: player session data, score calculation, timer, and leaderboard population

func _ready() -> void:
	# Initialise SilentWolf, the third-party leaderboard backend
	SilentWolf.configure({
		"api_key": "jIBgCejWMw2ZcYULjxpy74ydXswvr8ff7orLAr2O",
		"game_id": "tasktrain",
		"log_level": 1
	})
	
	# SilentWolf.Scores.wipe_leaderboard() # used to reset the leaderboard data

var username: String = ""        # Set at the start menu, included in every score submission
var startTime: float = 0.0       # Unix timestamp recorded when the player begins a run
var gameScore: int = 0           # Accumulated score: 1 pt per room complete, +3 per fully complete level
var activeLeaderboardRequest = null  # Tracks the current async leaderboard fetch so stale requests can be cancelled

### Timer

func startTimer():
	# Record the moment the player enters the game so elapsed time can be computed later
	startTime = Time.get_unix_time_from_system()

### Score

func initScoreFromProgression():
	# Recomputes gameScore from saved progression data so returning players start with the right total
	var pm = get_node("/root/LevelProgressionManager")
	gameScore = 0
	for levelId in pm.levels:
		var level = pm.levels[levelId]
		gameScore += level.completedRooms.size()       # +1 per completed room
		if level.isFullyComplete():
			gameScore += 3                             # +3 Bonus for fully completing a level

func submitScore():
	# Combines score and time into a single integer so the leaderboard can sort by score first,
	# then by fastest time as a tiebreaker: combined = score * 10000 + (9999 - elapsed_seconds)
	var elapsed = int(Time.get_unix_time_from_system() - startTime)
	var combined = gameScore * 10000 + (9999 - min(elapsed, 9999))
	SilentWolf.Scores.save_score(username, combined)

### Leaderboard

func cancelLeaderboard():
	# Invalidates any in-progress leaderboard fetch. Called when the scene changes
	# to prevent callbacks from writing into freed UI nodes
	if activeLeaderboardRequest:
		activeLeaderboardRequest = null

func populateLeaderboard(container: VBoxContainer):
	# Fetches the top scores asynchronously and builds a styled leaderboard inside 'container'
	# Uses a requestId pattern so that if the scene changes mid-fetch, stale results are discarded
	cancelLeaderboard()
	await get_tree().process_frame

	if not is_instance_valid(container) or not container.is_inside_tree():
		return

	var requestId = Time.get_ticks_msec()
	activeLeaderboardRequest = requestId

	# Clear any previously rendered rows
	for child in container.get_children():
		child.queue_free()

	var loadingLabel = Label.new()
	loadingLabel.text = "Loading..."
	loadingLabel.add_theme_font_size_override("font_size", 18)
	container.add_child(loadingLabel)

	var state = {"responded": false, "scores": []}

	# SilentWolf returns results via a signal, wrap it in a lambda so we can capture requestId
	var callback = func(res):
		if activeLeaderboardRequest != requestId:
			return
		state["responded"] = true
		state["scores"] = res.get("scores", [])

	# Request a large pool so we can filter down to 10 unique usernames
	SilentWolf.Scores.get_scores(1000).sw_get_scores_complete.connect(callback, CONNECT_ONE_SHOT)

	# Poll until the response arrives or 8 seconds elapse (network timeout guard)
	var maxWaitTime = 8.0
	var checkInterval = 0.1
	var elapsed = 0.0
	while not state["responded"] and elapsed < maxWaitTime:
		await get_tree().create_timer(checkInterval).timeout
		elapsed += checkInterval
		if activeLeaderboardRequest != requestId:
			return
		if not is_instance_valid(container) or not container.is_inside_tree():
			activeLeaderboardRequest = null
			return

	for child in container.get_children():
		child.queue_free()

	if not state["responded"]:
		var errorLabel = Label.new()
		errorLabel.text = "Could not load scores. Try again."
		errorLabel.add_theme_font_size_override("font_size", 18)
		container.add_child(errorLabel)
		activeLeaderboardRequest = null
		return

	if state["scores"].is_empty():
		var emptyLabel = Label.new()
		emptyLabel.text = "No scores yet - be the first!"
		emptyLabel.add_theme_font_size_override("font_size", 18)
		container.add_child(emptyLabel)
		activeLeaderboardRequest = null
		return

	# Decode combined score, de-duplicate to one row per player, and stop after 10 unique entries
	var seenNames: Array = []
	var rank = 1
	for entry in state["scores"]:
		var playerName = entry["player_name"]
		if playerName in seenNames:
			continue
		seenNames.append(playerName)
		var combined = int(entry["score"])
		var entryScore = combined / 10000
		var entryTime = 9999 - (combined % 10000)
		container.add_child(_makeRow(rank, playerName, entryScore, entryTime / 60, entryTime % 60))
		rank += 1
		if rank > 10:
			break

	activeLeaderboardRequest = null

func _makeRow(rank: int, playerName: String, score: int, mins: int, secs: int) -> PanelContainer:
	# Builds a styled leaderboard row with gold/silver/bronze theming for the top three
	var row = PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 68)
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.content_margin_left = 14
	style.content_margin_right = 20
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	match rank:
		1: style.bg_color = Color(0.18, 0.16, 0.05); style.border_color = Color(0.9, 0.78, 0.28, 0.6)
		2: style.bg_color = Color(0.14, 0.14, 0.15); style.border_color = Color(0.69, 0.71, 0.75, 0.6)
		3: style.bg_color = Color(0.16, 0.10, 0.05); style.border_color = Color(0.76, 0.48, 0.28, 0.6)
		_: style.bg_color = Color(0.12, 0.12, 0.12); style.border_color = Color(0.3, 0.3, 0.3, 0.5)
	row.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)

	var rankLabel = Label.new()
	rankLabel.text = str(rank)
	rankLabel.custom_minimum_size = Vector2(36, 0)
	rankLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rankLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rankLabel.add_theme_font_size_override("font_size", 22)
	match rank:
		1: rankLabel.add_theme_color_override("font_color", Color(0.9, 0.78, 0.28))
		2: rankLabel.add_theme_color_override("font_color", Color(0.69, 0.71, 0.75))
		3: rankLabel.add_theme_color_override("font_color", Color(0.76, 0.48, 0.28))
		_: rankLabel.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

	var nameLabel = Label.new()
	nameLabel.text = playerName
	nameLabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nameLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nameLabel.add_theme_font_size_override("font_size", 22)
	nameLabel.add_theme_color_override("font_color", Color.WHITE)

	var scoreLabel = Label.new()
	scoreLabel.text = "%d pts" % score
	scoreLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	scoreLabel.add_theme_font_size_override("font_size", 20)
	scoreLabel.add_theme_color_override("font_color", Color.WHITE)

	var divider = Label.new()
	divider.text = "|"
	divider.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	divider.add_theme_font_size_override("font_size", 20)
	divider.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))

	var timeLabel = Label.new()
	timeLabel.text = "%02d:%02d" % [mins, secs]
	timeLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timeLabel.add_theme_font_size_override("font_size", 20)
	timeLabel.add_theme_color_override("font_color", Color(0.5, 0.8, 0.6))

	hbox.add_child(rankLabel)
	hbox.add_child(nameLabel)
	hbox.add_child(scoreLabel)
	hbox.add_child(divider)
	hbox.add_child(timeLabel)
	row.add_child(hbox)
	return row

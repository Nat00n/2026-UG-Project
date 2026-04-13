extends Node

func _ready() -> void:
	SilentWolf.configure({
		"api_key": "jIBgCejWMw2ZcYULjxpy74ydXswvr8ff7orLAr2O",
		"game_id": "tasktrain",
		"log_level": 1
	})
	SilentWolf.configure_scores({
		"open_scene_on_close": "res://scenes/MainPage.tscn"
	})
	
	# SilentWolf.Scores.wipe_leaderboard()

var username: String = ""
var startTime: float = 0.0
var gameScore: int = 0
var activeLeaderboardRequest = null  # Track if request is active

func startTimer():
	startTime = Time.get_unix_time_from_system()

func getFormattedTime() -> String:
	var elapsed = int(Time.get_unix_time_from_system() - startTime)
	return "%02d:%02d" % [elapsed / 60, elapsed % 60]

func initScoreFromProgression():
	var pm = get_node("/root/LevelProgressionManager")
	gameScore = 0
	for levelId in pm.levels:
		var level = pm.levels[levelId]
		gameScore += level.completedRooms.size()
		if level.isFullyComplete():
			gameScore += 3

func submitScore():
	var elapsed = int(Time.get_unix_time_from_system() - startTime)
	var combined = gameScore * 10000 + (9999 - min(elapsed, 9999))
	print("[Global] Submitting score: ", combined, " (", gameScore, " pts, ", elapsed, "s) for ", username)
	SilentWolf.Scores.save_score(username, combined)

# Cancel any active leaderboard loading
func cancelLeaderboard():
	if activeLeaderboardRequest:
		activeLeaderboardRequest = null
		print("[Global] Cancelled leaderboard request")

func populateLeaderboard(container: VBoxContainer):
	# Cancel any previous request
	cancelLeaderboard()
	
	# Wait for the scene to be fully ready
	await get_tree().process_frame
	
	# Validate container still exists after waiting
	if not is_instance_valid(container) or not container.is_inside_tree():
		print("[Global] Container not valid or not in tree")
		return
	
	# Mark this request as active
	var requestId = Time.get_ticks_msec()
	activeLeaderboardRequest = requestId
	
	# Clear existing children
	for child in container.get_children():
		child.queue_free()

	var loadingLabel = Label.new()
	loadingLabel.text = "Loading..."
	loadingLabel.add_theme_font_size_override("font_size", 18)
	container.add_child(loadingLabel)

	var state = {"responded": false, "scores": []}

	var callback = func(res):
		# Ignore if this request was cancelled
		if activeLeaderboardRequest != requestId:
			return
		state["responded"] = true
		state["scores"] = res.get("scores", [])

	# Request TOP 100 scores so we can filter to 10 unique users
	SilentWolf.Scores.get_scores(1000).sw_get_scores_complete.connect(callback, CONNECT_ONE_SHOT)

	# Wait for response OR timeout (whichever comes first)
	var maxWaitTime = 8.0
	var checkInterval = 0.1
	var elapsed = 0.0
	
	while not state["responded"] and elapsed < maxWaitTime:
		await get_tree().create_timer(checkInterval).timeout
		elapsed += checkInterval
		
		# Check if request was cancelled
		if activeLeaderboardRequest != requestId:
			print("[Global] Request was cancelled during wait")
			return
		
		# Check if container is still valid
		if not is_instance_valid(container) or not container.is_inside_tree():
			print("[Global] Container no longer valid")
			activeLeaderboardRequest = null
			return

	# Clear loading message
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
		emptyLabel.text = "No scores yet — be the first!"
		emptyLabel.add_theme_font_size_override("font_size", 18)
		container.add_child(emptyLabel)
		activeLeaderboardRequest = null
		return

	# Filter to top 10 UNIQUE users
	var seenNames: Array = []
	var rank = 1
	for entry in state["scores"]:
		var playerName = entry["player_name"]
		
		# Skip if we've already seen this user
		if playerName in seenNames:
			continue
		
		# Add this unique user
		seenNames.append(playerName)
		var combined = int(entry["score"])
		var entryScore = combined / 10000
		var entryTime = 9999 - (combined % 10000)
		container.add_child(_makeRow(rank, playerName, entryScore, entryTime / 60, entryTime % 60))
		rank += 1
		
		# Stop after adding 10 unique users
		if rank > 10:
			break
	
	activeLeaderboardRequest = null

func _makeRow(rank: int, playerName: String, score: int, mins: int, secs: int) -> PanelContainer:
	# ... (keep the same as before)
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

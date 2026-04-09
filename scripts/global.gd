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

var username: String = ""
var startTime: float = 0.0
var elapsedTime: float = 0.0

func startTimer():
	startTime = Time.get_unix_time_from_system()

func stopTimer():
	elapsedTime = Time.get_unix_time_from_system() - startTime

func getFormattedTime() -> String:
	var mins = int(elapsedTime) / 60
	var secs = int(elapsedTime) % 60
	return "%02d:%02d" % [mins, secs]

func submitScore():
	# Invert so lower time = higher score
	var score = 999999 - int(elapsedTime)
	SilentWolf.Scores.save_score(username, score)
	
func populateLeaderboard(label: RichTextLabel):
	label.text = "Loading..."
	var sw_result: Dictionary = await SilentWolf.Scores.get_scores().sw_get_scores_complete
	var scores: Array = sw_result.get("scores", [])
	
	label.clear()
	label.add_theme_font_size_override("normal_font_size", 24)
	
	if scores.is_empty():
		label.append_text("No scores yet — be the first!")
		return
	

	var seenNames: Array = []
	var rank = 1
	for i in range(scores.size()):
		var entry = scores[i]
		var playerName = entry["player_name"]
		if playerName in seenNames:
			continue
		seenNames.append(playerName)
		
		var time = 999999 - int(entry["score"])
		var mins = time / 60
		var secs = time % 60
		
		label.append_text("%d " % rank)
		label.push_color(Color.WHITE)
		label.append_text("%-18s" % playerName)
		label.pop()
		label.push_color(Color(0.4, 0.9, 0.6))
		label.append_text("%02d:%02d\n" % [mins, secs])
		label.pop()
		rank += 1

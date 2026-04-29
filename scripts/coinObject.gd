class_name CoinChangeObject # Coin Object Script
extends InteractableObject
# Implements the coin change problem visualisation task
# A random target amount is generated and the player must produce a list of coin
# denominations that sums exactly to that amount. Coins animate as stacked circles

const COIN_VALUES = [1, 2, 5, 10, 20, 50, 100]  # Standard UK pence denominations
const COIN_RADIUS = 20
const COIN_GAP = 4
const COL_WIDTH = 80
const COL_HEIGHT = 300

var targetAmount: int = 0           # Amount the player must make (in pence)
var coinStacks: Dictionary = {}     # coinValue -> Array of PanelContainer (the coin nodes)

### Setup

func _init_object():
	targetAmount = randi_range(15, 500)
	_buildCoinDisplay()

func resetDisplay():
	for t in activeTweens:
		if is_instance_valid(t):
			t.kill()
	activeTweens.clear()
	# Generate a new target on each reset so the player can't re-use the same solution
	targetAmount = randi_range(15, 500)
	_buildCoinDisplay()

func _buildDisplay():
	_buildCoinDisplay()

func _buildCoinDisplay():
	# Clears and rebuilds the column-per-denomination layout with a target amount label
	for child in nodeDisplay.get_children():
		child.queue_free()
	coinStacks.clear()

	var totalWidth = COIN_VALUES.size() * COL_WIDTH
	nodeDisplay.size = Vector2(totalWidth, COL_HEIGHT + 80)

	var bg = ColorRect.new()
	bg.color = Color(0.5, 0.5, 0.5, 0.75)
	bg.position = Vector2(0, -50)
	bg.size = Vector2(totalWidth, COL_HEIGHT + 130)
	nodeDisplay.add_child(bg)
	bg.z_index = -1

	var targetLabel = Label.new()
	targetLabel.text = "Make: %s" % _formatCoin(targetAmount)
	targetLabel.position = Vector2(totalWidth / 2.0 - 70, -40)
	targetLabel.size = Vector2(140, 30)
	targetLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	targetLabel.add_theme_font_size_override("font_size", 16)
	targetLabel.add_theme_color_override("font_color", Color.YELLOW)
	nodeDisplay.add_child(targetLabel)

	# One column per denomination, with a baseline and a value label below it
	for i in range(COIN_VALUES.size()):
		var coinVal = COIN_VALUES[i]
		var colX = i * COL_WIDTH + COL_WIDTH / 2.0

		var valLabel = Label.new()
		valLabel.text = _formatCoin(coinVal)
		valLabel.position = Vector2(colX - 30, COL_HEIGHT + 10)
		valLabel.size = Vector2(60, 30)
		valLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		valLabel.add_theme_font_size_override("font_size", 13)
		valLabel.add_theme_color_override("font_color", Color.WHITE)
		nodeDisplay.add_child(valLabel)

		var line = Line2D.new()
		line.add_point(Vector2(colX - COIN_RADIUS - 4, COL_HEIGHT))
		line.add_point(Vector2(colX + COIN_RADIUS + 4, COL_HEIGHT))
		line.default_color = Color(0.4, 0.4, 0.4)
		line.width = 2
		nodeDisplay.add_child(line)

		coinStacks[coinVal] = []

### Coin Helpers

func _formatCoin(value: int) -> String:
	# Returns pence values as "Xp" and values ≥100 as "£X.XX"
	if value < 100:
		return "%dp" % value
	return "£%.2f" % (value / 100.0)

func _getCoinColor(value: int) -> Color:
	# Bronze for 1p/2p, silver for 5p/10p/20p, gold for 50p/£1
	match value:
		1, 2: return Color(0.6, 0.45, 0.25)
		5, 10, 20: return Color(0.8, 0.8, 0.8)
		50, 100: return Color(0.9, 0.8, 0.35)
	return Color.GRAY

func _makeCoinCircle(value: int) -> PanelContainer:
	# Creates a circular coin node with the denomination printed inside
	var panel = PanelContainer.new()
	panel.size = Vector2(COIN_RADIUS * 2, COIN_RADIUS * 2)
	panel.custom_minimum_size = Vector2(COIN_RADIUS * 2, COIN_RADIUS * 2)
	var style = StyleBoxFlat.new()
	style.bg_color = _getCoinColor(value)
	for corner in ["corner_radius_top_left", "corner_radius_top_right",
				   "corner_radius_bottom_left", "corner_radius_bottom_right"]:
		style.set(corner, COIN_RADIUS)
	style.border_width_left = 2; style.border_width_right = 2
	style.border_width_top = 2; style.border_width_bottom = 2
	style.border_color = Color(1, 1, 1, 0.2)
	panel.add_theme_stylebox_override("panel", style)
	var label = Label.new()
	label.text = _formatCoin(value)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(0.15, 0.1, 0.05))
	panel.add_child(label)
	return panel

### Stack Manipulation

func addCoinToStack(coinValue: int, delay: float = 0.0):
	# Animates a new coin dropping into its denomination column with a bounce effect
	if not COIN_VALUES.has(coinValue):
		return
	var colIndex = COIN_VALUES.find(coinValue)
	var colX = colIndex * COL_WIDTH + COL_WIDTH / 2.0
	var stack = coinStacks[coinValue]
	var coinY = COL_HEIGHT - COIN_RADIUS - stack.size() * (COIN_RADIUS * 2 + COIN_GAP)

	var coin = _makeCoinCircle(coinValue)
	coin.position = Vector2(colX - COIN_RADIUS, coinY - COIN_RADIUS - 60)  # Start above
	coin.modulate.a = 0.0
	nodeDisplay.add_child(coin)
	stack.append(coin)

	var tween = createTrackedTween()
	tween.set_parallel(true)
	tween.tween_property(coin, "position:y", coinY - COIN_RADIUS, 0.25)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(delay)
	tween.tween_property(coin, "modulate:a", 1.0, 0.1).set_delay(delay)
	AudioManager.playSFX("coin")

func removeCoinFromStack(coinValue: int):
	# Removes the top coin from a denomination's stack (supports backtracking algorithms)
	if not COIN_VALUES.has(coinValue):
		return
	var stack = coinStacks[coinValue]
	if stack.is_empty():
		return
	stack.pop_back().queue_free()

func clearAllStacks():
	for coinVal in COIN_VALUES:
		for coin in coinStacks[coinVal]:
			if is_instance_valid(coin):
				coin.queue_free()
		coinStacks[coinVal].clear()

### Commit & Verification

func commitChange(coinList: Array):
	# Clears the display, animates the submitted coin list, then verifies the result
	clearAllStacks()
	var delay = 0.0
	for coin in coinList:
		addCoinToStack(coin, delay)
		delay += 0.2
	# Wait for all coin drop animations to finish before verifying
	await get_tree().create_timer(delay + 0.5).timeout
	verifyCoinChange(coinList)

func verifyCoinChange(coinList: Array):
	# Passes only if the coins sum exactly to targetAmount and all values are valid denominations
	var sum = 0
	for coin in coinList:
		sum += coin
	if sum != targetAmount:
		AudioManager.playSFX("error")
		return
	for coin in coinList:
		if not COIN_VALUES.has(coin):
			AudioManager.playSFX("error")
			return
	Global.submitScore()
	roomTaskCompleted.emit(objectID)
	Analytics.recordComplete(objectID)
	AudioManager.playSFX("task_complete")

### Preamble & Guide

func getPreambleFunctions() -> String:
	return """
coins = [1, 2, 5, 10, 20, 50, 100]
targetAmount = %d

def useCoin(value):
	talk("__addcoin__:" + str(value))

def removeCoin(value):
	talk("__removecoin__:" + str(value))

def commitChange(coinList):
	talk("__commitchange__:" + ",".join(str(c) for c in coinList))
""" % targetAmount

func getBaseGuide() -> String:
	return """[b]Available Data:[/b]

[code]coins[/code]
A list of available coin denominations in pence: [1, 2, 5, 10, 20, 50, 100].

[code]targetAmount[/code]
The total amount in pence you must make using the available coins.

[b]Available Functions:[/b]

[code]useCoin(value)[/code]
Adds one coin of the given denomination to its stack in the visualiser.
Call this each time your algorithm selects a coin.

[code]removeCoin(value)[/code]
Removes the top coin of the given denomination from its stack.
Useful if your algorithm backtracks.

[code]commitChange(coinList)[/code]
Accepts a flat list of coin values representing the complete final selection.
Clears all stacks and animates the full solution at once.
Example: commitChange([50, 20, 5, 2, 2])"""

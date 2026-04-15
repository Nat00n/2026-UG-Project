extends CanvasLayer
#IDE

@onready var panel: Panel = $Panel
@onready var inputCE: CodeEdit = $Panel/VSplitContainer/CodeEditor
@onready var outputRCT: RichTextLabel = $Panel/VSplitContainer/OutputBox
@onready var guideContainer: HBoxContainer = $Panel/VSplitContainer/GuideContainer
@onready var guideTaskColumn: VBoxContainer = $Panel/VSplitContainer/GuideContainer/TaskScrollContainer/TaskColumn
@onready var guideTaskText: RichTextLabel = $Panel/VSplitContainer/GuideContainer/TaskScrollContainer/TaskColumn/TaskText
@onready var showExampleButton: Button = $Panel/VSplitContainer/GuideContainer/TaskScrollContainer/TaskColumn/ShowExampleButton
@onready var exampleCodeLabel: RichTextLabel = $Panel/VSplitContainer/GuideContainer/TaskScrollContainer/TaskColumn/ExampleCode
@onready var guideDataColumn: RichTextLabel = $Panel/VSplitContainer/GuideContainer/DataColumn
@onready var runButton: Button = $Panel/VSplitContainer/HSplitContainer/RunButton
@onready var closeButton: Button = $Panel/VSplitContainer/HSplitContainer/CloseButton
@onready var aiButton: Button = $Panel/VSplitContainer/HSplitContainer/AIButton
@onready var editorTabButton: Button = $Panel/VSplitContainer/HSplitContainer/EditorTabButton
@onready var guideTabButton: Button = $Panel/VSplitContainer/HSplitContainer/GuideTabButton

var _talkCallback
var _aiCallback
var _currentObject
var _executingObject
var _llmReady := false
var _llmReadyCallback
var _llmProgressCallback
var _onEditorTab := true
var _lastTabPerObject := {}  # Tracks last tab state for each object

func _ready():
	panel.visible = false

	closeButton.pressed.connect(onClose)
	runButton.pressed.connect(onRun)
	aiButton.pressed.connect(onAITips)
	editorTabButton.pressed.connect(_showEditorTab)
	guideTabButton.pressed.connect(_showGuideTab)
	showExampleButton.pressed.connect(_onShowExamplePressed)

	_setupSyntaxHighlighting()
	_setupExampleButton()
	_showEditorTab()

	if OS.has_feature("web"):
		_talkCallback = JavaScriptBridge.create_callback(talk)
		JavaScriptBridge.get_interface("window").godotTalk = _talkCallback

		_aiCallback = JavaScriptBridge.create_callback(onAIResponse)
		JavaScriptBridge.get_interface("window").godotAIResponse = _aiCallback

		_llmReadyCallback = JavaScriptBridge.create_callback(onLLMReady)
		JavaScriptBridge.get_interface("window").godotLLMReady = _llmReadyCallback

		_llmProgressCallback = JavaScriptBridge.create_callback(onLLMProgress)
		JavaScriptBridge.get_interface("window").godotLoadProgress = _llmProgressCallback


func talk(args):
	var msg = str(args[0])
	var target = _executingObject if _executingObject else _currentObject
	if target == null:
		return

	# Sort
	if msg.begins_with("__swap__:"):
		var parts = msg.split(":")
		target.queueSwap(int(parts[1]), int(parts[2]))
	elif msg.begins_with("__pivot__:"):
		target.queuePivot(int(msg.split(":")[1]))
	elif msg.begins_with("__commit__"):
		target.commitSort()
	elif msg.begins_with("__move__:"):
		var parts = msg.split(":")
		target.queueMove(int(parts[1]), int(parts[2]))
	elif msg.begins_with("__split__:"):
		var parts = msg.split(":")
		target.queueHighlightSplit(int(parts[1]), int(parts[2]), int(parts[3]))

	# Search
	elif msg.begins_with("__check__:"):
		target.queueCheck(int(msg.split(":")[1]))
	elif msg.begins_with("__commitSelect__:"):
		target.queueSelect(int(msg.split(":")[1]))
		target.commitSearch()

	# Graph
	elif msg.begins_with("__visit__:"):
		target.queueVisit(int(msg.split(":")[1]))
	elif msg.begins_with("__path__:"):
		var parts = msg.split(":")[1].split(",")
		var pathIds = []
		for p in parts:
			if p.strip_edges() != "":
				pathIds.append(int(p))
		target.queuePath(pathIds)
		target.startPathAnimation()

	# Coin change
	elif msg.begins_with("__addcoin__:"):
		target.addCoinToStack(int(msg.split(":")[1]))
	elif msg.begins_with("__removecoin__:"):
		target.removeCoinFromStack(int(msg.split(":")[1]))
	elif msg.begins_with("__commitchange__:"):
		var parts = msg.split(":")[1].split(",")
		var coinList = []
		for p in parts:
			if p.strip_edges() != "":
				coinList.append(int(p))
		target.commitChange(coinList)

	# Knapsack
	elif msg.begins_with("__cell__:"):
		var parts = msg.split(":")
		target.queueCellFill(int(parts[1]), int(parts[2]), int(parts[3]))
	elif msg.begins_with("__backtrack__:"):
		var parts = msg.split(":")
		target.queueBacktrack(int(parts[1]), int(parts[2]))
	elif msg.begins_with("__taken__:"):
		var parts = msg.split(":")
		target.queueTaken(int(parts[1]), int(parts[2]))
	elif msg.begins_with("__skipped__:"):
		var parts = msg.split(":")
		target.queueSkipped(int(parts[1]), int(parts[2]))
	elif msg.begins_with("__knapsack__:"):
		var parts = msg.split(":")[1].split(",")
		var indices = []
		for p in parts:
			if p.strip_edges() != "":
				indices.append(int(p))
		target.commitKnapsack(indices)

	# Default output
	else:
		outputRCT.append_text(msg + "\n")


func onClose() -> void:
	if _currentObject:
		_currentObject.saveScript(inputCE.text)
		# Save current tab state for this object
		_lastTabPerObject[_currentObject] = _onEditorTab

	panel.visible = false
	_currentObject = null


func open(objectName: String, interactable):
	_currentObject = interactable
	
	Analytics.startTask(_currentObject)
	
	outputRCT.clear()
	outputRCT.append_text("--- %s ---\n" % objectName)
	inputCE.text = interactable.savedScript
	
	# Check if this object has a saved tab preference
	if _lastTabPerObject.has(interactable):
		# Restore last tab
		if _lastTabPerObject[interactable]:
			_showEditorTab()
		else:
			_showGuideTab()
	else:
		# Default to Task Guide for first-time open
		_showGuideTab()
	
	panel.visible = true

func _setupSyntaxHighlighting():
	var highlighter = CodeHighlighter.new()

	# Keywords
	var keywords = ["False", "None", "True", "and", "as", "assert", "async", "await",
		"break", "class", "continue", "def", "del", "elif", "else", "except",
		"finally", "for", "from", "global", "if", "import", "in", "is",
		"lambda", "not", "or", "pass", "raise", "return", "try", "while", "with", "yield"]
	for kw in keywords:
		highlighter.add_keyword_color(kw, Color.html("#569CD6"))

	# Built-ins
	var builtins = ["print", "len", "range", "int", "str", "float", "list",
		"dict", "set", "tuple", "type", "enumerate", "zip", "map",
		"filter", "sorted", "reversed", "min", "max", "sum", "abs"]
	for b in builtins:
		highlighter.add_keyword_color(b, Color.html("#DCDCAA"))

	# Colors
	highlighter.number_color = Color.html("#B5CEA8")
	highlighter.symbol_color = Color.html("#D4D4D4")
	highlighter.function_color = Color.html("#DCDCAA")
	highlighter.member_variable_color = Color.html("#9CDCFE")

	# Strings
	highlighter.add_color_region('"', '"', Color.html("#CE9178"))
	highlighter.add_color_region("'", "'", Color.html("#CE9178"))

	# Comments
	highlighter.add_color_region("#", "", Color.html("#6A9955"), true)

	inputCE.syntax_highlighter = highlighter

func _setupExampleButton():
	# Add green styling to match example solution text
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.23, 0.23, 0.23)
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color.html("#90EE90")  # Light green
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_left = 8
	normal_style.corner_radius_bottom_right = 8
	showExampleButton.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.3, 0.3, 0.3)
	hover_style.border_width_left = 2
	hover_style.border_width_right = 2
	hover_style.border_width_top = 2
	hover_style.border_width_bottom = 2
	hover_style.border_color = Color.html("#B0FFB0")  # Lighter green on hover
	hover_style.corner_radius_top_left = 8
	hover_style.corner_radius_top_right = 8
	hover_style.corner_radius_bottom_left = 8
	hover_style.corner_radius_bottom_right = 8
	showExampleButton.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.15, 0.15, 0.15)
	pressed_style.border_width_left = 2
	pressed_style.border_width_right = 2
	pressed_style.border_width_top = 2
	pressed_style.border_width_bottom = 2
	pressed_style.border_color = Color.html("#90EE90")  # Light green
	pressed_style.corner_radius_top_left = 8
	pressed_style.corner_radius_top_right = 8
	pressed_style.corner_radius_bottom_left = 8
	pressed_style.corner_radius_bottom_right = 8
	showExampleButton.add_theme_stylebox_override("pressed", pressed_style)
	
	# Add spacing between TaskText and ShowExampleButton
	guideTaskColumn.add_theme_constant_override("separation", 20)

func _showEditorTab():
	_onEditorTab = true
	inputCE.visible = true
	outputRCT.visible = true
	guideContainer.visible = false
	aiButton.visible = true
	runButton.visible = true
	_setActiveTab(editorTabButton, guideTabButton)

func _showGuideTab():
	_onEditorTab = false
	inputCE.visible = false
	outputRCT.visible = false
	guideContainer.visible = true
	aiButton.visible = false
	runButton.visible = false
	_setActiveTab(guideTabButton, editorTabButton)
	_populateGuide()
	
func _setActiveTab(activeButton: Button, inactiveButton: Button):
	var activeStyle = StyleBoxFlat.new()
	activeStyle.bg_color = Color(0.25, 0.25, 0.25)
	activeStyle.corner_radius_top_left = 4
	activeStyle.corner_radius_top_right = 4
	activeStyle.corner_radius_bottom_left = 4
	activeStyle.corner_radius_bottom_right = 4
	activeButton.add_theme_stylebox_override("normal", activeStyle)
	activeButton.add_theme_stylebox_override("hover", activeStyle)

	var inactiveStyle = StyleBoxEmpty.new()
	inactiveButton.add_theme_stylebox_override("normal", inactiveStyle)
	inactiveButton.add_theme_stylebox_override("hover", inactiveStyle)

func _populateGuide():
	guideTaskText.clear()
	guideDataColumn.clear()
	
	# Reset example button/code visibility
	showExampleButton.visible = false
	exampleCodeLabel.visible = false
	
	if _currentObject == null:
		return
	
	# LEFT COLUMN - Task information
	if _currentObject.taskName.strip_edges() != "":
		guideTaskText.append_text("[b][font_size=28]%s[/font_size][/b]\n\n" % _currentObject.taskName)
	
	if _currentObject.taskGuide.strip_edges() != "":
		guideTaskText.append_text("[b][color=#FFDD88]Your Task:[/color][/b]\n")
		guideTaskText.append_text(_currentObject.taskGuide + "\n")
	
	# Show example button if example code exists
	if _currentObject.exampleCode.strip_edges() != "":
		showExampleButton.visible = true
		exampleCodeLabel.text = ""  # Clear previous example
	
	# RIGHT COLUMN - Data & Functions reference
	var base = _currentObject.getBaseGuide()
	if base.strip_edges() != "":
		guideDataColumn.append_text("[b][font_size=22][color=#88DDFF]Reference[/color][/font_size][/b]\n\n")
		guideDataColumn.append_text(base)

func _onShowExamplePressed():
	if _currentObject == null:
		return
		
	Analytics.recordRevealedCode(_currentObject)
		
	# Hide the button
	showExampleButton.visible = false
	
	# Show the example code
	exampleCodeLabel.clear()
	exampleCodeLabel.append_text("[b][color=#90EE90]Example Solution:[/color][/b]\n\n")
	exampleCodeLabel.append_text("[code]%s[/code]" % _currentObject.exampleCode)
	exampleCodeLabel.visible = true


func onLLMReady(args):
	_llmReady = true
	aiButton.disabled = false
	aiButton.text = "= AI Tips ="
	
	print("LLM ready")

func onLLMProgress(args):
	aiButton.text = "= AI Loading ="

func onAITips():
	if _currentObject == null:
		return

	var llmReady = JavaScriptBridge.eval("window.llmReady === true")
	if not llmReady:
		aiButton.text = "= AI Loading ="
		print("LLM not ready")
		return
		
	Analytics.recordAiTip(_currentObject)

	aiButton.disabled = true
	aiButton.text = "= AI Thinking... ="

	var playerCode = inputCE.text
	var task = _currentObject.taskDescription
	var preamble = _currentObject.getBaseGuide()

	var prompt = """You are a coding tutor in an educational game. 
You must NEVER write code or pseudocode. Only ask questions and give hints.

Task: %s

Available functions and data:
%s

Player's code:
%s

Give one short hint or ask one guiding question to help the player improve their code.  
Keep your response under 50 words.""" % [
		task if task.strip_edges() != "" else "No task provided.",
		preamble.strip_edges(),
		playerCode.strip_edges() if playerCode.strip_edges() != "" else "(empty)"
	]

	JavaScriptBridge.eval("window._pendingAIPrompt = %s;" % JSON.stringify(prompt))
	JavaScriptBridge.eval("""
		(async () => {
			try {
				await runAITips();
			} catch(e) {
				window.godotAIResponse("Error: " + e.message);
			}
		})();
	""")

	talk(["AI Thinking..."])

func onAIResponse(args):
	
	var msg = str(args[0])
	aiButton.disabled = false
	aiButton.text = "= AI Tips ="

	# Show AI response in output box with distinct colour
	outputRCT.push_color(Color.html("#DCDCAA"))
	outputRCT.append_text("\n AI Tips:\n")
	outputRCT.pop()
	outputRCT.push_color(Color.html("#9CDCFE"))
	outputRCT.append_text(msg + "\n")
	outputRCT.pop()

func onRun():
	if _currentObject:
		_currentObject.saveScript(inputCE.text)
		Analytics.recordRun(_currentObject)
		
	_executeCode(inputCE.text, _currentObject, false)

# Called by interactable for silent background run
func runScript(code: String, interactable):
	_executeCode(code, interactable, true)

func _buildPreamble() -> String:
	return """
import sys, io

class GodotOutput(io.TextIOBase):
	def write(self, s):
		if s.strip():
			talk(str(s))
		return len(s)

sys.stdout = GodotOutput()
sys.stderr = GodotOutput()

array = """ + _currentObject.getArrayString() + _currentObject.getPreambleFunctions()

func _executeCode(code: String, target, silent: bool):
	_executingObject = target
	
	if not silent:
		outputRCT.clear()
		outputRCT.append_text("Running...\n")
		
	if target.has_method("resetDisplay"):
		target.resetDisplay()

	var wrapped = _buildPreamble() + "\n" + code

	JavaScriptBridge.eval("window._pendingCode = %s;" % JSON.stringify(wrapped))
	JavaScriptBridge.eval("""
		(async () => {
			try {
				await runPythonFromGodot();
			} catch(e) {
				if (window.godotTalk) window.godotTalk("Error: " + e.message);
			}
		})();
	""")
	await get_tree().create_timer(0.1).timeout
	_executingObject = null

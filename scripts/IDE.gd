extends CanvasLayer


@onready var panel: Panel = $Panel
@onready var inputCE: CodeEdit = $Panel/VSplitContainer/CodeEditor
@onready var outputRCT: RichTextLabel = $Panel/VSplitContainer/OutputBox
@onready var runButton: Button = $Panel/VSplitContainer/HSplitContainer/RunButton
@onready var closeButton: Button = $Panel/VSplitContainer/HSplitContainer/CloseButton

var _talkCallback
var _currentObject

func _ready():
	
	panel.visible = false
	
	closeButton.pressed.connect(close)
	runButton.pressed.connect(run)
	
	if OS.has_feature("web"):
		_talkCallback = JavaScriptBridge.create_callback(talk)
		JavaScriptBridge.get_interface("window").godotTalk = _talkCallback

func talk(args): # test function to see that the python -> JavaScript -> Godot bridge works
	outputRCT.append_text(str(args[0]) + "\n")


func open(objectName: String, interactable):
	_currentObject = interactable
	
	outputRCT.clear()
	outputRCT.append_text("--- %s ---\n" % objectName)
	
	_registerPythonFunctions()
	
	panel.visible = true

func _registerPythonFunctions():
	JavaScriptBridge.eval("""
		window.gdReadNode = function(index) {
			return window._gdReadCallback ? window._gdReadCallback(index) : "not ready";
		};
		window.gdSelectNode = function(index) {
			return window._gdSelectCallback ? window._gdSelectCallback(index) : "not ready";
		};
	""")

	# Wire up GDScript callbacks
	var read_cb = JavaScriptBridge.create_callback(
		func(args):
			var idx = int(args[0])
			var result = _currentObject.read_node(idx)
			JavaScriptBridge.get_interface("window").set("_lastReadResult", result)
	)
	var select_cb = JavaScriptBridge.create_callback(
		func(args):
			var idx = int(args[0])
			var result = _currentObject.select_node(idx)
			JavaScriptBridge.get_interface("window").set("_lastSelectResult", result)
	)
	JavaScriptBridge.get_interface("window").set("_gdReadCallback", read_cb)
	JavaScriptBridge.get_interface("window").set("_gdSelectCallback", select_cb)

func run():
	
	outputRCT.clear()
	outputRCT.append_text("running : \n")
	
	var nodesStr = "["
	for n in _currentObject.dataNodes:
		nodesStr += '{"name": "%s", "value": %d},' % [n["name"], n["value"]]
	nodesStr += "]"
	
	var code = inputCE.get_text()
	
	var wrapped = """
import sys, io

class GodotOutput(io.TextIOBase):
	def write(self, s):
		if s.strip():
			talk(str(s))
		return len(s)

sys.stdout = GodotOutput()
sys.stderr = GodotOutput()

dataNodes = """ + nodesStr + """

# Custom functions
def read(index):
	if index < 0 or index >= len(dataNodes):
		talk("Error: index " + str(index) + " out of range")
		return None
	node = dataNodes[index]
	result = node["name"] + " = " + str(node["value"])
	talk(result)
	return node["value"]

def select(index):
	if index < 0 or index >= len(dataNodes):
		talk("Error: index " + str(index) + " out of range")
		return None
	talk("__select__:" + str(index))
	node = dataNodes[index]
	talk("Selected: " + node["name"] + " (value: " + str(node["value"]) + ")")
	return node["value"]

""" + code

	JavaScriptBridge.eval("""
			(async () => {
				try {
					await runPythonFromGodot(`""" + wrapped.replace("`", "\\`") + """`);
				} catch(e) {
					if (window.godotTalk) window.godotTalk("Error: " + e.message);
				}
			})();
		""")
	

func close() -> void:
	panel.visible = false

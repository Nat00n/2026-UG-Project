extends CanvasLayer


@onready var panel: Panel = $Panel
@onready var inputCE: CodeEdit = $Panel/VSplitContainer/CodeEditor
@onready var outputRCT: RichTextLabel = $Panel/VSplitContainer/OutputBox
@onready var runButton: Button = $Panel/VSplitContainer/HSplitContainer/RunButton
@onready var closeButton: Button = $Panel/VSplitContainer/HSplitContainer/CloseButton

var talkCallback

func _ready():
	
	panel.visible = false
	
	closeButton.pressed.connect(close)
	runButton.pressed.connect(run)
	
	if OS.has_feature("web"):
		talkCallback = JavaScriptBridge.create_callback(talk)
		JavaScriptBridge.get_interface("window").godotTalk = talkCallback


func talk(args):
	var msg = str(args[0])
	outputRCT.append_text(msg + "\n")


func open(objectName: String):
	outputRCT.clear()
	outputRCT.append_text("--- %s ---\n" % objectName)
	panel.visible = true


func run():
	
	outputRCT.clear()
	outputRCT.append_text("running : \n")
	
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

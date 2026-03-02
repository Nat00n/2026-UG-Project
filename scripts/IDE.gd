extends Control

@onready var inputCE: CodeEdit = $Panel/VSplitContainer/CodeEditor
@onready var outputRCT: RichTextLabel = $Panel/VSplitContainer/OutputBox
@onready var runButton: Button = $Panel/VSplitContainer/HSplitContainer/RunButton

var talkCallback

func _ready():
	
	if OS.has_feature("web"):
		talkCallback = JavaScriptBridge.create_callback(talk)
		JavaScriptBridge.get_interface("window").godotTalk = talkCallback
		
		
		
func _on_button_pressed():
	
	outputRCT.clear()
	outputRCT.append_text("run pressed \n")
	
	var code = inputCE.get_text()
	
	#JavaScriptBridge.eval("""
	#    (async () => {
	#		await runPythonFromGodot(`""" + code + """`);
	#    })();
	#""")
	
	
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
	
func talk(args):
	var msg = str(args[0])
	outputRCT.append_text("talk : ")
	outputRCT.append_text(msg + "\n")
	
	
	

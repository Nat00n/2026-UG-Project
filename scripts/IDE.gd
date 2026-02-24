extends Control

const pythonSubset = preload("res://scripts/pythonSubset.gd")
const lexer = preload("res://scripts/lexer.gd")

@onready var inputCE: CodeEdit = $Panel/VSplitContainer/CodeEditor
@onready var outputRCT: RichTextLabel = $Panel/VSplitContainer/OutputBox
@onready var runButton: Button = $Panel/VSplitContainer/HSplitContainer/RunButton

func _ready():
	runButton.pressed.connect(_on_button_pressed)


func _on_button_pressed():
	
	outputRCT.clear()
	
	var code = inputCE.get_text()
	
	print(code)
	
	var lex = lexer.new()
	var tokens = lex.tokenise(code)
	
	for t in tokens:
		outputRCT.append_text(str(t))
	
	
	

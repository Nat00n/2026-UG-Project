extends Control

const pythonSubset = preload("res://scripts/pythonSubset.gd")
const lexer = preload("res://scripts/lexer.gd")
const token = preload("res://scripts/token.gd")

@onready var inputCE: CodeEdit = $VSplitContainer/CodeEditor
@onready var outputRCT: RichTextLabel = $VSplitContainer/OutputBox
@onready var runButton: Button = $Panel/VSplitContainer/HSplitContainer/RunButton

func _ready():
	runButton.pressed.connect(_on_button_pressed)


func _on_button_pressed():
	
	outputRCT.clear()
	
	var code = inputCE
	
	var lex = lexer.new(code)
	var tokens = lex.tokenise()
	
	for t in tokens:
		outputRCT.append_text(str(t.type) + " " + t.value + "\n")
	
	#var interpret = pythonSubset.new()
	#var result = interpret.run(code)
	#$outputRCT.text = str(result)
	

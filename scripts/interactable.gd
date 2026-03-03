extends Area2D

@onready var hoverLabel: Label = $hoverLabel
@onready var visual: ColorRect = $visual
@export var objectName: String = "new"

var _hovered := false
var _popup: CanvasLayer

func _ready():
	hoverLabel.visible = false

func _process(_delta):
	var mouse = get_global_mouse_position()
	var rect = Rect2(visual.global_position, visual.size)
	
	var was_hovered = _hovered
	_hovered = rect.has_point(mouse)
	
	if _hovered != was_hovered:
		hoverLabel.visible = _hovered

func _input(event):
	if _hovered and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			print("clicked")
			if _popup:
				print("popup exists")
				_popup.open(objectName)
			else:
				print("popup is null")

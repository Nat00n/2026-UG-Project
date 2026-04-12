extends Control
class_name RoomProgressIndicator

# Visual indicator showing dots for each room with completion highlighting

@export var dotRadius: float = 8.0
@export var dotSpacing: float = 25.0
@export var completedColor: Color = Color(0.3, 0.9, 0.3)  # Green
@export var incompleteColor: Color = Color(0.4, 0.4, 0.4)  # Gray
@export var outlineColor: Color = Color.WHITE

var totalRooms: int = 0
var completedRooms: Array[int] = []
var currentRoom: int = 0

func setup(roomCount: int, completed: Array[int], current: int = 0):
	totalRooms = roomCount
	completedRooms = completed.duplicate()
	currentRoom = current
	
	# Resize control to fit all dots
	var totalWidth = (roomCount - 1) * dotSpacing + dotRadius * 4
	custom_minimum_size = Vector2(totalWidth, dotRadius * 4)
	size = custom_minimum_size
	
	queue_redraw()

func updateCompletion(completed: Array[int], current: int = -1):
	completedRooms = completed.duplicate()
	if current >= 0:
		currentRoom = current
	queue_redraw()

func _draw():
	if totalRooms == 0:
		return
	
	# Calculate starting position to center the dots
	var totalWidth = (totalRooms - 1) * dotSpacing
	var startX = (size.x - totalWidth) / 2.0
	var centerY = size.y / 2.0
	
	for i in range(totalRooms):
		var pos = Vector2(startX + i * dotSpacing, centerY)
		var isCompleted = completedRooms.has(i)
		var isCurrent = (i == currentRoom)
		
		# Determine colors
		var fillColor = completedColor if isCompleted else incompleteColor
		var outline = outlineColor if isCurrent else Color(0.6, 0.6, 0.6)
		var outlineThickness = 2.5 if isCurrent else 1.5
		
		# Draw outline (using outlineThickness instead of fixed value)
		draw_circle(pos, dotRadius + outlineThickness - 1.5, outline)
		
		# Draw dot
		draw_circle(pos, dotRadius, fillColor)
		
		# Draw checkmark if completed
		if isCompleted:
			drawMiniCheckmark(pos, dotRadius * 0.6)

func drawMiniCheckmark(pos: Vector2, checkSize: float):
	var p1 = pos + Vector2(-checkSize * 0.4, 0)
	var p2 = pos + Vector2(-checkSize * 0.1, checkSize * 0.35)
	var p3 = pos + Vector2(checkSize * 0.4, -checkSize * 0.4)
	
	draw_line(p1, p2, Color.WHITE, 2.0)
	draw_line(p2, p3, Color.WHITE, 2.0)

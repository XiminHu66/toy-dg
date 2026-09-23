extends Control
signal selected(id: String)
signal moved(id: String, point: Vector2i)
var items: Array = []
var bounds := Vector2i(6,5)
var cell := 44.0
var font: Font
var selected_id := ""
var drag_id := ""
var editable := true
var catalog: Dictionary

func _ready() -> void:
	custom_minimum_size = Vector2(bounds)*cell
	mouse_filter = Control.MOUSE_FILTER_STOP

func at(point: Vector2i) -> String:
	for item in items:
		if Rect2i(Vector2i(int(item.x),int(item.y)),Vector2i(int(item.w),int(item.h))).has_point(point):
			return str(item.id)
	return ""

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id := at(Vector2i(event.position/cell))
		if not id.is_empty():
			selected.emit(id)

func _get_drag_data(position_value: Vector2) -> Variant:
	if not editable:
		return null
	var id := at(Vector2i(position_value/cell))
	if id.is_empty():
		return null
	var preview := Label.new()
	preview.text = "移动装备"
	preview.add_theme_font_override("font",font)
	set_drag_preview(preview)
	selected.emit(id)
	return {"id":id,"source":get_instance_id()}

func _can_drop_data(_position_value: Vector2,data: Variant) -> bool:
	return editable and data is Dictionary and data.get("source",0) == get_instance_id()

func _drop_data(position_value: Vector2,data: Variant) -> void:
	moved.emit(str(data.id),Vector2i(position_value/cell))

func _draw() -> void:
	for y in range(bounds.y):
		for x in range(bounds.x):
			draw_rect(Rect2(Vector2(x,y)*cell,Vector2.ONE*(cell-2)),Color("15222f"))
	for item in items:
		var rect := Rect2(Vector2(float(item.x),float(item.y))*cell+Vector2.ONE,Vector2(float(item.w),float(item.h))*cell-Vector2.ONE*4)
		var color := Color(str(catalog.rarities[int(item.rarity)].color))
		draw_rect(rect,Color(color,0.14))
		draw_rect(rect,color if item.id == selected_id else Color(color,0.45),false,2 if item.id == selected_id else 1)
		var center_value := rect.get_center()
		if item.type == "weapon":
			draw_line(center_value+Vector2(-9,16),center_value+Vector2(10,-18),color,4)
			draw_line(center_value+Vector2(-11,5),center_value+Vector2(4,13),color,3)
		elif item.type == "armor":
			draw_colored_polygon(PackedVector2Array([center_value+Vector2(-14,-12),center_value+Vector2(14,-12),center_value+Vector2(10,14),center_value+Vector2(-10,14)]),Color(color,0.6))
		else:
			draw_arc(center_value,10,0,TAU,24,color,3)
		if rect.size.x >= 70:
			draw_string(font,rect.position+Vector2(6,17),str(item.name).left(4),HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)
		if item.get("found",false):
			draw_circle(rect.position+Vector2(rect.size.x-6,6),3,Color("6fe1c5"))

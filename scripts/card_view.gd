extends Button
const Cards = preload("res://scripts/cards.gd")
var card_id := "strike"
var font: Font
var chosen := false
var ordinal := 0
var summary := ""
var compact := false
var hover_amount := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(188,216 if not compact else 192)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = Cards.DATA[card_id].text + ("\n"+summary if not summary.is_empty() else "")
	for state in ["normal","hover","pressed","focus","disabled"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())

func _process(delta: float) -> void:
	hover_amount = move_toward(hover_amount,1.0 if is_hovered() or chosen else 0.0,delta*8)
	queue_redraw()

func _draw() -> void:
	var card: Dictionary = Cards.DATA[card_id]
	var color := Color(card.color)
	if disabled:
		color = color.darkened(0.5)
	var rect := Rect2(Vector2(3,10-hover_amount*7),size-Vector2(6,13))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("182434") if not chosen else Color("27394a")
	style.border_color = color if chosen or is_hovered() else Color(color,0.45)
	style.set_border_width_all(2 if chosen else 1)
	style.set_corner_radius_all(10)
	draw_style_box(style,rect)
	draw_rect(Rect2(rect.position+Vector2(1,46),Vector2(rect.size.x-2,49)),Color(color,0.09))
	var center := Vector2(size.x/2,rect.position.y+70)
	if card.has("attack"):
		draw_line(center+Vector2(-17,14),center+Vector2(17,-14),color,3,true)
		draw_line(center+Vector2(-13,-5),center+Vector2(2,11),color,2,true)
	elif card.has("block"):
		draw_polyline(PackedVector2Array([center+Vector2(-14,-12),center+Vector2(14,-12),center+Vector2(12,9),center+Vector2(0,18),center+Vector2(-12,9),center+Vector2(-14,-12)]),color,2,true)
	else:
		draw_arc(center,17,0,TAU,32,color,2,true)
		draw_line(center+Vector2(-24,0),center+Vector2(24,0),color,2,true)
	draw_circle(rect.position+Vector2(22,24),15,color)
	draw_string(font,rect.position+Vector2(16,30),str(card.cost),HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("0d1823"))
	draw_string(font,rect.position+Vector2(45,31),card.name,HORIZONTAL_ALIGNMENT_LEFT,-1,19,color)
	draw_string(font,rect.position+Vector2(12,115),summary if not summary.is_empty() else card.type,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-24,13,color)
	draw_multiline_string(font,rect.position+Vector2(12,138),card.text,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-24,13,4,Color("c2cbd9"))
	if not compact:
		draw_string(font,rect.position+Vector2(12,rect.size.y-10),"消耗" if card.get("exhaust",false) else card.type,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("91a0b3"))
		if ordinal>0:
			draw_string(font,rect.position+Vector2(rect.size.x-25,rect.size.y-10),str(ordinal%10),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("91a0b3"))

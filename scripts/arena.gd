extends Control
signal target_clicked(id: String)
signal card_dropped(index: int,id: String)
var session: RefCounted
var font: Font
var selected := ""
var background := preload("res://assets/art/sealed-sanctum.webp")
var portrait := preload("res://assets/art/rin.webp")
var pulse := 0.0
var elapsed := 0.0
var preview_card := ""
const Cards = preload("res://scripts/cards.gd")

func _ready() -> void:
	custom_minimum_size = Vector2(680,270)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true

func animate() -> void:
	pulse = 1.0

func _process(delta: float) -> void:
	pulse = maxf(0,pulse-delta*1.8)
	elapsed += delta
	queue_redraw()

func enemy_center(i: int) -> Vector2:
	return Vector2(size.x*(0.64+0.21*i),size.y*0.34)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in range(session.enemies.size()):
			if session.enemies[i].hp>0 and Rect2(enemy_center(i)-Vector2(95,140),Vector2(190,280)).has_point(event.position):
				target_clicked.emit(session.enemies[i].id)

func text_at(point: Vector2,text_value: String,color: Color,font_size: int = 16,centered: bool = true) -> void:
	var width := font.get_string_size(text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	draw_string(font,point-Vector2(width/2 if centered else 0,0),text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func bar(point: Vector2,width: float,value: float,maximum: float,color: Color) -> void:
	draw_rect(Rect2(point,Vector2(width,6)),Color("14202e"))
	draw_rect(Rect2(point,Vector2(width*clampf(value/maxf(maximum,1),0,1),6)),color)

func _draw() -> void:
	var texture_size := background.get_size()
	var zoom := maxf(size.x/texture_size.x,size.y/texture_size.y)
	var crop_size := size/zoom
	draw_texture_rect_region(background,Rect2(Vector2.ZERO,size),Rect2((texture_size-crop_size)*Vector2(0.5,0.6),crop_size))
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.025,0.045,0.075,0.28))
	# One continuous scene; only soft shading supports the overlaid HUD and cards.
	for strip in range(24):
		var alpha := pow(float(strip)/24,2)*0.68
		draw_rect(Rect2(0,size.y*0.57+strip*size.y*0.43/24,size.x,size.y*0.43/24+1),Color(0.02,0.035,0.06,alpha))
	draw_rect(Rect2(0,0,size.x,61),Color(0.02,0.035,0.06,0.55))
	for mote in range(16):
		var point := Vector2(fmod(mote*173.0+sin(elapsed*0.3+mote)*18,size.x),fmod(mote*79.0-elapsed*9+size.y*10,size.y))
		draw_circle(point,1.5,Color(0.55,0.85,0.9,0.13+0.1*sin(elapsed+mote)))
	var ground := size.y*0.49
	var hero := Vector2(size.x*0.2,ground)
	var attack_shift := sin(pulse*PI)*18 if session.last_result.get("kind","")=="card" else 0.0
	var h := ground-65
	draw_texture_rect(portrait,Rect2(Vector2(hero.x-h*0.32+attack_shift,ground-h),Vector2(h*0.66,h)),false)
	text_at(Vector2(hero.x,ground+17),"凛 · 拾遗者",Color("e9edf3"),18)
	bar(Vector2(hero.x-83,ground+25),166,session.player.hp,session.player.max_hp,Color("79cdb6"))
	text_at(Vector2(hero.x,ground+49),"生命 %d/%d   格挡 %d" % [session.player.hp,session.player.max_hp,session.player.block],Color("b5e4da"),14)
	var player_bleed := 0
	for effect in session.player.bleeds:
		player_bleed += int(effect.damage)
	if player_bleed>0:
		text_at(Vector2(hero.x,ground+65),"流血 %d/回合（无视格挡）" % player_bleed,Color("e194a6"),12)
	for i in range(session.enemies.size()):
		var target: Dictionary = session.enemies[i]
		if target.hp<=0:
			continue
		var center := enemy_center(i)+Vector2(0,sin(elapsed*2+i)*3)
		if pulse>0 and session.last_result.get("target_id","")==target.id:
			center.x += sin((1-pulse)*65)*pulse*9
		var col := Color("daa57b") if i==0 else Color("be9bdc")
		if selected == target.id:
			draw_arc(center,64,0,TAU,64,Color(col,0.8),2,true)
			draw_circle(center,68,Color(col,0.06))
		if target.id in ["watcher","warden"]:
			var points := PackedVector2Array([center+Vector2(0,-65),center+Vector2(40,-28),center+Vector2(53,37),center+Vector2(14,28),center+Vector2(0,57),center+Vector2(-14,28),center+Vector2(-53,37),center+Vector2(-40,-28)])
			draw_colored_polygon(points,Color("242638"))
			draw_polyline(points+PackedVector2Array([points[0]]),col,3,true)
			draw_line(center+Vector2(-19,-13),center+Vector2(19,-13),Color("f9c991"),4,true)
			draw_line(center+Vector2(0,0),center+Vector2(0,27),col,3,true)
		else:
			for j in range(4):
				var vec := Vector2.from_angle(j*PI/2+PI/4)*48
				draw_line(center+vec*0.4,center+vec,col,5,true)
			draw_colored_polygon(PackedVector2Array([center+Vector2(0,-33),center+Vector2(32,0),center+Vector2(0,37),center+Vector2(-32,0)]),Color("312a48"))
			draw_circle(center,12,col)
		var intent: Dictionary = target.intent
		var msg := "%s %d × %d" % [intent.name,session.intent_damage(target),intent.hits] if int(intent.hits)>0 else "%s +%d" % [intent.name,intent.block]
		text_at(Vector2(center.x,86),msg,Color("f5b49e") if int(intent.hits)>0 else Color("8bd1d0"),20)
		text_at(Vector2(center.x,107),"失衡：本次伤害减半" if target.broken else "下一步意图",Color("b1b7c8"),12)
		text_at(Vector2(center.x,ground+17),target.name,col,18)
		bar(Vector2(center.x-78,ground+25),156,target.hp,target.max_hp,col)
		text_at(Vector2(center.x,ground+47),"%d/%d   格挡 %d   韧性 %d" % [target.hp,target.max_hp,target.block,target.toughness],Color("d5d6de"),13)
		var bleed_damage := 0
		for effect in target.bleeds:
			bleed_damage += int(effect.damage)
		var effects := "流血 %d/回合   易伤 %d回合" % [bleed_damage,target.vulnerable]
		text_at(Vector2(center.x,ground+65),effects,Color("bc9eb2"),12)
		if not preview_card.is_empty() and Cards.DATA[preview_card].has("attack"):
			text_at(Vector2(center.x,131),"预计 %d / 暴击 %d" % [session.card_damage(Cards.DATA[preview_card],target),session.card_damage(Cards.DATA[preview_card],target,true)],Color("fff1c5"),15)
		if pulse>0 and session.last_result.get("target_id","")==target.id:
			draw_line(center+Vector2(-38,32)*pulse,center+Vector2(38,-32)*pulse,Color(1,0.87,0.65,pulse),5,true)
			text_at(center+Vector2(0,-25-(1-pulse)*38),"-%d" % session.last_result.get("damage",0),Color(1,0.87,0.65,pulse),28)
	if pulse>0 and session.last_result.get("kind","")=="enemy_turn":
		text_at(hero+Vector2(0,-100-(1-pulse)*35),"-%d" % session.last_result.get("damage",0),Color(1,0.52,0.51,pulse),28)

func _can_drop_data(point: Vector2,data: Variant) -> bool:
	if not data is Dictionary or data.get("kind","")!="card" or session.phase!="combat" or data.get("turn",-1)!=session.round_no:
		return false
	var index := int(data.get("index",-1))
	if index<0 or index>=session.hand.size() or session.hand[index]!=data.get("id",""):
		return false
	if not Cards.DATA[data.id].has("attack"):
		return point.x<size.x*0.42
	for i in range(session.enemies.size()):
		if session.enemies[i].hp>0 and Rect2(enemy_center(i)-Vector2(95,140),Vector2(190,280)).has_point(point):
			return true
	return false

func _drop_data(point: Vector2,data: Variant) -> void:
	if not _can_drop_data(point,data):
		return
	var id := ""
	if Cards.DATA[data.id].has("attack"):
		for i in range(session.enemies.size()):
			if session.enemies[i].hp>0 and Rect2(enemy_center(i)-Vector2(95,140),Vector2(190,280)).has_point(point):
				id = session.enemies[i].id
				break
	card_dropped.emit(int(data.index),id)

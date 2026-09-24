extends Control
const Session = preload("res://scripts/session.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Arena = preload("res://scripts/arena.gd")
const CardView = preload("res://scripts/card_view.gd")
const Cards = preload("res://scripts/cards.gd")
const InventoryView = preload("res://scripts/inventory_view.gd")
const ExplorationView = preload("res://scripts/exploration_view.gd")
const SceneBackdrop = preload("res://scripts/scene_backdrop.gd")
const Rules = preload("res://scripts/rules.gd")
var atlas: Control
var help_window: AcceptDialog
var feedback: PanelContainer
var scene_background: Control
var map_seen: Array = []
var map_origin := -1
const RESOURCE_HELP := {
 "金币":"金币 / 永久资产\n撤离结算、出售装备获得。用于购买、强化、附魔与寻宝。",
 "本局":"本局收益 / 尚未结算\n地下城宝箱、战斗和事件获得，成功撤离后变成永久金币。",
 "战意":"战意 / 回合资源\n每回合恢复为2，上限8。基础攻击和防御可补充。\n回合结束剩余至多3点，每点转为2格挡；韧性达20时为3格挡。",
 "灵纹":"灵纹 / 本次探索资源\n每场战斗获得2，研习牌获得2，上限12。跨战斗保留，回营清空。\n战斗研习：购牌3–5、精简3、刷新1。",
 "侦察":"侦察 / 探索次数\n开局按感知获得1–3次。选择侦察模式再点相邻未知房间。\n只揭示类型，不进入、不触发事件；重复侦察不扣次数。",
 "疗伤药":"疗伤药 / 探索补给\n每次出征补充2瓶。战斗中花1战意使用，恢复最多30生命。",
 "背包":"随身背包 / 6×5格\n拖拽整理，选择装备后按R旋转。青色圆点是本局战利品。\n营地可以转入10×8仓库；成功撤离才能保住本局新物品。"
}
var game := Session.new()
var font: Font
var body: HBoxContainer
var footer: RichTextLabel
var header_stats: Label
var selection := ""
var selected_container := "bag"
var target_id := ""
var selected_card := -1
var camp_tab := "出征"
var map_mode := "探索"
var craft_id := ""
var hand_views: Array = []
var hand_dock: Control
var rendered_hand: Array = []
var rendered_round := -1
var entering_cards: Array = []
var combat_busy := false
var market_window: AcceptDialog
var input_shield: Control
var build_version := "0.3.dev"
var board: Control
var item_details: RichTextLabel
var item_buttons: HBoxContainer
var bag_view: Control
var stash_view: Control
var toast := ""
var save_ok := true
var quit_after_test := false

func _ready() -> void:
	if OS.has_feature("launcher") or "--launcher-smoke" in OS.get_cmdline_user_args():
		get_tree().call_deferred("change_scene_to_file","res://launcher/launcher.tscn")
		return
	if FileAccess.file_exists("res://data/build.json"):
		var info: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/build.json"))
		if info is Dictionary:
			build_version = str(info.get("version",build_version))
	font = load("res://assets/fonts/DungeonSans.ttf")
	var theme_value := Theme.new()
	theme_value.default_font = font
	theme_value.default_font_size = 16
	theme_value.set_color("font_color","Label",Color("dce5ef"))
	theme_value.set_color("font_color","Button",Color("dce5ef"))
	theme_value.set_color("font_hover_color","Button",Color("ffffff"))
	theme_value.set_color("font_disabled_color","Button",Color("63788b"))
	theme_value.set_stylebox("normal","Button",box("203b46",7))
	theme_value.set_stylebox("hover","Button",box("345465",8))
	theme_value.set_stylebox("pressed","Button",box("346a68",8))
	theme_value.set_stylebox("disabled","Button",box("192632",8))
	theme_value.set_stylebox("panel","AcceptDialog",box("101e2c",10))
	theme_value.set_stylebox("panel","TooltipPanel",box("102c37",8))
	theme_value.set_color("font_color","TooltipLabel",Color("ecdfbd"))
	theme_value.set_font_size("font_size","TooltipLabel",15)
	theme_value.set_stylebox("background","ProgressBar",box("152632",4))
	theme_value.set_stylebox("fill","ProgressBar",box("4d9d91",4))
	set_theme(theme_value)
	scene_background = SceneBackdrop.new()
	scene_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scene_background)
	game.load_game()
	if "--capture" in OS.get_cmdline_user_args() or "--smoke" in OS.get_cmdline_user_args():
		game = Session.new(23)
		game.save_path = "user://ui-test-profile.json"
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+edge,16)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation",10)
	margin.add_child(page)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 50
	page.add_child(header)
	var title_column := VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_column)
	label(title_column,"地城拾遗",29,"eef3fa")
	label(title_column,"RELIC / RUNNER     ·     牌与遗物",12,"76b7b2")
	header_stats = label(header,"",16,"e8cc99")
	header_stats.tooltip_text = RESOURCE_HELP["金币"]+"\n\n"+RESOURCE_HELP["本局"]
	button(header,"? 手册",show_help).tooltip_text = "展开资源、战斗、探索和营地规则"
	body = HBoxContainer.new()
	body.add_theme_constant_override("separation",18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	var footer_panel := PanelContainer.new()
	footer_panel.add_theme_stylebox_override("panel",box("0e1b28",10))
	footer_panel.custom_minimum_size.y = 42
	page.add_child(footer_panel)
	footer = RichTextLabel.new()
	footer.bbcode_enabled = true
	footer.scroll_following = true
	footer.add_theme_font_override("normal_font",font)
	footer.add_theme_font_size_override("normal_font_size",14)
	footer_panel.add_child(footer)
	refresh()
	if "--capture" in OS.get_cmdline_user_args():
		for tab in ["出征","仓库","商店","工坊","抽奖","牌组"]:
			camp_tab = tab
			refresh()
			await capture_screen({"出征":"camp","仓库":"warehouse","商店":"shop","工坊":"workshop","抽奖":"draw","牌组":"deck"}[tab])
		show_help()
		help_window.get_child(0).get_child(0).get_child(0).get_child(0).get_child(0).pressed.emit()
		await capture_screen("handbook")
		close_help()
		game.start_run()
		game.reveal_tile(1)
		refresh()
		await capture_screen("explore")
		game.start_encounter()
		refresh()
		await capture_screen("combat")
		show_market()
		await capture_screen("market")
		close_market()
		selected_card = game.hand.find("strike")
		refresh()
		await capture_screen("targeting")
		game.draw_cards(10)
		refresh()
		await capture_screen("hand-ten")
		get_window().size = Vector2i(1280,720)
		await capture_screen("combat-720p")
		get_window().size = Vector2i(960,600)
		await capture_screen("combat-small")
		get_window().size = Vector2i(1440,900)
		game.start_encounter()
		refresh()
		await get_tree().create_timer(0.8).timeout
		for i in range(game.hand.size()):
			if Cards.DATA[game.hand[i]].has("attack"):
				submit_card(i,game.enemies[0].id)
				break
		await capture_motion("play")
		end_combat_turn()
		await capture_motion("turn")
		print("CAPTURE_OK")
		get_tree().quit()
	if "--smoke" in OS.get_cmdline_user_args():
		game.start_run()
		refresh()
		await settle_layout("explore")
		for i in range(35):
			if atlas.hit(atlas.center(i))!=i:
				push_error("Map hit target mismatch")
			var tile: Dictionary = game.dungeon[i]
			if not tile.seen and not tile.scouted and "未知房间" not in atlas.describe(i):
				push_error("Map leaked hidden room")
		show_help()
		await get_tree().process_frame
		if not is_instance_valid(help_window) or not help_window.visible:
			push_error("Resource handbook did not open")
		close_help()
		map_mode = "标记"
		atlas.activated.emit(1)
		if not game.dungeon[1].flag:
			push_error("Map flag interaction failed")
		atlas.flagged.emit(1)
		var scouts_before := game.scouts
		map_mode = "侦察"
		atlas.activated.emit(1)
		if not game.dungeon[1].scouted or game.dungeon[1].seen or game.scouts!=scouts_before-1:
			push_error("Scouting should reveal without entering")
		map_mode = "探索"
		atlas.activated.emit(1)
		if not game.dungeon[1].seen or game.map_position!=1:
			push_error("Map exploration interaction failed")
		game.start_encounter()
		refresh()
		await settle_layout("combat")
		# Drive the actual card signal and arena drop handler, not only the rule API.
		var attack_index := -1
		for i in range(game.hand.size()):
			if Cards.DATA[game.hand[i]].has("attack") and Cards.DATA[game.hand[i]].cost<=game.energy:
				attack_index = i
				break
		if attack_index>=0:
			var count_before := game.hand.size()
			hand_views[attack_index].pressed.emit()
			if selected_card!=attack_index:
				push_error("Card click did not select attack")
			var drag := {"kind":"card","index":attack_index,"id":game.hand[attack_index],"turn":game.round_no}
			board._drop_data(board.enemy_center(0),drag)
			var energy_after := game.energy
			submit_card(attack_index,game.enemies[0].id)
			if game.energy!=energy_after or not combat_busy:
				push_error("Animation input lock did not prevent duplicate play")
			await get_tree().create_timer(0.7).timeout
			if game.hand.size()!=count_before-1+int(Cards.DATA[drag.id].get("draw",0)):
				push_error("Drag-to-enemy did not play card")
		show_market()
		await get_tree().process_frame
		if not is_instance_valid(market_window) or not market_window.visible:
			push_error("Study market did not open")
		close_market()
		var round_before := game.round_no
		end_combat_turn()
		end_combat_turn()
		await get_tree().create_timer(1.2).timeout
		if game.round_no!=round_before+1 or combat_busy:
			push_error("Animated turn transition did not finish exactly once")
		game.draw_cards(10)
		refresh()
		for dimensions in [Vector2i(1440,900),Vector2i(1280,720),Vector2i(960,600)]:
			get_window().size = dimensions
			await settle_layout("combat-resize")
		get_window().size = Vector2i(1440,900)
		for test_phase in ["event","loot","exit","camp"]:
			game.phase = test_phase
			if test_phase=="loot":
				game.pending_loot = [game.make_item(0,3),game.make_item(3,2)]
				game.card_rewards = ["reap","bastion","echo"]
			refresh()
			await settle_layout(test_phase)
		for tab in ["出征","仓库","商店","工坊","抽奖","牌组"]:
			camp_tab = tab
			refresh()
			await settle_layout(tab)
			if tab in ["工坊","抽奖"]:
				expand_rule_panels(body)
				await settle_layout(tab+"-expanded")
		game.gold = 500
		game.stash.clear()
		camp_tab = "抽奖"
		refresh()
		draw_relic()
		draw_relic()
		await get_tree().create_timer(1.6).timeout
		if game.gold!=380 or combat_busy or game.stash.size()!=1:
			push_error("Relic reveal did not protect against duplicate purchase")
		print("UI_SMOKE_OK")
		get_tree().quit()

func expand_rule_panels(parent: Node) -> void:
	for child in parent.get_children():
		if child is Button and child.text.begins_with("＋ "):
			child.pressed.emit()
		expand_rule_panels(child)

func settle_layout(name_value: String) -> void:
	await get_tree().create_timer(0.65).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	check_layout(name_value)

func capture_screen(name_value: String) -> void:
	await get_tree().create_timer(0.75).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/screenshots/"+name_value+".png")

func capture_motion(prefix: String) -> void:
	for i in range(20):
		await get_tree().create_timer(0.05).timeout
		await RenderingServer.frame_post_draw
		var frame := get_viewport().get_texture().get_image()
		frame.resize(864,540)
		frame.save_png("res://build/screenshots/motion-%s-%02d.png" % [prefix,i])

func check_layout(phase_name: String) -> void:
	var rect := body.get_global_rect()
	if rect.end.y > get_viewport_rect().size.y-42 or rect.end.x > get_viewport_rect().size.x:
		push_error("Interface exceeds viewport: "+phase_name+" "+str(rect))
	if game.phase=="combat":
		if hand_views.size()!=game.hand.size():
			push_error("Missing hand controls")
		for view in hand_views:
			if not view.is_visible_in_tree() or view.size.x<100 or not get_viewport_rect().encloses(view.get_global_rect()):
				push_error("Card is hidden or offscreen: "+phase_name)

func box(hex: String, radius: int = 12) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = Color(hex)
	result.set_corner_radius_all(radius)
	result.border_color = Color("395460")
	result.set_border_width_all(1)
	if hex=="101e2c":
		result.bg_color = Color(0.035,0.075,0.11,0.89)
	result.content_margin_left = 14
	result.content_margin_right = 14
	result.content_margin_top = 10
	result.content_margin_bottom = 10
	return result

func label(parent: Node,text_value: String,font_size: int = 16,color: String = "dce5ef") -> Label:
	var result := Label.new()
	result.text = text_value
	result.add_theme_font_size_override("font_size",font_size)
	result.add_theme_color_override("font_color",Color(color))
	parent.add_child(result)
	return result

func paragraph(parent: Node,text_value: String,color: String = "94aaba") -> Label:
	var result := label(parent,text_value,15,color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result

func button(parent: Node,text_value: String,action: Callable,disabled: bool = false) -> Button:
	var result := Button.new()
	result.text = text_value
	result.custom_minimum_size.y = 38
	result.disabled = disabled
	result.pressed.connect(action)
	parent.add_child(result)
	for resource in RESOURCE_HELP:
		if resource in text_value:
			result.tooltip_text = RESOURCE_HELP[resource]
			break
	result.mouse_entered.connect(func():
		if not result.disabled:
			result.create_tween().tween_property(result,"self_modulate",Color("baffed"),0.12))
	result.mouse_exited.connect(func(): result.create_tween().tween_property(result,"self_modulate",Color.WHITE,0.18))
	return result

func panel(parent: Node,expand: bool = false) -> VBoxContainer:
	var container := PanelContainer.new()
	container.add_theme_stylebox_override("panel",box("101e2c"))
	if expand:
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(container)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	container.add_child(column)
	return column

func clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func refresh() -> void:
	atlas = null
	scene_background.visible = game.phase!="combat"
	hand_views.clear()
	hand_dock = null
	clear(body)
	board = null
	bag_view = null
	stash_view = null
	header_stats.text = "v%s  ·  %s   /   金币 %d   /   本局 %d" % [build_version,"营地" if game.phase == "camp" else "探索中",game.gold,game.run_gold]
	item_details = null
	item_buttons = null
	if game.phase == "combat":
		combat(body)
	else:
		rendered_hand.clear()
		rendered_round = -1
		var left := panel(body,true)
		match game.phase:
			"camp": camp(left)
			"explore": explore_room(left)
			"loot": loot(left)
			"event": event_room(left)
			"exit": exit_room(left)
		var right_wrap := ScrollContainer.new()
		right_wrap.custom_minimum_size.x = 350
		right_wrap.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		right_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(right_wrap)
		var right := panel(right_wrap)
		right.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		build_right(right)
	if game.phase!="combat":
		body.modulate.a = 0.25
		body.create_tween().tween_property(body,"modulate:a",1.0,0.22)
	else:
		body.modulate.a = 1.0
	footer.clear()
	for line in game.log_lines.slice(maxi(0,game.log_lines.size()-1)):
		footer.append_text("[color=#b4c5d5]"+str(line)+"[/color]\n")
	if not toast.is_empty():
		footer.append_text("[color=#f2c981]"+toast+"[/color]\n")

func finish_action(success: bool) -> void:
	toast = "" if success else game.last_error
	if success:
		save_ok = game.save_game()
		if not save_ok:
			toast = "存档写入失败，请保持页面打开。"
	refresh()
	if board != null:
		board.animate()
	if not success:
		notify_result(game.last_error,false)
	elif game.phase=="camp" or game.phase=="explore":
		if not game.log_lines.is_empty():
			notify_result(str(game.log_lines[-1]),true)

func camp(column: VBoxContainer) -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation",10)
	column.add_child(tabs)
	for tab in ["出征","仓库","商店","工坊","抽奖","牌组"]:
		button(tabs,("● " if camp_tab==tab else "")+tab,func(): camp_tab=tab; refresh())
	if camp_tab == "商店":
		shop_room(column)
		return
	if camp_tab == "工坊":
		craft_room(column)
		return
	if camp_tab == "抽奖":
		draw_room(column)
		return
	if camp_tab == "仓库":
		label(column,"遗物档案 / 仓库",25,"e9d2aa")
		paragraph(column,"选择查看词条与估值；拖拽整理，R 旋转。右侧操作可穿戴、出售或转移。")
		var tools_row := HBoxContainer.new()
		column.add_child(tools_row)
		button(tools_row,"全部入库",func(): finish_action(game.deposit_all()))
		button(tools_row,"整理仓库",func(): finish_action(game.tidy_stash()))
		button(tools_row,"前往交易",func(): camp_tab="商店"; refresh())
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(scroll)
		stash_view = make_inventory(scroll,game.stash,Session.STASH,49,"stash")
		return
	if camp_tab == "牌组":
		label(column,"出征牌组 · %d 张" % game.starting_deck().size(),25,"e9d2aa")
		paragraph(column,"基础牌 + 武器专属牌 + 特殊装备牌。战后获得的卡牌仅在本次探索中保留，装备长期保留。")
		deck_grid(column,game.starting_deck())
		return
	var hero := Control.new()
	hero.custom_minimum_size.y = 280
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(hero)
	var art := SceneBackdrop.new()
	art.dim = 0.08
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hero.add_child(art)
	var shade := PanelContainer.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 335
	shade.add_theme_stylebox_override("panel",box("0b1b29d9",0))
	hero.add_child(shade)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation",16)
	shade.add_child(words)
	label(words,"S E A L E D   O B S E R V A T O R Y",12,"84cbbb")
	label(words,"星骸观测站",32,"f2e2c4")
	paragraph(words,"灯火尚未熄灭。\n带上你的牌组，再入迷雾。","b5c8cc")
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	words.add_child(space)
	label(words,"封印矿井 · 35个未知房间",16,"e3c98f")
	var go := button(words,"启程探索  →",func(): selected_card=-1; target_id=""; map_seen.clear(); map_origin=-1; finish_action(game.start_run()))
	go.custom_minimum_size.y = 52
	go.add_theme_stylebox_override("normal",box("386e66",7))
	var services := HBoxContainer.new()
	services.add_theme_constant_override("separation",12)
	column.add_child(services)
	for entry in [["仓库","01 / 整理遗物","格子管理 · 查看估值"],["商店","02 / 遗物交易","出售战利品 · 补充底材"],["工坊","03 / 打造流派","强化装备 · 附魔技能"]]:
		var card := panel(services,true)
		label(card,entry[1],17,"e2d0a6")
		paragraph(card,entry[2])
		button(card,"进入"+entry[0]+"  →",func(): camp_tab=entry[0]; refresh())
	paragraph(column,"探索 → 收集 → 撤离 → 养成。准备好后启程，也可以随时打开右上角手册。")

func card_summary(id: String) -> String:
	var card: Dictionary = Cards.DATA[id]
	if card.has("attack"):
		var damage := game.card_damage(card,{"defense":0,"bleeds":[],"vulnerable":0})
		return "基础伤害 %d%s" % [damage," / +1战意" if card.get("energy",0)>0 else ""]
	if card.has("runes"):
		return "+%d灵纹 · 本场消耗" % card.runes
	if card.has("construct"):
		return "持续阵式 · 本场生效"
	if card.has("block"):
		return "%d格挡%s" % [game.card_block(card)," / +1战意" if card.get("energy",0)>0 else ""]
	return "抽 %d 张" % card.draw if card.has("draw") else "+2战意 / -5生命"

func make_card(parent: Node,id: String,action: Callable,index: int = -1,disabled_value: bool = false) -> Button:
	var view := CardView.new()
	view.card_id = id
	view.font = font
	view.summary = card_summary(id)
	view.ordinal = index+1
	view.turn = game.round_no
	view.chosen = index>=0 and index==selected_card
	view.disabled = disabled_value
	view.pressed.connect(action)
	parent.add_child(view)
	return view

func deck_grid(parent: Node,ids: Array) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",10)
	scroll.add_child(grid)
	for id in ids:
		make_card(grid,id,func(): pass)

func show_pile(title_value: String,ids: Array) -> void:
	var window := AcceptDialog.new()
	window.title = title_value
	window.ok_button_text = "返回"
	add_child(window)
	var margin := MarginContainer.new()
	margin.offset_bottom = -50
	window.add_child(margin)
	deck_grid(margin,ids)
	window.confirmed.connect(window.queue_free)
	window.canceled.connect(window.queue_free)
	window.popup_centered(Vector2i(840,550))

func combat(parent: Control) -> void:
	var previous := rendered_hand.duplicate() if rendered_round==game.round_no else []
	entering_cards.clear()
	for id in game.hand:
		var found := previous.find(id)
		entering_cards.append(found<0)
		if found>=0:
			previous.remove_at(found)
	rendered_hand = game.hand.duplicate()
	rendered_round = game.round_no
	board = Arena.new()
	board.session = game
	board.font = font
	board.selected = target_id
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(board)
	var top := HBoxContainer.new()
	board.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 22
	top.offset_right = -22
	top.offset_top = 12
	var title := label(top,"核心守卫" if game.encounter_kind=="boss" else ("精英遭遇" if game.encounter_kind=="elite" else "迷雾遭遇"),22,"e5d1ad")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label(top,"第 %d 回合 · 手牌 %d" % [game.round_no,game.hand.size()],17,"c8d2e3")
	button(top,"研习 · 灵纹 %d" % game.runes,show_market)
	button(top,"行囊",show_bag)
	button(top,"战斗记录",show_log)
	if selected_card>=0 and selected_card<game.hand.size():
		board.preview_card = game.hand[selected_card]
	board.target_clicked.connect(on_target)
	board.card_dropped.connect(submit_card)
	var engines := label(board," / ".join(game.constructs.map(func(id): return Cards.DATA[id].name)),14,"c9b4e9")
	engines.position = Vector2(24,64)
	engines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_dock = Control.new()
	hand_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(hand_dock)
	hand_dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hand_dock.offset_top = -300
	hand_dock.offset_bottom = -54
	var hint := label(hand_dock,"手牌  /  点击选牌，或拖到敌人出牌；技能可直接点击或拖向角色。",14,"a8c8cc")
	hint.position = Vector2(24,-20)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if selected_card>=0 and selected_card<game.hand.size():
		hint.text = "已选择「%s」· 点击敌人 / Esc 取消" % Cards.DATA[game.hand[selected_card]].name
	for i in range(game.hand.size()):
		var index := i
		var card: Dictionary = Cards.DATA[game.hand[i]]
		var view := make_card(hand_dock,game.hand[i],func(): select_card(index),i,game.energy<int(card.cost) or game.player.hp<=int(card.get("hp_cost",0)))
		hand_views.append(view)
		view.hovered.connect(func(v): v.focus_hand(true))
		view.unhovered.connect(func(v): v.focus_hand(false))
	hand_dock.resized.connect(arrange_hand)
	call_deferred("arrange_hand")
	if game.hand.is_empty():
		var empty := label(hand_dock,"手牌已打空。结束回合后重新抽牌。",22,"e6d6b6")
		empty.position = Vector2(320,100)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",10)
	board.add_child(actions)
	actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	actions.offset_left = 22
	actions.offset_right = -22
	actions.offset_top = -48
	actions.offset_bottom = -10
	label(actions,"战意 %d" % game.energy,25,"83e0cf").tooltip_text = RESOURCE_HELP["战意"]
	button(actions,"抽牌 %d" % game.draw_pile.size(),func(): var cards: Array=game.draw_pile.duplicate(); cards.sort(); show_pile("抽牌堆 · 不显示顺序",cards))
	button(actions,"弃牌 %d" % game.discard_pile.size(),func(): show_pile("弃牌堆",game.discard_pile))
	button(actions,"本回合 %d" % game.played_pile.size(),func(): show_pile("已打出 · 回合结束入弃牌堆",game.played_pile))
	var status_label := label(actions,"蓄势 +%d%%" % int(game.momentum*100) if game.momentum>0 else "留力 +%d格挡" % game.reserve_block(),14,"9caec0")
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(actions,"疗伤药 ×%d" % game.potions,func(): selected_card=-1; finish_action(game.heal()),game.energy<1 or game.potions<1 or game.player.hp>=game.player.max_hp)
	var end := button(actions,"结束回合 [空格]",end_combat_turn)
	end.add_theme_stylebox_override("normal",box("70554a",8))

func arrange_hand() -> void:
	if hand_dock==null or not is_instance_valid(hand_dock) or hand_views.is_empty():
		return
	var count := hand_views.size()
	var step := minf(158.0,(hand_dock.size.x-260)/maxf(1,count-1))
	var left := (hand_dock.size.x-(180+step*(count-1)))/2
	for i in range(count):
		var view = hand_views[i]
		var fan := (float(i)-(count-1)*0.5)/maxf(1,(count-1)*0.5)
		view.size = Vector2(180,230)
		view.pivot_offset = Vector2(90,210)
		view.rest_position = Vector2(left+step*i,5+absf(fan)*16)
		view.rest_angle = fan*0.075
		view.z_index = 20 if view.chosen else i
		if not view.hand_placed:
			view.hand_placed = true
			if entering_cards[i]:
				view.deal_in(Vector2(20,150),i*0.045)
			else:
				view.position = view.rest_position
				view.rotation = view.rest_angle
		else:
			view.focus_hand(false)

func select_card(index: int) -> void:
	if combat_busy:
		return
	if index<0 or index>=game.hand.size():
		return
	var card: Dictionary = Cards.DATA[game.hand[index]]
	if card.has("attack"):
		selected_card = -1 if selected_card==index else index
		refresh()
	else:
		selected_card = -1
		submit_card(index,"")

func on_target(id: String) -> void:
	if combat_busy:
		return
	target_id = id
	if selected_card>=0:
		var index := selected_card
		selected_card = -1
		submit_card(index,id)
	else:
		refresh()


func lock_combat(value: bool) -> void:
	combat_busy = value
	if value:
		input_shield = Control.new()
		input_shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		input_shield.mouse_filter = Control.MOUSE_FILTER_STOP
		input_shield.z_index = 80
		add_child(input_shield)
	elif is_instance_valid(input_shield):
		input_shield.queue_free()
		input_shield = null

func submit_card(index: int,id: String = "") -> void:
	if combat_busy or index<0 or index>=game.hand.size():
		return
	var card_id: String = game.hand[index]
	var origin: Vector2 = hand_views[index].global_position
	var destination: Vector2 = board.global_position+Vector2(board.size.x*0.2,board.size.y*0.35)
	for i in range(game.enemies.size()):
		if game.enemies[i].id==id:
			destination = board.global_position+board.enemy_center(i)
	if not game.play_card(index,id):
		finish_action(false)
		return
	lock_combat(true)
	selected_card = -1
	hand_views[index].hide()
	var ghost := make_card(self,card_id,func(): pass)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.z_index = 90
	ghost.position = origin
	ghost.pivot_offset = Vector2(90,115)
	var tween := ghost.create_tween().set_parallel(true)
	tween.tween_property(ghost,"position",destination-Vector2(90,115),0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(ghost,"scale",Vector2(0.3,0.3),0.25)
	tween.tween_property(ghost,"rotation",0.25,0.25)
	tween.tween_property(ghost,"modulate:a",0.15,0.25)
	await tween.finished
	ghost.queue_free()
	finish_action(true)
	impact_flash(destination,Color(Cards.DATA[card_id].color))
	lock_combat(false)

func impact_flash(point: Vector2,color: Color) -> void:
	for i in range(8):
		var spark := ColorRect.new()
		spark.color = color
		spark.size = Vector2(5,16)
		spark.position = point
		spark.rotation = i*TAU/8
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.z_index = 95
		add_child(spark)
		var tween := spark.create_tween().set_parallel(true)
		tween.tween_property(spark,"position",point+Vector2.from_angle(i*TAU/8)*90,0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark,"modulate:a",0.0,0.3)
		tween.chain().tween_callback(spark.queue_free)

func end_combat_turn() -> void:
	if combat_busy or game.phase!="combat":
		return
	lock_combat(true)
	selected_card = -1
	for view in hand_views:
		view.discard_out(Vector2(hand_dock.size.x-70,120))
	await get_tree().create_timer(0.23).timeout
	var success := game.end_turn()
	finish_action(success)
	if success and game.phase=="combat":
		var banner := label(self,"第 %d 回合" % game.round_no,32,"e9d2aa")
		banner.z_index = 90
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		banner.position = body.global_position+Vector2(body.size.x*0.45,body.size.y*0.2)
		banner.modulate.a = 0
		var tween := banner.create_tween()
		tween.tween_property(banner,"modulate:a",1.0,0.12)
		tween.tween_interval(0.35)
		tween.tween_property(banner,"modulate:a",0.0,0.18)
		tween.tween_callback(banner.queue_free)
	await get_tree().create_timer(0.4).timeout
	lock_combat(false)

func show_market() -> void:
	if combat_busy or game.phase!="combat":
		return
	market_window = AcceptDialog.new()
	market_window.title = "研习市场 · 灵纹 %d/12 · 本场购买 %d/2" % [game.runes,game.market_buys]
	market_window.ok_button_text = "返回战斗"
	add_child(market_window)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	market_window.add_child(column)
	paragraph(column,"灵纹来自每场入场+2与研习牌。新牌进入弃牌堆；牌组与灵纹只在本次探索保留。")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	column.add_child(row)
	for i in range(game.market.size()):
		var index := i
		var id: String = game.market[i]
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(cell)
		label(cell,"%s · %d灵纹" % [Cards.DATA[id].school,Cards.DATA[id].price],18,"d2b3eb")
		make_card(cell,id,func(): pass)
		button(cell,"研习入组",func(): market_action(game.acquire_card(index)),game.runes<int(Cards.DATA[id].price) or game.market_buys>=2 or game.run_deck.size()>=18)
	var options := HBoxContainer.new()
	column.add_child(options)
	button(options,"刷新 · 1灵纹",func(): market_action(game.refresh_market()),game.market_refresh_used or game.runes<1)
	for id in ["strike","guard","study"]:
		button(options,"精简%s · 3" % Cards.DATA[id].name,func(): market_action(game.purge_card(id)),game.purge_used or game.runes<3 or game.run_deck.size()<=8 or not game.run_deck.has(id))
	paragraph(column,"本局牌组 %d/18 · 每场精简一次，至少留8张。免费基础牌积累战意，强力牌消耗战意；未用战意（最多3）在敌人行动前转为格挡。" % game.run_deck.size())
	button(column,"查看牌组 / 消耗 / 阵式",func(): show_pile("本局牌组（包含阵式和本场消耗）",game.run_deck))
	market_window.confirmed.connect(close_market)
	market_window.canceled.connect(close_market)
	market_window.popup_centered(Vector2i(780,480))

func close_market() -> void:
	if is_instance_valid(market_window):
		market_window.queue_free()
		market_window = null

func market_action(success: bool) -> void:
	close_market()
	selected_card = -1
	finish_action(success)
	show_market()

func show_log() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "探索记录"
	dialog.dialog_text = "\n".join(game.log_lines.slice(maxi(0,game.log_lines.size()-18)))
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(820,530))

func show_bag() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "随身行囊 · 战斗中只读"
	add_child(dialog)
	var column := VBoxContainer.new()
	dialog.add_child(column)
	label(column,"空间管理在战斗结束后开放。装备与金币均保持原规则。",14)
	make_inventory(column,game.bag,Session.BAG,50,"bag")
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(650,410))

func loot(column: VBoxContainer) -> void:
	label(column,"战利品 / FIELD RECOVERY",13,"68cdb9")
	label(column,"战利品与新的可能",25,"edf1f7")
	paragraph(column,"右侧背包中的青色标记代表本局新获得的物品。撤离才能保住它们；继续探索会放弃地上未拾取的物品。")
	if not game.card_rewards.is_empty():
		label(column,"战术领悟 · 三选一加入本局牌组（可跳过）",17,"c4a5ef")
		var rewards := HBoxContainer.new()
		rewards.add_theme_constant_override("separation",12)
		column.add_child(rewards)
		for id in game.card_rewards:
			make_card(rewards,id,func(): finish_action(game.choose_reward(id)))
	var gear_row := HBoxContainer.new()
	gear_row.add_theme_constant_override("separation",12)
	column.add_child(gear_row)
	for item in game.pending_loot:
		var card := panel(gear_row,true)
		var color: String = game.catalog.rarities[int(item.rarity)].color
		label(card,"%s · %s" % [game.catalog.rarities[int(item.rarity)].name,item.name],18,color)
		paragraph(card,item_description(item).replace("\n","  "),"c2cbd6")
		var id: String = item.id
		button(card,"收入背包  ·  %d × %d" % [item.w,item.h],func(): finish_action(game.take_loot(id)))
	if game.pending_loot.is_empty():
		paragraph(column,"这里已经没有待拾取的装备。")
	var stretch := Control.new()
	stretch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(stretch)
	var row := HBoxContainer.new()
	column.add_child(row)
	button(row,"继续探索  →",func(): finish_action(game.continue_route()))
	button(row,"立即撤离" if game.can_extract() else "返回地图后可回入口撤离",func(): finish_action(game.extract()),not game.can_extract())

func event_room(column: VBoxContainer) -> void:
	label(column,"03 / 遗迹事件",13,"68cdb9")
	label(column,"墙后，传来另一种心跳。",28,"e9d5b1")
	paragraph(column,"裂开的符文墙中嵌着一只旧时代的匣子。你可以观察封印的规律，或以意志压制其中的回声。骰子只在作出选择后投掷。")
	paragraph(column,"成功：获得一件稀有装备与25金币。失败：失去10生命（最低保留1点），事件仍然推进。每个祭坛只能检定一次。")
	button(column,"观察封印 · 感知 %d%%" % game.player.perception,func(): finish_action(game.resolve_event("perception")))
	button(column,"压制回声 · 意志 %d%%" % game.player.will,func(): finish_action(game.resolve_event("will")))
	button(column,"放弃匣子，继续探索",func(): finish_action(game.resolve_event("leave")))
	button(column,"撤离",func(): finish_action(game.extract()),not game.can_extract())

func exit_room(column: VBoxContainer) -> void:
	label(column,"05 / 返回地面",13,"68cdb9")
	label(column,"封印沉寂，行囊渐重。",28,"e9d5b1")
	paragraph(column,"本次探索完成。带着战利品回到营地，整理、出售或强化装备，为下一次深入做好准备。")
	button(column,"返回营地  ·  结算%d金币" % game.run_gold,func(): finish_action(game.extract()))

func build_right(column: VBoxContainer) -> void:
	label(column,"凛 / RELIC RUNNER",18,"e6edf7")
	var stats: Dictionary = game.player
	label(column,"生命 %d / %d" % [stats.hp,stats.max_hp],19,"6ed8bf")
	paragraph(column,"攻击 %d   防御 %d   敏捷 %d\n速度 %d   移动力 %d   破甲 %d\n暴击 %d%%   暴击倍率 %.2f\n感知 %d   意志 %d" % [stats.attack,stats.defense,stats.agility,stats.speed,stats.movement,stats.penetration,stats.crit,stats.crit_damage/100.0,stats.perception,stats.will])
	var hp_bar := ProgressBar.new()
	hp_bar.max_value = stats.max_hp
	hp_bar.value = stats.hp
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size.y = 7
	column.add_child(hp_bar)
	button(column,"属性与流派说明  ›",show_help).tooltip_text = "防御／敏捷增强格挡，速度增加首回合抽牌\n移动力强化掠影／影步，意志增强心刃\n韧性 %d：减轻流血；达到20时提高留力格挡" % stats.toughness
	for slot in game.equipment:
		var item: Dictionary = game.equipment[slot]
		label(column,"▸ %s +%d" % [item.name,item.level],14,str(game.catalog.rarities[int(item.rarity)].color))
	var used := 0
	for item in game.bag:
		used += int(item.w)*int(item.h)
	label(column,"随身背包  /  %d · 30格" % used,16,"c5d4df").tooltip_text = RESOURCE_HELP["背包"]
	bag_view = make_inventory(column,game.bag,Session.BAG,43,"bag")
	item_details = RichTextLabel.new()
	item_details.custom_minimum_size.y = 115
	item_details.fit_content = true
	item_details.bbcode_enabled = true
	item_details.add_theme_font_override("normal_font",font)
	item_details.add_theme_font_size_override("normal_font_size",14)
	column.add_child(item_details)
	item_buttons = HBoxContainer.new()
	item_buttons.add_theme_constant_override("separation",5)
	column.add_child(item_buttons)
	refresh_selection()
	label(column,"%s" % ("每次操作后自动保存" if save_ok else "存档写入失败"),12,"708a9c")

func make_inventory(parent: Node,items: Array,bounds: Vector2i,cell: float,source: String) -> Control:
	var view := InventoryView.new()
	view.font = font
	view.items = items
	view.bounds = bounds
	view.cell = cell
	view.catalog = game.catalog
	view.editable = game.phase != "combat"
	view.selected_id = selection if selected_container == source else ""
	view.selected.connect(func(id): selection=id; selected_container=source; refresh_selection())
	view.moved.connect(func(id,point): finish_action(Inventory.move(items,id,point,bounds)))
	parent.add_child(view)
	return view

func selected_item() -> Dictionary:
	var items: Array = game.bag if selected_container == "bag" else game.stash
	for item in items:
		if item.id == selection:
			return item
	return {}

func item_description(item: Dictionary) -> String:
	var text_value := "出售 %d金币   每格 %.1f金币\n" % [item.value,float(item.value)/(item.w*item.h)]
	for key in ["attack","defense","hp"]:
		if item.has(key):
			var names := {"attack":"攻击","defense":"防御","hp":"生命"}
			text_value += "%s +%d  " % [names[key],int(item[key])+int(item.level)*2]
	for affix in item.affixes + ([item.enchantment] if item.has("enchantment") else []):
		text_value += "\n%s%s" % [affix.label,"" if affix.key=="shadowstep" else " +%d" % affix.value]
	if item.has("enchantment"):
		text_value += "\n附魔槽已激活"
	if item.get("locked",false):
		text_value += "  · 已锁定"
	return text_value

func refresh_selection() -> void:
	if item_details == null or not is_instance_valid(item_details):
		return
	if bag_view != null:
		bag_view.selected_id = selection if selected_container=="bag" else ""
		bag_view.queue_redraw()
	if stash_view != null:
		stash_view.selected_id = selection if selected_container=="stash" else ""
		stash_view.queue_redraw()
	clear(item_buttons)
	var item := selected_item()
	item_details.clear()
	if item.is_empty():
		item_details.append_text("[color=#7892a7]选择背包或仓库中的装备查看词条。\n营地可换装、转移和出售。[/color]")
		return
	item_details.append_text("[color=#%s]%s[/color]\n%s" % [game.catalog.rarities[int(item.rarity)].color,item.name,item_description(item)])
	var items: Array = game.bag if selected_container=="bag" else game.stash
	var bounds: Vector2i = Session.BAG if selected_container=="bag" else Session.STASH
	button(item_buttons,"旋转",func(): finish_action(Inventory.move(items,selection,Vector2i(int(item.x),int(item.y)),bounds,true)),game.phase=="combat")
	button(item_buttons,"装备",func(): finish_action(game.equip_item(selection,items)),game.phase!="camp")
	button(item_buttons,"出售",func(): confirm_sell(item,items),game.phase!="camp" or item.get("locked",false))
	button(item_buttons,"锁定" if not item.get("locked",false) else "解锁",func(): finish_action(game.toggle_lock(item.id)),game.phase!="camp")
	button(item_buttons,"转移",func(): finish_action(Inventory.transfer(items,game.stash if selected_container=="bag" else game.bag,selection,Session.STASH if selected_container=="bag" else Session.BAG)),game.phase!="camp")

func confirm_sell(item: Dictionary,items: Array) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "出售装备"
	dialog.dialog_text = "出售「%s」，获得%d金币？\n原型尚未提供赎回，请确认。" % [item.name,item.value]
	dialog.ok_button_text = "确认出售"
	dialog.cancel_button_text = "保留"
	add_child(dialog)
	dialog.confirmed.connect(func(): finish_action(game.sell_item(item.id,items)); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(420,180))

func _unhandled_key_input(event: InputEvent) -> void:
	if combat_busy or is_instance_valid(market_window) or is_instance_valid(help_window):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and game.phase != "combat":
			var item := selected_item()
			if not item.is_empty():
				var items: Array = game.bag if selected_container=="bag" else game.stash
				finish_action(Inventory.move(items,selection,Vector2i(int(item.x),int(item.y)),Session.BAG if selected_container=="bag" else Session.STASH,true))
		if game.phase == "combat":
			if event.keycode == KEY_SPACE:
				selected_card = -1
				end_combat_turn()
			elif event.keycode == KEY_ESCAPE:
				selected_card = -1
				refresh()
			elif event.keycode>=KEY_1 and event.keycode<=KEY_9:
				select_card(event.keycode-KEY_1)
			elif event.keycode==KEY_0:
				select_card(9)

func scrolling_column(parent: Node) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",12)
	scroll.add_child(column)
	return column

func shop_room(column: VBoxContainer) -> void:
	label(column,"遗物交易所",29,"e9d2aa")
	paragraph(column,"基础装备直接购买后入库；出售背包或仓库中的战利品，供养强化与附魔。锁定装备不会被出售。")
	var content := scrolling_column(column)
	label(content,"购买基础装备",18,"81cdbb")
	var goods := GridContainer.new()
	goods.columns = 2
	goods.add_theme_constant_override("h_separation",12)
	goods.add_theme_constant_override("v_separation",12)
	content.add_child(goods)
	for i in range(game.catalog.bases.size()):
		var index := i
		var item: Dictionary = game.catalog.bases[i]
		var product := panel(goods,true)
		label(product,"B A S E  /  %02d" % (i+1),12,"78b8ae")
		label(product,str(item.name),23,"e8d6b7")
		label(product,"占用 %d×%d格 · 回收 %d金币" % [item.w,item.h,item.value],14,"9baebc")
		button(product,"购买入库 · %d金币" % game.shop_price(i),func(): finish_action(game.shop_buy(index)),game.gold<game.shop_price(i))
	label(content,"出售战利品 / 按每格价值比较",18,"e9d2aa")
	var owned: Array = game.bag+game.stash
	owned.sort_custom(func(a,b): return float(a.value)/(a.w*a.h)>float(b.value)/(b.w*b.h))
	if owned.is_empty():
		paragraph(content,"暂无待售装备。下地城找到宝箱或击败敌人，撤离后即可交易。")
	for item in owned:
		var source: Array = game.bag if game.bag.has(item) else game.stash
		var row := HBoxContainer.new()
		content.add_child(row)
		var title := label(row,"%s%s +%d · %d金币 / %.1f每格" % ["锁定 · " if item.get("locked",false) else "",item.name,item.level,item.value,float(item.value)/(item.w*item.h)],15,str(game.catalog.rarities[int(item.rarity)].color))
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button(row,"详情",func(): selection=item.id; selected_container="bag" if is_same(source,game.bag) else "stash"; refresh_selection())
		button(row,"出售",func(): confirm_sell(item,source),item.get("locked",false))

func craft_room(column: VBoxContainer) -> void:
	column = scrolling_column(column)
	label(column,"工坊 / 强化与附魔",29,"e9d2aa")
	foldout(column,"工坊规则与费用","强化最高+5，每级基础属性+2。附魔使用独立词条槽，重铸保留原掉落词条。")
	if game.owned_item(craft_id).is_empty():
		craft_id = game.equipment.weapon.id
	var picker := OptionButton.new()
	picker.custom_minimum_size.y = 40
	column.add_child(picker)
	var owned: Array = game.equipment.values()+game.bag+game.stash
	for i in range(owned.size()):
		picker.add_item("%s +%d%s" % [owned[i].name,owned[i].level," · 已装备" if game.equipment.values().has(owned[i]) else ""])
		if str(owned[i].id)==craft_id:
			picker.select(i)
	picker.item_selected.connect(func(i): craft_id=owned[i].id; refresh())
	var item := game.owned_item(craft_id)
	var details := panel(column)
	label(details,item.name+" +%d" % item.level,24,str(game.catalog.rarities[int(item.rarity)].color))
	paragraph(details,item_description(item),"ccd7e1")
	label(column,"强化 · 每级基础攻击／防御／生命 +2",18,"81cdbb")
	button(column,"强化至 +%d · %d金币" % [int(item.level)+1,game.upgrade_cost(item)],func(): finish_action(game.upgrade_item(craft_id)),game.gold<game.upgrade_cost(item) or item.level>=5)
	label(column,"附魔槽 · "+(str(item.enchantment.label)+" +%d" % item.enchantment.value if item.has("enchantment") else "尚未激活"),18,"c4a5ef")
	paragraph(column,"随机生成一个经典RPG词条，可能获得影步技能。重铸时排除当前附魔种类；费用每次增加40金币。附魔不提高商人回收价。")
	button(column,"%s · %d金币" % ["重铸附魔" if item.has("enchantment") else "附魔",game.enchant_cost(item)],func(): confirm_enchant(item),game.gold<game.enchant_cost(item))
	foldout(column,"查看附魔池","攻击、防御、生命、敏捷、速度、移动力、暴击、暴伤、破甲、韧性、感知、意志、流血、影步。")

func confirm_enchant(item: Dictionary) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "确认附魔"
	dialog.dialog_text = "花费%d金币为「%s」生成随机附魔？\n%s" % [game.enchant_cost(item),item.name,"现有附魔将被替换，原掉落词条保留。" if item.has("enchantment") else "新增一个独立附魔词条。"]
	dialog.ok_button_text = "确认附魔"
	dialog.cancel_button_text = "取消"
	add_child(dialog)
	dialog.confirmed.connect(func(): finish_action(game.enchant_item(item.id)); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(500,200))

func draw_room(column: VBoxContainer) -> void:
	label(column,"遗物寻宝 / 装备抽奖",29,"e9d2aa")
	paragraph(column,"使用探索和交易赚取的游戏金币。获得的装备自动存入仓库，可以穿戴、出售、强化或附魔。")
	var banner := panel(column)
	label(banner,"120 金币 / 次",30,"e9d2aa")
	label(banner,"普通 55% · 魔法 30% · 稀有 13% · 史诗 2%",19,"bdabdc")
	foldout(banner,"概率与保底说明","四种底材等概率。连续9次未出稀有及以上，第10次至少稀有。稀有及以上重置计数。空间不足不扣款。")
	label(banner,"保底进度  %d / 9" % game.draw_pity,23,"83e0cf")
	var bar := ProgressBar.new()
	bar.max_value = 9
	bar.value = game.draw_pity
	bar.show_percentage = false
	banner.add_child(bar)
	button(banner,"唤醒遗物 · 120金币",draw_relic,game.gold<Session.DRAW_COST)
	button(banner,"查看仓库",func(): camp_tab="仓库"; refresh())
	var history := scrolling_column(column)
	label(history,"最近获得",18,"b5cbd6")
	if game.draw_history.is_empty():
		paragraph(history,"还没有抽取记录。空间不足时不会扣款或消耗保底。")
	for entry in game.draw_history:
		label(history,"%s · %s" % [game.catalog.rarities[int(entry.rarity)].name,entry.name],18,str(game.catalog.rarities[int(entry.rarity)].color))

func explore_room(column: VBoxContainer) -> void:
	var top := HBoxContainer.new()
	column.add_child(top)
	var title := label(top,"封印矿井",27,"e9d2aa")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var count := 0
	for tile in game.dungeon:
		if tile.seen:
			count += 1
	label(top,"已探索 %02d / 35" % count,16,"84cbbb")
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation",10)
	column.add_child(controls)
	for mode in ["探索","标记","侦察"]:
		var control := button(controls,("● " if map_mode==mode else "")+mode,func(): map_mode=mode; refresh(),mode=="侦察" and game.scouts<=0)
		control.tooltip_text = {"探索":"进入亮边房间；已清理通道可安全快速通行。","标记":"点击未知房间插旗，再次点击取消；也可直接右键。","侦察":RESOURCE_HELP["侦察"]}[mode]
	label(controls,"侦察 %d" % game.scouts,17,"83e0cf").tooltip_text = RESOURCE_HELP["侦察"]
	atlas = ExplorationView.new()
	atlas.session = game
	atlas.font = font
	atlas.mode = map_mode
	atlas.previous_seen = map_seen.duplicate()
	atlas.origin = map_origin
	atlas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(atlas)
	var context := paragraph(column,"亮边房间可抵达 · 右键标记危险 · 数字统计周围八格","b9cace")
	context.custom_minimum_size.y = 42
	atlas.inspected.connect(func(value): context.text=value)
	atlas.activated.connect(map_click)
	atlas.flagged.connect(func(index): remember_map(); finish_action(game.flag_tile(index)))
	var route := HBoxContainer.new()
	column.add_child(route)
	button(route,"返回入口",func(): remember_map(); finish_action(game.reveal_tile(0))).tooltip_text = "沿已清理的通道安全返回入口，不会重触发事件。"
	button(route,"撤离 · 结算%d金币" % game.run_gold,func(): finish_action(game.extract()),not game.can_extract()).tooltip_text = "在入口或击败核心后撤离，将本局收益存入永久资产。"
	label(route,"目标：深入右下方核心",14,"c6b892")

func remember_map() -> void:
	map_seen.clear()
	for i in range(game.dungeon.size()):
		if game.dungeon[i].seen:
			map_seen.append(i)
	map_origin = game.map_position

func map_click(index: int) -> void:
	remember_map()
	match map_mode:
		"标记": finish_action(game.flag_tile(index))
		"侦察": finish_action(game.scout_tile(index))
		_: finish_action(game.reveal_tile(index))

func show_help() -> void:
	if is_instance_valid(help_window):
		return
	help_window = AcceptDialog.new()
	help_window.title = "探索者手册 · 点击条目展开"
	help_window.ok_button_text = "收起手册"
	add_child(help_window)
	var content := scrolling_column(help_window)
	for key in RESOURCE_HELP:
		foldout(content,key,RESOURCE_HELP[key])
	foldout(content,"地图与危险数字","移动只沿上下左右相邻房间展开；数字统计周围八格最初的战斗或陷阱数量。\n清理危险后数字不减少。零危险通道自动展开，特殊房间进入时才触发。\n鼠标点选，右键插旗；也可聚焦地图后用方向键和回车操作。")
	foldout(content,"卡牌与装备 Build","每回合抽5张。攻击/格挡类基础牌补充战意，强力卡消耗战意。\n已打出的牌在回合结束后才进弃牌堆；牌库空时洗入弃牌。\n攻击与破甲提高输出，防御/敏捷加强格挡，速度改善开局抽牌。\n移动力强化位移牌，意志增强心刃；韧性20提升留力格挡。\n研习购买与战后奖励只在本次探索生效，装备和附魔长期保留。")
	foldout(content,"交易、强化与寻宝","仓库10×8格，装备可锁定防止误售。商店按每格金币估值。\n强化最多+5，每级基础属性+2；费用60起，每级增加40。\n附魔80起，每次增加40：重铸只替换独立槽，不动掉落词条。\n寻宝120金币；普通55%、魔法30%、稀有13%、史诗2%。\n连续9次未出稀有及以上，第10次保底；空间不足不扣款。")
	help_window.confirmed.connect(close_help)
	help_window.canceled.connect(close_help)
	help_window.popup_centered(Vector2i(mini(640,int(size.x)-40),mini(630,int(size.y)-60)))

func close_help() -> void:
	if is_instance_valid(help_window):
		help_window.queue_free()
	help_window = null

func foldout(parent: Node,title_value: String,text_value: String) -> void:
	var column := panel(parent)
	var title := button(column,"＋ "+title_value,func(): pass)
	var details := paragraph(column,text_value,"b6cad4")
	details.hide()
	title.pressed.connect(func(): details.visible=not details.visible; title.text=("－ " if details.visible else "＋ ")+title_value)

func notify_result(message: String,success: bool) -> void:
	if is_instance_valid(feedback):
		feedback.queue_free()
	var popup := PanelContainer.new()
	feedback = popup
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.z_index = 100
	popup.add_theme_stylebox_override("panel",box("173a36" if success else "4b3033",9))
	add_child(popup)
	var text_label := paragraph(popup,("✓  " if success else "!  ")+message,"dbeadd")
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.custom_minimum_size.x = minf(440,size.x-60)
	popup.position = Vector2((size.x-text_label.custom_minimum_size.x)/2,80)
	popup.modulate.a = 0
	var tween := popup.create_tween()
	tween.tween_property(popup,"modulate:a",1.0,0.18)
	tween.tween_interval(2.2)
	tween.tween_property(popup,"modulate:a",0.0,0.4)
	tween.tween_callback(popup.queue_free)

func draw_relic() -> void:
	if combat_busy:
		return
	if not game.draw_equipment():
		finish_action(false)
		return
	# The result is saved before the purely visual reveal, so interruption cannot reroll it.
	save_ok = game.save_game()
	lock_combat(true)
	var veil := ColorRect.new()
	veil.color = Color(0.025,0.04,0.08,0.93)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.z_index = 90
	add_child(veil)
	var display := VBoxContainer.new()
	display.position = size/2-Vector2(220,90)
	display.custom_minimum_size.x = 440
	veil.add_child(display)
	var latest: Dictionary = game.draw_history[0]
	var color: String = game.catalog.rarities[int(latest.rarity)].color
	label(display,"遗物正在苏醒",18,"9cb6c5").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var result := label(display,str(latest.name),34,color)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.modulate.a = 0
	label(display,str(game.catalog.rarities[int(latest.rarity)].name)+" · 已收入仓库",20,color).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tween := veil.create_tween()
	tween.tween_interval(0.25)
	tween.tween_property(result,"modulate:a",1.0,0.45)
	impact_flash(size/2,Color(color))
	await tween.finished
	await get_tree().create_timer(0.65).timeout
	veil.queue_free()
	lock_combat(false)
	finish_action(true)

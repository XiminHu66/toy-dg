extends Control
const Session = preload("res://scripts/session.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Arena = preload("res://scripts/arena.gd")
const CardView = preload("res://scripts/card_view.gd")
const Cards = preload("res://scripts/cards.gd")
const InventoryView = preload("res://scripts/inventory_view.gd")
const Rules = preload("res://scripts/rules.gd")
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
var build_version := "0.2.dev"
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
	theme_value.set_stylebox("normal","Button",box("233744",8))
	theme_value.set_stylebox("hover","Button",box("345465",8))
	theme_value.set_stylebox("pressed","Button",box("346a68",8))
	theme_value.set_stylebox("disabled","Button",box("192632",8))
	theme_value.set_stylebox("panel","AcceptDialog",box("101e2c",10))
	set_theme(theme_value)
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
	header_stats = label(header,"",17,"e8cc99")
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
		game.start_run()
		game.reveal_tile(1)
		refresh()
		await capture_screen("explore")
		game.start_encounter()
		refresh()
		await capture_screen("combat")
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
		print("CAPTURE_OK")
		get_tree().quit()
	if "--smoke" in OS.get_cmdline_user_args():
		game.start_run()
		refresh()
		await settle_layout("explore")
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
			if game.hand.size()!=count_before-1+int(Cards.DATA[drag.id].get("draw",0)):
				push_error("Drag-to-enemy did not play card")
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
		print("UI_SMOKE_OK")
		get_tree().quit()

func settle_layout(name_value: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	check_layout(name_value)

func capture_screen(name_value: String) -> void:
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/screenshots/"+name_value+".png")

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
		var full := panel(body,true)
		combat(full)
	else:
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
	footer.clear()
	for line in game.log_lines.slice(maxi(0,game.log_lines.size()-2)):
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
	label(column,"封印矿井",32,"f1e8d8")
	paragraph(column,"在遗物与回声之间，寻找下一种可能。", "b4c6d4")
	var art := TextureRect.new()
	art.texture = load("res://assets/art/sealed-sanctum.webp")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.custom_minimum_size.y = 190
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(art)
	var itinerary := HBoxContainer.new()
	itinerary.add_theme_constant_override("separation",18)
	column.add_child(itinerary)
	for entry in [["01","揭开迷雾"],["02","战斗寻宝"],["03","返回撤离"],["04","交易养成"]]:
		var step := panel(itinerary,true)
		label(step,entry[0],23,"68cdb9")
		label(step,entry[1],15,"c6cfdc")
	paragraph(column,"3 能量 · 每回合抽 5 张 · 可见敌人意图
探索7×5迷雾地图，数字提示危险；回营后交易、强化、抽奖和附魔。")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",14)
	column.add_child(row)
	var go := button(row,"开始探索  →",func(): selected_card=-1; target_id=""; finish_action(game.start_run()))
	go.custom_minimum_size = Vector2(250,52)
	go.add_theme_stylebox_override("normal",box("356b64",8))
	var cost := 60 + int(game.equipment.weapon.level)*40
	button(row,"强化武器 · %d 金币" % cost,func(): finish_action(game.upgrade_weapon()),game.gold<cost or game.equipment.weapon.level>=5)

func card_summary(id: String) -> String:
	var card: Dictionary = Cards.DATA[id]
	if card.has("attack"):
		return "攻击 ×%.0f%%" % (float(card.attack)*100)
	if card.has("block"):
		return "获得 %d 格挡" % game.card_block(card)
	return "抽 %d 张" % card.draw if card.has("draw") else "获得 2 能量"

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

func combat(column: VBoxContainer) -> void:
	var top := HBoxContainer.new()
	column.add_child(top)
	var title := label(top,"核心守卫" if game.encounter_kind=="boss" else ("精英遭遇" if game.encounter_kind=="elite" else "迷雾遭遇"),22,"e5d1ad")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label(top,"第 %d 回合 · 手牌 %d" % [game.round_no,game.hand.size()],17,"c8d2e3")
	button(top,"行囊",show_bag)
	button(top,"战斗记录",show_log)
	board = Arena.new()
	board.session = game
	board.font = font
	board.selected = target_id
	if selected_card>=0 and selected_card<game.hand.size():
		board.preview_card = game.hand[selected_card]
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.target_clicked.connect(on_target)
	board.card_dropped.connect(func(index,id): selected_card=-1; finish_action(game.play_card(index,id)))
	column.add_child(board)
	hand_dock = Control.new()
	hand_dock.custom_minimum_size.y = 264
	hand_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(hand_dock)
	var hint := label(hand_dock,"手牌  /  点击选牌，或拖到敌人出牌；技能可直接点击或拖向角色。",14,"a8c8cc")
	hint.position = Vector2(12,0)
	if selected_card>=0 and selected_card<game.hand.size():
		hint.text = "已选择「%s」· 点击敌人 / Esc 取消" % Cards.DATA[game.hand[selected_card]].name
	for i in range(game.hand.size()):
		var index := i
		var card: Dictionary = Cards.DATA[game.hand[i]]
		var view := make_card(hand_dock,game.hand[i],func(): select_card(index),i,game.energy<int(card.cost) or game.player.hp<=int(card.get("hp_cost",0)))
		hand_views.append(view)
		view.hovered.connect(func(v): v.z_index=30; v.position.y=18)
		view.unhovered.connect(func(v): v.z_index=10 if v.chosen else v.ordinal; arrange_hand())
	hand_dock.resized.connect(arrange_hand)
	call_deferred("arrange_hand")
	if game.hand.is_empty():
		var empty := label(hand_dock,"手牌已打空。结束回合后重新抽牌。",22,"e6d6b6")
		empty.position = Vector2(320,100)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",10)
	column.add_child(actions)
	label(actions,"%d / 3 能量" % game.energy,25,"83e0cf")
	button(actions,"抽牌 %d" % game.draw_pile.size(),func(): var cards: Array=game.draw_pile.duplicate(); cards.sort(); show_pile("抽牌堆 · 不显示顺序",cards))
	button(actions,"弃牌 %d" % game.discard_pile.size(),func(): show_pile("弃牌堆",game.discard_pile))
	button(actions,"消耗 %d" % game.exhaust_pile.size(),func(): show_pile("消耗区",game.exhaust_pile))
	var status_label := label(actions,"蓄势 +%d%%" % int(game.momentum*100) if game.momentum>0 else "1–9/0 选牌 · Esc 取消",14,"9caec0")
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(actions,"疗伤药 ×%d" % game.potions,func(): selected_card=-1; finish_action(game.heal()),game.energy<1 or game.potions<1 or game.player.hp>=game.player.max_hp)
	var end := button(actions,"结束回合 [空格]",func(): selected_card=-1; finish_action(game.end_turn()))
	end.add_theme_stylebox_override("normal",box("70554a",8))

func arrange_hand() -> void:
	if hand_dock==null or not is_instance_valid(hand_dock) or hand_views.is_empty():
		return
	var count := hand_views.size()
	var step := minf(190.0,(hand_dock.size.x-190)/maxf(1,count-1))
	var left := (hand_dock.size.x-(180+step*(count-1)))/2
	for i in range(count):
		var view: Control = hand_views[i]
		view.size = Vector2(180,230)
		view.position = Vector2(left+step*i,24)
		view.z_index = 10 if view.chosen else i

func select_card(index: int) -> void:
	if index<0 or index>=game.hand.size():
		return
	var card: Dictionary = Cards.DATA[game.hand[index]]
	if card.has("attack"):
		selected_card = -1 if selected_card==index else index
		refresh()
	else:
		selected_card = -1
		finish_action(game.play_card(index))

func on_target(id: String) -> void:
	target_id = id
	if selected_card>=0:
		var index := selected_card
		selected_card = -1
		finish_action(game.play_card(index,id))
	else:
		refresh()

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
	paragraph(column,"防御／敏捷增强格挡 · 速度增加首回合抽牌\n移动力强化掠影／影步 · 意志增强心刃", "718ca2")
	for slot in game.equipment:
		var item: Dictionary = game.equipment[slot]
		label(column,"▸ %s +%d" % [item.name,item.level],14,str(game.catalog.rarities[int(item.rarity)].color))
	var used := 0
	for item in game.bag:
		used += int(item.w)*int(item.h)
	label(column,"随身背包  /  %d · 30格" % used,16,"c5d4df")
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
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and game.phase != "combat":
			var item := selected_item()
			if not item.is_empty():
				var items: Array = game.bag if selected_container=="bag" else game.stash
				finish_action(Inventory.move(items,selection,Vector2i(int(item.x),int(item.y)),Session.BAG if selected_container=="bag" else Session.STASH,true))
		if game.phase == "combat":
			if event.keycode == KEY_SPACE:
				selected_card = -1
				finish_action(game.end_turn())
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
	for i in range(game.catalog.bases.size()):
		var index := i
		var item: Dictionary = game.catalog.bases[i]
		var row := HBoxContainer.new()
		content.add_child(row)
		var title := label(row,"%s  ·  %d×%d  ·  购入 %d / 售出 %d" % [item.name,item.w,item.h,game.shop_price(i),item.value],17)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button(row,"购买入库",func(): finish_action(game.shop_buy(index)),game.gold<game.shop_price(i))
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
	label(column,"工坊 / 强化与附魔",29,"e9d2aa")
	paragraph(column,"强化提升装备基础属性，最高+5；附魔使用一个独立词条槽，再次附魔会替换该槽，保留原有掉落词条。")
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
	paragraph(column,"可抽取：攻击、防御、生命、敏捷、速度、移动力、暴击、暴伤、破甲、韧性、感知、意志、流血、影步。")

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
	paragraph(banner,"四种装备底材等概率。连续9次未获得稀有或史诗，第10次至少稀有；获得稀有或史诗后重置计数。")
	label(banner,"保底进度  %d / 9" % game.draw_pity,23,"83e0cf")
	var bar := ProgressBar.new()
	bar.max_value = 9
	bar.value = game.draw_pity
	bar.show_percentage = false
	banner.add_child(bar)
	button(banner,"抽取一次 · 120金币",func(): finish_action(game.draw_equipment()),game.gold<Session.DRAW_COST)
	button(banner,"查看仓库",func(): camp_tab="仓库"; refresh())
	var history := scrolling_column(column)
	label(history,"最近获得",18,"b5cbd6")
	if game.draw_history.is_empty():
		paragraph(history,"还没有抽取记录。空间不足时不会扣款或消耗保底。")
	for entry in game.draw_history:
		label(history,"%s · %s" % [game.catalog.rarities[int(entry.rarity)].name,entry.name],18,str(game.catalog.rarities[int(entry.rarity)].color))

func explore_room(column: VBoxContainer) -> void:
	label(column,"封印矿井 / 迷雾探索",27,"e9d2aa")
	paragraph(column,"亮边格可探索；数字表示周围八格最初的战斗或陷阱数量。右键插旗，零危险通道会自动展开。")
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation",10)
	column.add_child(controls)
	for mode in ["探索","标记","侦察"]:
		button(controls,("● " if map_mode==mode else "")+mode,func(): map_mode=mode; refresh(),mode=="侦察" and game.scouts<=0)
	label(controls,"侦察剩余 %d" % game.scouts,17,"83e0cf")
	var area := CenterContainer.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(area)
	var grid := GridContainer.new()
	grid.columns = Session.Dungeon.WIDTH
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	area.add_child(grid)
	for i in range(game.dungeon.size()):
		var index := i
		var tile: Dictionary = game.dungeon[i]
		var seen: bool = tile.seen
		var accessible: bool = Session.Dungeon.accessible(game.dungeon,i)
		var name_value := "迷雾"
		if seen or tile.scouted:
			name_value = Session.Dungeon.TITLES[tile.kind]
		if tile.flag:
			name_value = "! 标记"
		elif seen and tile.kind=="empty":
			name_value = str(Session.Dungeon.danger(game.dungeon,i))
		elif seen and tile.cleared and tile.kind!="entrance":
			name_value += "\n已清理"
		if i==game.map_position:
			name_value = "● "+name_value
		var cell := button(grid,name_value,func(): map_click(index))
		cell.custom_minimum_size = Vector2(86,68)
		cell.add_theme_font_size_override("font_size",17)
		cell.tooltip_text = "已侦察，进入后才触发" if tile.scouted and not seen else ("可以抵达" if accessible else "先探索相邻区域")
		var bg := "243948" if seen else ("192d3a" if accessible else "101923")
		var style := box(bg,7)
		style.border_color = Color("87d8c5") if i==game.map_position else Color("466677")
		style.set_border_width_all(2 if accessible and not seen or i==game.map_position else 0)
		cell.add_theme_stylebox_override("normal",style)
		cell.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
				finish_action(game.flag_tile(index)))
	var route := HBoxContainer.new()
	route.add_theme_constant_override("separation",12)
	column.add_child(route)
	button(route,"返回入口",func(): finish_action(game.reveal_tile(0)))
	button(route,"撤离结算 · %d金币" % game.run_gold,func(): finish_action(game.extract()),not game.can_extract())
	paragraph(column,"宝箱：装备与金币 · 营火：恢复生命 · 事件：属性检定\n核心守卫位于右下角。可以随时回入口撤离；未撤离的本局收益仍有风险。")

func map_click(index: int) -> void:
	match map_mode:
		"标记": finish_action(game.flag_tile(index))
		"侦察": finish_action(game.scout_tile(index))
		_: finish_action(game.reveal_tile(index))

extends SceneTree
const Session = preload("res://scripts/session.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Rules = preload("res://scripts/rules.gd")
var failures := 0
var checks := 0

func check(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: "+message)

func _initialize() -> void:
	test_rules()
	test_inventory()
	test_combat()
	test_economy()
	test_save()
	test_full_run()
	test_services()
	test_dungeon()
	test_map_run()
	print("TEST_RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func begin_combat(s: RefCounted) -> void:
	s.start_run()
	s.dungeon.clear()
	s.start_encounter()

func test_rules() -> void:
	check(Rules.damage(27,25,0,1.2)==25,"documented noncritical damage")
	check(Rules.damage(27,25,0,1.8)==38,"documented critical damage")
	check(Rules.damage(20,10,999,1)==20,"penetration cannot make defense negative")
	check(Rules.behind(Vector2i(0,0),Vector2i(1,0),Vector2i.RIGHT),"back arc")
	check(not Rules.behind(Vector2i(2,0),Vector2i(1,0),Vector2i.RIGHT),"front arc")
	check(Rules.event_check(60,60)=="成功","event exact boundary succeeds")
	check(Rules.event_check(60,61)=="失败","event above boundary fails")
	check(Rules.event_check(60,12)=="极难成功","extreme event success")
	check(Rules.event_check(0,1)=="失败","zero skill cannot succeed")
	var s := Session.new(10)
	var enemy := s.enemy("test","Test",Vector2i.ZERO,50,10,0,8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9876
	var hits := 0
	var crits := 0
	for _i in range(5000):
		var result := Rules.resolve(s.player,enemy,rng)
		if result.hit:
			hits += 1
			check(result.damage > 0,"positive damage on hit")
		else:
			check(result.damage == 0 and result.dice.is_empty(),"miss does not roll damage")
		if result.crit:
			crits += 1
	check(hits>3900 and hits<4300,"hit distribution around82%")
	check(crits>650 and crits<950,"critical distribution around16% overall")

func test_inventory() -> void:
	var s := Session.new(1)
	var items: Array = []
	var a := s.make_item(0,0)
	var b := s.make_item(2,0)
	check(Inventory.add(items,a,Vector2i(4,3)),"first item fits")
	check(Inventory.add(items,b,Vector2i(4,3)),"second item fits")
	var before := JSON.stringify(items)
	check(not Inventory.move(items,a.id,Vector2i(2,0),Vector2i(4,3)),"overlap rejected")
	check(JSON.stringify(items)==before,"invalid move is atomic")
	check(not Inventory.move(items,a.id,Vector2i(0,0),Vector2i(4,3),true),"rotation overlap rejected")
	check(JSON.stringify(items)==before,"invalid rotation preserves footprint")
	var target: Array = []
	check(not Inventory.transfer(items,target,a.id,Vector2i(1,1)),"small destination rejects transfer")
	check(items.size()==2 and target.is_empty(),"failed transfer cannot lose item")
	check(Inventory.transfer(items,target,a.id,Vector2i(6,5)),"valid transfer")
	check(items.size()==1 and target.size()==1,"successful transfer conserves count")
	check(not Inventory.add(target,a,Vector2i(6,5)),"duplicate id rejected")
	check(Inventory.validate(target,Vector2i(6,5)),"valid grid")
	target.append(a.duplicate(true))
	check(not Inventory.validate(target,Vector2i(6,5)),"duplicate in save rejected")

func test_combat() -> void:
	var s := Session.new(2)
	begin_combat(s)
	check(s.player_turn and s.energy==3 and s.hand.size()==5,"first turn draws five and grants three energy")
	check(s.run_deck.has("heavy"),"sword contributes equipment card")
	check(s.draw_pile.size()+s.hand.size()==s.run_deck.size(),"opening deck conservation")
	var target: Dictionary = s.enemies[0]
	s.hand = ["strike","guard","focus","break","surge"]
	s.player.crit = 0
	var before := s.snapshot()
	check(not s.play_card(0,"missing"),"invalid target rejected")
	check(s.snapshot()==before,"invalid card play has no cost and consumes no RNG")
	var predicted := s.card_damage(Session.Cards.DATA.strike,target)
	var health := int(target.hp)
	check(s.play_card(0,target.id),"attack plays")
	check(target.hp==health-predicted and s.energy==2,"noncritical hit equals preview")
	check(s.play_card(0),"guard plays")
	check(s.player.block==s.card_block(Session.Cards.DATA.guard),"armor and agility contribute to block")
	check(s.play_card(0),"zero cost focus plays")
	check(s.exhaust_pile.has("focus") and not s.discard_pile.has("focus"),"exhaust excludes reshuffle")
	before = s.snapshot()
	check(not s.play_card(s.hand.find("break"),target.id),"insufficient energy rejected")
	check(s.snapshot()==before,"failed energy check atomic")
	s.hand = ["surge"]
	s.player.hp = 5
	check(not s.play_card(0),"HP cost cannot kill player")
	s.player.hp = 60
	check(s.play_card(0) and s.energy==3 and s.player.hp==55,"surge pays HP for energy")
	s.hand = ["dash","strike"]
	s.energy = 3
	s.play_card(0)
	check(s.momentum>0 and s.card_damage(Session.Cards.DATA.strike,target)>predicted,"movement grants next-attack bonus")
	s.play_card(0,target.id)
	check(s.momentum==0,"momentum consumed on attack")
	s.hand = ["break"]
	s.energy = 3
	target.hp = 100
	target.toughness = 5
	s.play_card(0,target.id)
	check(target.broken and target.vulnerable==2,"break applies stagger and vulnerability")
	check(s.intent_damage(target)==int(target.intent.damage*0.5),"stagger updates visible damage")
	s.phase = "event"
	check(not s.play_card(0),"cards unavailable outside combat")
	s.resolve_event("perception")
	before = s.snapshot()
	check(not s.resolve_event("will") and s.snapshot()==before,"event cannot be rerolled")
	var fresh := Session.new(99)
	begin_combat(fresh)
	fresh.draw_pile.clear()
	fresh.hand.clear()
	fresh.discard_pile = ["guard","strike"]
	fresh.exhaust_pile = ["focus"]
	fresh.draw_cards(5)
	check(fresh.hand.size()==2 and fresh.discard_pile.is_empty(),"empty draw pile reshuffles only discard")
	check(not fresh.hand.has("focus"),"exhaust never returns")
	fresh.hand = []
	for _i in range(15):
		fresh.draw_pile.append("strike")
	fresh.draw_cards(15)
	check(fresh.hand.size()==10,"hand limit ten")
	fresh.player.block = 99
	fresh.retain_block = false
	fresh.end_turn()
	check(fresh.player.block==0 and fresh.energy==3,"block expires and energy refreshes at turn start")
	fresh.player.block = 99
	fresh.retain_block = true
	fresh.end_turn()
	check(fresh.player.block>0 and not fresh.retain_block,"bastion retains block for one transition")
	fresh.player.hp = 1
	fresh.player.block = 0
	fresh.enemies[0].intent = {"name":"test","damage":20,"hits":1,"block":0,"bleed":0}
	fresh.end_turn()
	check(fresh.phase=="camp","enemy lethal damage returns to camp")

func test_economy() -> void:
	var s := Session.new(3)
	var charm: Dictionary = s.stash[0]
	check(s.equip_item(charm.id,s.stash),"equip from stash")
	check(s.player.shadowstep==1,"special skill affix applied")
	var initial_gold := s.gold
	check(s.upgrade_weapon(),"upgrade affordable")
	check(s.gold==initial_gold-60 and s.equipment.weapon.level==1,"upgrade cost and level")
	var snapshot := s.snapshot()
	check(not s.upgrade_weapon(),"unaffordable upgrade rejected")
	check(s.snapshot()==snapshot,"unaffordable upgrade atomic")
	var item := s.make_item(3,1)
	Inventory.add(s.bag,item,Session.BAG)
	var price: int = item.value
	check(s.sell_item(item.id,s.bag),"sell item")
	check(s.gold==initial_gold-60+price,"sale pays exactly once")
	check(not s.sell_item(item.id,s.bag),"cannot sell same item twice")
	var protected := s.make_item(3,0)
	Inventory.add(s.bag,protected,Session.BAG)
	begin_combat(s)
	var found := s.make_item(3,1)
	Inventory.add(s.bag,found,Session.BAG)
	s.player.hp = 0
	s.check_battle()
	check(s.phase=="camp" and s.bag.size()==1 and s.bag[0].id==protected.id,"death loses found loot and preserves brought items")
	check(s.player.hp==s.player.max_hp and s.gold>=0,"failure cannot prevent next run")

func test_save() -> void:
	var s := Session.new(4)
	begin_combat(s)
	s.end_turn()
	var data: Variant = JSON.parse_string(JSON.stringify(s.snapshot()))
	var restored := Session.new(999)
	check(restored.restore(data),"JSON save restores")
	check(restored.hand==s.hand and restored.draw_pile==s.draw_pile and restored.energy==s.energy,"card zones and energy restored")
	check(restored.rng.randi()==s.rng.randi(),"64-bit RNG state survives JSON round trip")
	var legacy: Dictionary = s.snapshot()
	legacy.version = 1
	for key in ["run_deck","draw_pile","hand","discard_pile","exhaust_pile","card_rewards","energy","momentum","retain_block"]:
		legacy.erase(key)
	check(restored.restore(legacy),"v1 combat migrates")
	check(restored.gold==s.gold and restored.equipment==s.equipment and restored.player.hp==s.player.hp,"migration preserves economy equipment and health")
	check(restored.round_no==1 and restored.hand.size()==5,"legacy encounter restarts as cards")
	var corrupt: Dictionary = s.snapshot()
	corrupt.hand.append("invented")
	check(not restored.restore(corrupt),"unknown card save rejected")
	data.version = 100
	check(not restored.restore(data),"future version rejected")
	data = JSON.parse_string(JSON.stringify(s.snapshot()))
	data.bag.append(data.equipment.weapon.duplicate(true))
	check(not restored.restore(data),"duplicate equipment id rejected")
	s.save_path = "user://test-profile.json"
	check(s.save_game(),"first disk save")
	s.gold = 321
	check(s.save_game(),"second disk save creates backup")
	var file := FileAccess.open(s.save_path,FileAccess.WRITE)
	file.store_string("corrupted")
	file.close()
	var recovery := Session.new(2)
	recovery.save_path = s.save_path
	check(recovery.load_game() and recovery.gold!=321,"corrupt primary falls back to backup")
	DirAccess.remove_absolute(s.save_path)
	DirAccess.remove_absolute(s.save_path+".bak")

func test_full_run() -> void:
	for seed_value in range(6):
		var s := Session.new(seed_value)
		begin_combat(s)
		# High HP removes balance variance while exercising the real turn and loot loop.
		s.player.hp = 10000
		s.player.max_hp = 10000
		var turns := 0
		while s.phase != "exit" and turns < 100:
			turns += 1
			if s.phase == "combat":
				var plays := 0
				while s.phase=="combat" and plays<20:
					var target_id := ""
					for enemy in s.enemies:
						if enemy.hp>0:
							target_id = enemy.id
							break
					var played := false
					for i in range(s.hand.size()):
						if s.play_card(i,target_id):
							played = true
							break
					plays += 1
					if not played:
						break
				if s.phase=="combat":
					s.end_turn()
			elif s.phase=="loot":
				if not s.card_rewards.is_empty():
					var reward: String = s.card_rewards[0]
					check(s.choose_reward(reward) and not s.choose_reward(reward),"card reward cannot be claimed twice")
				for item in s.pending_loot.duplicate():
					s.take_loot(item.id)
				s.continue_route()
			elif s.phase=="event":
				s.resolve_event("perception")
			else:
				break
		check(s.phase=="exit","full route reaches exit seed %d" % seed_value)
		var carried_gold: int = s.run_gold
		var gold_before: int = s.gold
		check(s.extract(),"extraction succeeds")
		check(s.phase=="camp" and s.gold==gold_before+carried_gold,"gold credited on extraction")
		check(not s.extract(),"cannot extract twice")

func test_services() -> void:
	var s := Session.new(31)
	s.gold = 5000
	var gold_before := s.gold
	check(s.shop_buy(0) and s.gold==gold_before-s.shop_price(0),"shop charges exact listed price")
	var item: Dictionary = s.stash.back()
	check(item.rarity==0 and item.level==0 and not item.found,"shop item is basic and owned")
	check(s.toggle_lock(item.id),"lock item")
	var before := s.snapshot()
	check(not s.sell_item(item.id,s.stash) and before==s.snapshot(),"locked item cannot be sold")
	s.toggle_lock(item.id)
	var original_affixes: Array = item.affixes.duplicate(true)
	check(s.enchant_item(item.id) and item.has("enchantment"),"enchant adds distinct slot")
	var prior_key: String = item.enchantment.key
	check(s.enchant_cost(item)==120,"recast price increases")
	check(s.enchant_item(item.id) and item.enchantment.key!=prior_key,"recast excludes current type")
	check(item.affixes==original_affixes,"enchant preserves original drop affixes")
	check(s.equip_item(item.id,s.stash),"enchanted item can be equipped")
	var calculated := s.build_player()
	check(calculated==s.player,"equipped enchant recalculates actual stats")
	for _i in range(5):
		s.upgrade_weapon()
	before = s.snapshot()
	check(s.equipment.weapon.level==5 and not s.upgrade_weapon() and before==s.snapshot(),"upgrade cap is atomic")
	s.draw_pity = 9
	gold_before = s.gold
	check(s.draw_equipment(),"equipment draw succeeds")
	check(s.stash.back().rarity>=2 and s.draw_pity==0 and s.gold==gold_before-Session.DRAW_COST,"tenth draw guarantees rare and resets")
	var recovered := Session.new(99)
	check(recovered.restore(JSON.parse_string(JSON.stringify(s.snapshot()))),"services save restores")
	check(recovered.draw_history==JSON.parse_string(JSON.stringify(s.draw_history)) and recovered.equipment==JSON.parse_string(JSON.stringify(s.equipment)),"draw results and enchants persist")
	s.gold = 0
	before = s.snapshot()
	check(not s.shop_buy(0) and not s.draw_equipment() and not s.enchant_item(s.equipment.weapon.id),"insufficient gold blocks services")
	check(s.snapshot()==before,"failed services cannot advance RNG or modify inventory")
	var full := Session.new(44)
	full.gold = 9000
	full.stash.clear()
	for _i in range(80):
		Inventory.add(full.stash,full.make_item(3,0),Session.STASH)
	before = full.snapshot()
	check(not full.shop_buy(0) and not full.draw_equipment(),"full warehouse blocks buys and draws")
	check(full.snapshot()==before,"capacity rejection preserves money pity and RNG")
	Inventory.add(full.bag,full.make_item(0,0),Session.BAG)
	before = full.snapshot()
	check(not full.deposit_all() and full.snapshot()==before,"bulk deposit is transactional")
	var ids: Array = []
	for stored in full.stash:
		ids.append(stored.id)
	check(full.tidy_stash() and Inventory.validate(full.stash,Session.STASH),"sort creates legal packing")
	check(full.stash.size()==ids.size(),"sort preserves item count")

func test_dungeon() -> void:
	for seed_value in range(10):
		var s := Session.new(seed_value)
		s.start_run()
		check(s.phase=="explore" and s.dungeon.size()==35,"run starts on fog map")
		check(Session.Dungeon.validate(s.dungeon,0),"generated map valid")
		check(Session.Dungeon.danger(s.dungeon,0)==0,"safe opening area")
		var before := s.snapshot()
		check(not s.reveal_tile(34) and before==s.snapshot(),"cannot jump to hidden boss")
		check(s.flag_tile(1) and not s.reveal_tile(1),"flag prevents accidental reveal")
		s.flag_tile(1)
		check(s.scout_tile(1) and s.scouts==1 and not s.dungeon[1].seen,"scout reveals type without triggering")
		before = s.snapshot()
		check(not s.scout_tile(1) and s.snapshot()==before,"repeat scouting costs nothing")
		check(s.reveal_tile(1) and s.dungeon[1].cleared,"safe reveal succeeds")
		var recovered := Session.new(999)
		check(recovered.restore(JSON.parse_string(JSON.stringify(s.snapshot()))),"map save restores")
		check(recovered.dungeon==s.dungeon and recovered.map_position==s.map_position,"fog and position preserved")
		check(not s.extract(),"must reach extraction point")
		s.reveal_tile(0)
		check(s.extract(),"entry allows safe early extraction")
	var old := Session.new(77)
	begin_combat(old)
	var legacy: Dictionary = old.snapshot()
	legacy.version = 2
	for key in ["dungeon","map_position","encounter_kind","scouts","draw_pity","draw_history"]:
		legacy.erase(key)
	var next := Session.new(99)
	check(next.restore(legacy) and next.hand==old.hand and next.dungeon.is_empty(),"v2 active card encounter continues unchanged")

func test_map_run() -> void:
	var s := Session.new(123)
	s.start_run()
	s.player.hp = 10000
	s.player.max_hp = 10000
	var iterations := 0
	while iterations<500:
		iterations += 1
		if s.phase=="explore":
			if s.dungeon[34].cleared:
				s.reveal_tile(34)
				break
			var next := -1
			for i in range(35):
				if not s.dungeon[i].seen and Session.Dungeon.accessible(s.dungeon,i):
					next = i
					break
			check(next>=0,"map always has a reachable frontier")
			if next<0:
				break
			s.reveal_tile(next)
		elif s.phase=="combat":
			for _play in range(20):
				if s.phase!="combat":
					break
				var id := ""
				for enemy in s.enemies:
					if enemy.hp>0:
						id = enemy.id
						break
				var played := false
				for i in range(s.hand.size()):
					if s.play_card(i,id):
						played = true
						break
				if not played:
					break
			if s.phase=="combat":
				s.end_turn()
		elif s.phase=="loot":
			for item in s.pending_loot.duplicate():
				s.take_loot(item.id)
			if not s.card_rewards.is_empty():
				s.choose_reward(s.card_rewards[0])
			s.continue_route()
		elif s.phase=="event":
			s.resolve_event("perception")
		else:
			break
	check(s.dungeon[34].cleared and s.can_extract(),"fog exploration reaches boss and exit")
	var before := s.gold
	var earned := s.run_gold
	check(s.extract() and s.gold==before+earned,"map loot settles exactly once")
	check(not s.extract(),"cannot settle map twice")

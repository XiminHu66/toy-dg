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
	print("TEST_RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

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
	s.start_run()
	check(s.player_turn and s.ap==2,"player turn reached through speed queue")
	var old_position: Vector2i = s.player.position
	var old_movement: int = s.movement
	check(not s.move_player(Vector2i(3,2)),"wall cannot be entered")
	check(s.player.position==old_position and s.movement==old_movement,"invalid move has no cost")
	var p := s.path(s.player.position,Vector2i(2,3))
	check(p.size()==1,"shortest legal path")
	check(s.move_player(Vector2i(2,3)) and s.movement==old_movement-1,"movement consumes exact path cost")
	check(not s.strike(s.enemies[0].id,"slash") and s.ap==2,"out of range attack costs nothing")
	s.player.position = Vector2i(1,2)
	s.enemies[0].position = Vector2i(5,2)
	check(not s.strike(s.enemies[0].id,"dash"),"dash cannot pass through wall")
	s.player.position = Vector2i(1,0)
	s.enemies[0].position = Vector2i(4,0)
	check(s.strike(s.enemies[0].id,"dash"),"clear straight dash")
	check(s.player.position==Vector2i(3,0) and s.ap==0,"dash ends beside enemy and consumes AP")
	s.ap = 2
	s.player.shadowstep = 1
	check(s.shadowstep(Vector2i(2,1)),"shadowstep with equipment skill")
	check(not s.shadowstep(Vector2i(1,1)),"shadowstep limited once per turn")
	check(s.guard() and s.ap==0,"guard spends AP")
	check(not s.guard(),"guard cannot stack")
	s.phase = "event"
	check(not s.move_player(Vector2i(1,1)),"no combat movement in event")
	s.resolve_event("perception")
	var state := s.snapshot()
	check(not s.resolve_event("will"),"event cannot be rerolled")
	check(s.snapshot()==state,"event repeat cannot mutate state")

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
	s.start_run()
	var found := s.make_item(3,1)
	Inventory.add(s.bag,found,Session.BAG)
	s.player.hp = 0
	s.check_battle()
	check(s.phase=="camp" and s.bag.size()==1 and s.bag[0].id==protected.id,"death loses found loot and preserves brought items")
	check(s.player.hp==s.player.max_hp and s.gold>=0,"failure cannot prevent next run")

func test_save() -> void:
	var s := Session.new(4)
	s.start_run()
	s.move_player(Vector2i(2,3))
	var data: Variant = JSON.parse_string(JSON.stringify(s.snapshot()))
	var restored := Session.new(999)
	check(restored.restore(data),"JSON save restores")
	check(restored.player.position==s.player.position and restored.movement==s.movement,"combat position and resources restored")
	check(restored.rng.randi()==s.rng.randi(),"64-bit RNG state survives JSON round trip")
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
		s.start_run()
		# High HP removes balance variance while exercising the real turn and loot loop.
		s.player.hp = 10000
		s.player.max_hp = 10000
		var turns := 0
		while s.phase != "exit" and turns < 100:
			turns += 1
			if s.phase == "combat":
				var target: Dictionary = {}
				for enemy in s.enemies:
					if enemy.hp>0:
						target = enemy
						break
				var best: Array = []
				if s.distance(s.player.position,target.position)>1:
					for direction in Session.DIRECTIONS:
						var route := s.path(s.player.position,target.position+direction)
						if not route.is_empty() and (best.is_empty() or route.size()<best.size()):
							best = route
					if not best.is_empty():
						s.move_player(best[mini(best.size(),s.movement)-1])
				s.strike(target.id,"rupture")
				if s.phase=="combat":
					s.end_turn()
			elif s.phase=="loot":
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

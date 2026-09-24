extends SceneTree
const Session = preload("res://scripts/session.gd")
func _initialize() -> void:
	var report := {}
	for encounter in ["combat","boss"]:
		for build in ["starter","sword","bleed","bastion","will"]:
			var wins := 0
			var turns := 0
			var damage := 0
			var plays := 0
			for seed_value in range(40):
				var s := Session.new(seed_value)
				s.start_run()
				s.dungeon.clear()
				if build=="sword":
					s.player.attack += 8
					s.player.crit += 15
					s.run_deck.append_array(["break","heavy"])
				elif build=="bleed":
					s.player.bleed = 3
					s.run_deck.append_array(["rupture","reap"])
				elif build=="bastion":
					s.player.defense += 14
					s.player.toughness += 10
					s.run_deck.append_array(["riposte","ward"])
				elif build=="will":
					s.player.will += 25
					s.run_deck.append_array(["echo","forge"])
				s.encounter_kind = encounter
				s.start_encounter()
				while s.phase=="combat" and s.round_no<=20:
					var count := 0
					while count<30 and s.phase=="combat":
						var target := ""
						for enemy in s.enemies:
							if enemy.hp>0:
								target = enemy.id
								break
						var played := false
						# Simple hand-order policy; not an optimal player or balance proof.
						for i in range(s.hand.size()):
							if s.play_card(i,target):
								played = true
								plays += 1
								break
						if not played:
							break
						count += 1
					if s.phase=="combat":
						s.end_turn()
				wins += 1 if s.phase=="loot" else 0
				turns += s.round_no
				damage += 90-int(s.player.hp) if s.phase=="loot" else 90
			report[encounter+"/"+build] = {"seeds":40,"wins":wins,"mean_turns":turns/40.0,"mean_hp_lost":damage/40.0,"mean_cards_played":plays/40.0}
	print("BALANCE_PROBE: "+JSON.stringify(report))
	quit()

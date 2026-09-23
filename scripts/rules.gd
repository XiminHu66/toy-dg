extends RefCounted
## Pure combat rules. Animation never consumes the simulation RNG.

static func chance(attacker: Dictionary, defender: Dictionary, bonus: int = 0) -> int:
	return clampi(78 + int(attacker.agility - defender.agility) + bonus, 5, 95)

static func behind(attacker_pos: Vector2i, target_pos: Vector2i, facing: Vector2i) -> bool:
	var delta := attacker_pos - target_pos
	return delta.x * facing.x + delta.y * facing.y < 0

static func damage(raw: float, defense: float, penetration: float, multiplier: float) -> int:
	return maxi(1, int(floor(raw * multiplier * 100.0 / (100.0 + maxf(0.0, defense - penetration)))))

static func resolve(attacker: Dictionary, defender: Dictionary, rng: RandomNumberGenerator, coefficient: float = 1.0, backstab: bool = false) -> Dictionary:
	var hit_chance := chance(attacker, defender)
	var roll := rng.randi_range(1, 100)
	var result := {"roll":roll, "chance":hit_chance, "hit":roll <= hit_chance, "crit":false, "damage":0, "dice":[]}
	if not result.hit:
		return result
	result.crit = roll <= int(floor(hit_chance * clampf(float(attacker.crit) / 100.0, 0.0, 1.0)))
	var d1 := rng.randi_range(1, 6)
	var d2 := rng.randi_range(1, 6)
	result.dice = [d1, d2]
	var multiplier := 1.2 if backstab else 1.0
	if result.crit:
		multiplier *= float(attacker.crit_damage) / 100.0
	result.damage = damage(float(attacker.attack) * coefficient + d1 + d2, defender.defense, attacker.penetration, multiplier)
	return result

static func event_check(value: int, roll: int) -> String:
	var threshold := clampi(value, 0, 100)
	if roll <= int(threshold / 5.0):
		return "极难成功"
	if roll <= int(threshold / 2.0):
		return "困难成功"
	if roll <= threshold:
		return "成功"
	return "失败"

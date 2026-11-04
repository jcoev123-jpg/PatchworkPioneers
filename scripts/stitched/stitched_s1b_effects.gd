class_name StitchedS1BEffects
extends RefCounted
## Pure Design v4 S1b projections. The battle owns the seeded RNG and all mutations.

const RESOLVE_TRAITS := ["frantic", "hollow", "bitter", "reckless", "cowering"]
const CANDLE_BANDS := [
	{"name": "snuffed", "minimum": 0, "maximum": 0, "fray_percent": 40, "enemy_acc": 0, "enemy_damage_percent": 25, "loot_percent": 100, "opening_side": "foe", "opening_percent": 25},
	{"name": "dark", "minimum": 1, "maximum": 25, "fray_percent": 30, "enemy_acc": 10, "enemy_damage_percent": 15, "loot_percent": 75, "opening_side": "", "opening_percent": 0},
	{"name": "gloom", "minimum": 26, "maximum": 50, "fray_percent": 20, "enemy_acc": 5, "enemy_damage_percent": 10, "loot_percent": 50, "opening_side": "", "opening_percent": 0},
	{"name": "dim", "minimum": 51, "maximum": 75, "fray_percent": 10, "enemy_acc": 0, "enemy_damage_percent": 0, "loot_percent": 25, "opening_side": "", "opening_percent": 0},
	{"name": "bright", "minimum": 76, "maximum": 100, "fray_percent": 0, "enemy_acc": 0, "enemy_damage_percent": 0, "loot_percent": 0, "opening_side": "hero", "opening_percent": 15},
]

static func candle_band(candle: int) -> Dictionary:
	for band in CANDLE_BANDS:
		if candle >= int(band["minimum"]) and candle <= int(band["maximum"]):
			return band.duplicate(true)
	return {}

## All percent increases round UP so even a small fray event feels darker.
static func increased(base: int, percent: int) -> int:
	if base <= 0:
		return 0
	@warning_ignore("integer_division")
	return int((base * (100 + percent) + 99) / 100)

static func fray_gain(base: int, candle: int) -> int:
	return increased(base, int(candle_band(candle).get("fray_percent", 0)))

static func enemy_damage(base: int, candle: int) -> int:
	return increased(base, int(candle_band(candle).get("enemy_damage_percent", 0)))

static func steadfast_damage(base: int) -> int:
	return increased(base, 10)

static func percent_roll_succeeds(roll: int, chance: int) -> bool:
	return roll >= 1 and roll <= chance

static func trait_for_roll(index: int) -> String:
	if index < 0 or index >= RESOLVE_TRAITS.size():
		return ""
	return str(RESOLVE_TRAITS[index])

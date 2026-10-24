class_name CardShortRules
extends RefCounted
## Deterministic, read-only formatter for the terse effect line printed on a hand
## card face. Every phrase comes from one already-validated authored card record:
## this class plays no card, resolves no damage or status order, rolls no RNG and
## never predicts what a cast would actually do.
##
## `applied` optionally carries amounts the caller has already read from the same
## validated record (for example an authored Path/passive bonus printed by the
## owning catalog). It is never computed here.

## Every effect key this formatter can print. An authored key outside this list
## is reported honestly as an undescribed effect instead of being guessed at.
const KNOWN_EFFECT_KEYS := [
	"damage", "hits", "hit_count", "block", "other_ally_block", "block_all",
	"heal", "exposed", "weak", "bleed", "unravel", "bleed_multiplier", "pinned",
	"guarding", "thorns", "draw", "energy", "gain_energy", "self_hp_loss",
	"conditional_damage", "random_target_each_hit", "rng_source",
	"living_targets_only", "duration", "next_attack_damage_bonus",
	"next_turn_energy", "expires",
]
const SEPARATOR := " · "
## Terse markers for the two targeting kinds the face must distinguish.
const ALL_TARGET := "ALL"
const RANDOM_TARGET := "RND"
const SWAP_PHRASE := "swap ally"
const UNKNOWN_PHRASE := "other effects"


## One description of a validated card record:
## {known: bool, phrases: Array[String], line: String, unknown: bool}
## `unknown` is true when the record authors a field (or a shape) this formatter
## cannot read, so the face can say so instead of inventing a number.
static func describe(definition: Variant, applied: Dictionary = {}) -> Dictionary:
	var phrases: Array[String] = []
	if not definition is Dictionary:
		return _result(false, phrases, false)
	var card: Dictionary = definition
	var raw_effects: Variant = card.get("effects", {})
	if card.is_empty() or not raw_effects is Dictionary:
		return _result(false, phrases, false)
	var effects: Dictionary = raw_effects
	var undescribed := false
	# Authored movement rules carry no effects dictionary of their own.
	if str(card.get("action_kind", "")) == "adjacent_swap":
		phrases.append(SWAP_PHRASE)
	if effects.has("damage"):
		var damage := _amount(effects["damage"], -1)
		if damage >= 0:
			phrases.append(_damage_phrase(damage, _hits(effects)))
		else:
			undescribed = true
	if effects.has("block"):
		var block := _amount(effects["block"], -1)
		if block >= 0:
			phrases.append("%d Block" % block)
		else:
			undescribed = true
	# Hold the Line and Bastion Quilt pay other recipients too; never hide them.
	if effects.has("other_ally_block"):
		var ally_block := _amount(effects["other_ally_block"], -1)
		if ally_block >= 0:
			phrases.append("%d Block allies" % ally_block)
		else:
			undescribed = true
	if effects.has("block_all"):
		var all_block := _amount(effects["block_all"], -1)
		if all_block >= 0:
			phrases.append("%d Block" % all_block)
		else:
			undescribed = true
	if effects.has("heal"):
		var heal_phrase := _heal_phrase(effects["heal"])
		if heal_phrase.is_empty():
			undescribed = true
		else:
			phrases.append(heal_phrase)
	for status in ["exposed", "weak", "bleed", "unravel"]:
		if not effects.has(status):
			continue
		var authored := _amount(effects[status], -1)
		if authored <= 0:
			undescribed = true
			continue
		var amount := _amount(applied.get(status, authored), authored)
		phrases.append("%s %d" % [status.capitalize(), amount])
	if effects.has("bleed_multiplier"):
		var multiplier := _amount(effects["bleed_multiplier"], -1)
		if multiplier == 2:
			phrases.append("double Bleed")
		elif multiplier > 2:
			phrases.append("Bleed x%d" % multiplier)
		else:
			undescribed = true
	if effects.has("pinned"):
		var pin_phrase := _pin_phrase(effects["pinned"])
		if pin_phrase.is_empty():
			undescribed = true
		else:
			phrases.append(pin_phrase)
	if effects.has("guarding"):
		if _flag(effects["guarding"]):
			phrases.append("Guard")
		else:
			undescribed = true
	if effects.has("thorns"):
		var thorns := _amount(effects["thorns"], -1)
		if thorns > 0:
			phrases.append("Thorns %d" % thorns)
		else:
			undescribed = true
	if effects.has("draw"):
		var draw := _amount(effects["draw"], -1)
		if draw > 0:
			phrases.append("draw %d" % draw)
		else:
			undescribed = true
	for key in ["gain_energy", "energy"]:
		if not effects.has(key):
			continue
		# One energy phrase only: an explicit gain_energy wins over a bare energy.
		if key == "energy" and effects.has("gain_energy"):
			continue
		var energy := _amount(effects[key], -1)
		if energy > 0:
			phrases.append("+%d energy" % energy)
		else:
			undescribed = true
	if effects.has("next_turn_energy"):
		var credit := _amount(effects["next_turn_energy"], -1)
		if credit > 0:
			phrases.append("+%d energy next turn" % credit)
		else:
			undescribed = true
	if effects.has("self_hp_loss"):
		var cost_hp := _amount(effects["self_hp_loss"], -1)
		if cost_hp > 0:
			phrases.append("-%d HP" % cost_hp)
		else:
			undescribed = true
	if effects.has("next_attack_damage_bonus"):
		var bonus := _amount(effects["next_attack_damage_bonus"], -1)
		if bonus > 0:
			phrases.append("+%d next attack" % bonus)
		else:
			undescribed = true
	if effects.has("conditional_damage"):
		var conditional_phrase := _conditional_phrase(effects["conditional_damage"])
		if conditional_phrase.is_empty():
			undescribed = true
		else:
			phrases.append(conditional_phrase)
	# The authored recipient shape is its own terse phrase so a status-only area
	# or random cast still says so on the face.
	var marker := _target_marker(card, effects)
	if not marker.is_empty():
		phrases.append(marker)
	var unknown := undescribed or has_unknown(definition)
	if unknown:
		phrases.append(UNKNOWN_PHRASE)
	return _result(true, phrases, unknown)


## The complete terse face line, phrases in the fixed authored order.
static func line(definition: Variant, applied: Dictionary = {}) -> String:
	return str(describe(definition, applied).get("line", ""))


## True when the record authors a field this formatter cannot describe.
static func has_unknown(definition: Variant) -> bool:
	if not definition is Dictionary:
		return false
	var raw_effects: Variant = (definition as Dictionary).get("effects", {})
	if not raw_effects is Dictionary:
		return false
	for key in (raw_effects as Dictionary):
		if str(key) not in KNOWN_EFFECT_KEYS:
			return true
	return false


static func _result(known: bool, phrases: Array[String], unknown: bool) -> Dictionary:
	return {"known": known, "phrases": phrases, "line": SEPARATOR.join(phrases),
		"unknown": unknown}


## "%d dmg x%d" for repeated hits; targeting is its own phrase so the all-enemy
## and per-hit-random kinds stay distinct instead of blurring together.
static func _damage_phrase(damage: int, hits: int) -> String:
	var text := "%d dmg" % damage
	if hits > 1:
		text += " x%d" % hits
	return text


## Terse recipient phrase: ALL for an area card, RND for a per-hit random pick.
static func _target_marker(card: Dictionary, effects: Dictionary) -> String:
	if bool(effects.get("random_target_each_hit", false)):
		return RANDOM_TARGET
	match str(card.get("target_kind", "")):
		"enemy_all", "party_all":
			return ALL_TARGET
	return ""


static func _heal_phrase(value: Variant) -> String:
	if value is int and int(value) >= 0:
		return "heal %d" % int(value)
	if not value is Dictionary:
		return ""
	var heal: Dictionary = value
	var amount := _amount(heal.get("amount", -1), -1)
	if amount < 0:
		return ""
	var phrase := "heal %d" % amount
	if str(heal.get("target", "")) == "weakest_living_ally":
		phrase += " weakest"
	if str(heal.get("cap", "")) == "missing_hp":
		phrase += " capped"
	return phrase


static func _pin_phrase(value: Variant) -> String:
	if value is bool:
		return "Pin" if value else ""
	if not value is Dictionary:
		return ""
	var rule: Dictionary = value
	if rule.is_empty():
		return ""
	var bonus := _amount(rule.get("bonus_damage", -1), -1)
	return "Pin +%d" % bonus if bonus >= 0 else "Pin"


static func _conditional_phrase(value: Variant) -> String:
	if not value is Dictionary:
		return ""
	var condition: Dictionary = value
	var empowered := _amount(condition.get("damage", -1), -1)
	if empowered < 0:
		return ""
	var labels: Array[String] = []
	var authored: Variant = condition.get("conditions", [])
	if authored is Array:
		for entry in (authored as Array):
			if not entry is Dictionary:
				continue
			var predicate: Dictionary = entry
			if str(predicate.get("status", "")) == "unravelled":
				if not labels.has("Unravelled"):
					labels.append("Unravelled")
			elif str(predicate.get("gauge", "")) == "unravel" \
					and str(predicate.get("comparison", "")) == "at_least_half":
				if not labels.has("half gauge"):
					labels.append("half gauge")
	if labels.is_empty():
		return "%d dmg conditional" % empowered
	return "%d dmg if %s" % [empowered, "/".join(labels)]


static func _hits(effects: Dictionary) -> int:
	if effects.get("hits") is int:
		return maxi(1, int(effects["hits"]))
	if effects.get("hit_count") is int:
		return maxi(1, int(effects["hit_count"]))
	return 1


static func _amount(value: Variant, fallback: int) -> int:
	return int(value) if value is int else fallback


## Only an authored true flag or a non-empty authored rule dictionary is described.
static func _flag(value: Variant) -> bool:
	if value is bool:
		return bool(value)
	return value is Dictionary and not (value as Dictionary).is_empty()

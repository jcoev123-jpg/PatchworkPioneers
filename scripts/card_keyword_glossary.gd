class_name CardKeywordGlossary
extends RefCounted
## Read-only explanations for authored card effects. No run, scene or RNG state.
## The fixed order is independent of Dictionary insertion order: the seven
## keyword rows first, then the authored special-rule rows in SPECIAL_ORDER.
## Help is explanatory only; it never says an unheld card can be played.

const KEYWORD_ORDER := ["bleed", "weak", "exposed", "pinned", "unravel", "guarding", "thorns"]
## Non-keyword rules are explained after the seven keywords, always in this
## order and only for the exact authored descriptor shape (never a guess).
const SPECIAL_ORDER := ["conditional_damage", "random_hit"]
## The Unravel thresholds the authored "current threshold" condition compares to.
const UNRAVEL_THRESHOLDS := "starts at 8 normal, 12 elite, 16 boss and rises by 4 after each break"


static func describe(definition: Variant) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	if not definition is Dictionary:
		return lines
	var effects_value: Variant = (definition as Dictionary).get("effects", {})
	if not effects_value is Dictionary:
		return lines
	var effects: Dictionary = effects_value
	for key: String in KEYWORD_ORDER:
		if not effects.has(key):
			continue
		var raw: Variant = effects[key]
		var keyword := ""
		var explanation := ""
		if key in ["bleed", "weak", "exposed", "unravel", "thorns"]:
			if not raw is int or int(raw) <= 0:
				continue
			keyword = "%s %d" % [key.capitalize(), int(raw)]
		elif (key == "pinned" or key == "guarding") and ((raw is bool and raw) or (raw is Dictionary and not raw.is_empty())):
			keyword = key.capitalize()
		else:
			continue
		match key:
			"bleed":
				explanation = "At the end of the affected owner's turn, lose %d HP, then Bleed decreases by 1. An enemy Bleed tick also adds 1 Unravel." % int(raw)
			"weak":
				explanation = "For %d turn(s), the afflicted actor deals 25%% less attack damage. Damage rounds down (minimum 0)." % int(raw)
			"exposed":
				explanation = "For %d turn(s), the affected actor takes 50%% more attack damage. Damage rounds down (minimum 0)." % int(raw)
			"pinned":
				explanation = "The next attack by a DIFFERENT hero adds +5 damage before Weak/Exposed and consumes this pin. The same hero cannot use it. Re-pinning replaces the pin; it expires at combat end."
			"unravel":
				explanation = "Add %d to an enemy's Unravel gauge. Thresholds: normal 8, elite 12, boss 16. At threshold it becomes Unravelled and skips its NEXT action; the gauge resets to 0 and its threshold rises by 4 for this combat." % int(raw)
			"guarding":
				explanation = "Warden's Draw Fire (1 energy, from position 1) redirects attacks aimed at other heroes to Warden until the next turn."
			"thorns":
				explanation = "Warden's Counter-stitch (1 energy, from positions 1-2) makes enemies that attack Warden take %d damage until the next turn." % int(raw)
		lines.append({"keyword": keyword, "explanation": explanation})
	for key: String in SPECIAL_ORDER:
		var special := _special_line(key, effects)
		if not special.is_empty():
			lines.append(special)
	return lines


static func _special_line(rule_key: String, effects: Dictionary) -> Dictionary:
	match rule_key:
		"conditional_damage":
			return _conditional_damage_line(effects)
		"random_hit":
			return _random_hit_line(effects)
	return {}


## Snip the Seam's authored conditional: a base damage, a higher empowered damage
## and a non-empty OR/AND list whose every predicate is one of the two recognized
## Unravel tests. Anything else (unknown or extra predicate, malformed or partial
## descriptor, no damage gain) yields no row instead of an invented rule.
static func _conditional_damage_line(effects: Dictionary) -> Dictionary:
	var base_value: Variant = effects.get("damage")
	var condition_value: Variant = effects.get("conditional_damage")
	if not base_value is int or int(base_value) <= 0 or not condition_value is Dictionary:
		return {}
	var condition: Dictionary = condition_value
	var empowered_value: Variant = condition.get("damage")
	var operator_value: Variant = condition.get("operator")
	var authored: Variant = condition.get("conditions")
	if not empowered_value is int or int(empowered_value) <= int(base_value):
		return {}
	if not operator_value is String or not String(operator_value) in ["or", "and"]:
		return {}
	if not authored is Array or (authored as Array).is_empty():
		return {}
	var clauses: Array[String] = []
	var compares_threshold := false
	for entry: Variant in (authored as Array):
		var clause := _condition_clause(entry)
		if clause.is_empty():
			return {}
		if entry is Dictionary and (entry as Dictionary).has("gauge"):
			compares_threshold = true
		clauses.append(clause)
	var joiner := " or " if String(operator_value) == "or" else " and "
	var explanation := "Deal %d damage, or %d instead if %s." % [
		int(base_value), int(empowered_value), joiner.join(clauses)]
	if compares_threshold:
		explanation += " The target's CURRENT Unravel threshold %s." % UNRAVEL_THRESHOLDS
	return {"keyword": "Conditional damage", "explanation": explanation}


## One recognized predicate, exactly as authored; every other shape is ignored.
static func _condition_clause(entry: Variant) -> String:
	if not entry is Dictionary:
		return ""
	var predicate: Dictionary = entry
	if predicate.has("status"):
		if predicate.size() == 1 and String(predicate["status"]) == "unravelled":
			return "the target is Unravelled"
		return ""
	if predicate.has("gauge"):
		if predicate.size() == 3 and String(predicate["gauge"]) == "unravel" \
				and String(predicate.get("comparison", "")) == "at_least_half" \
				and String(predicate.get("threshold", "")) == "current_target_threshold":
			return "its Unravel gauge is at least half its current threshold"
		return ""
	return ""


## Ricochet's authored random-hit descriptor: a positive per-hit damage, several
## hits, a new random living target for each hit and the single run RNG. A shape
## missing any part of that contract (or naming another RNG) gets no row.
static func _random_hit_line(effects: Dictionary) -> Dictionary:
	var damage_value: Variant = effects.get("damage")
	var hit_value: Variant = effects.get("hit_count")
	if not damage_value is int or int(damage_value) <= 0:
		return {}
	if not hit_value is int or int(hit_value) < 2:
		return {}
	if effects.get("random_target_each_hit") != true or effects.get("rng_source") != "run" \
			or effects.get("living_targets_only") != true:
		return {}
	var explanation := "%d separate hits of %d damage each. Every hit picks its own random living enemy using the run's single seeded RNG, so the same enemy can be hit more than once." % [
		int(hit_value), int(damage_value)]
	return {"keyword": "Random hits", "explanation": explanation}

class_name CardKeywordGlossary
extends RefCounted
## Read-only explanations for authored card effects. No run, scene or RNG state.
## The fixed order is independent of Dictionary insertion order: the seven
## keyword rows first, then the authored special-rule rows in SPECIAL_ORDER.
## Help is explanatory only; it never says an unheld card can be played.

const KEYWORD_ORDER := ["bleed", "weak", "exposed", "pinned", "unravel", "guarding", "thorns"]
## Non-keyword rules are explained after the seven keywords, always in this
## order and only for the exact authored descriptor shape (never a guess).
const SPECIAL_ORDER := ["conditional_damage", "random_hit", "energy_tradeoff", "bleed_doubling", "two_hits"]
## The Unravel thresholds the authored "current threshold" condition compares to.
const UNRAVEL_THRESHOLDS := "starts at 8 normal, 12 elite, 16 boss and rises by 4 after each break"
## The two energy-trading pool cards this Help knows, plus the exact authored
## numbers and the three hero slots their owner/structure check needs.
const OVERCLOCK_IDS := ["tinker_overclock", "tinker_overclock_plus"]
const TRANCE_IDS := ["seamstress_tailors_trance", "seamstress_tailors_trance_plus"]
const OVERCLOCK_COST := 0
const OVERCLOCK_GAIN := 1
const OVERCLOCK_SELF_DAMAGE := 3
const TRANCE_COST := 1
const TRANCE_GAIN := 1
const TRANCE_BASE_DRAW := 2
const TRANCE_PLUS_DRAW := 3
const PARTY_SIZE := 3
## Hemorrhage Hem's authored doubling rule: base and '+' carry the same
## descriptor, only the energy cost differs. The whole catalog shape is re-checked
## so no other card, owner, price, slot or target can borrow this explanation.
const BLEED_DOUBLING_BASE_ID := "seamstress_hemorrhage_hem"
const BLEED_DOUBLING_PLUS_ID := "seamstress_hemorrhage_hem_plus"
const BLEED_DOUBLING_OWNER := "seamstress"
const BLEED_DOUBLING_BASE_COST := 2
const BLEED_DOUBLING_PLUS_COST := 1
const BLEED_DOUBLING_MULTIPLIER := 2
## Pin and Pound's authored two sequential hits (D2-1). Only these two Warden
## identities, the exact cost/slots/target and the two-hit descriptor qualify;
## the shared catalog shape is re-checked so no other card can borrow the text.
const PIN_AND_POUND_BASE_ID := "warden_pin_and_pound"
const PIN_AND_POUND_PLUS_ID := "warden_pin_and_pound_plus"
const PIN_AND_POUND_OWNER := "warden"
const PIN_AND_POUND_COST := 2
const PIN_AND_POUND_BASE_DAMAGE := 9
const PIN_AND_POUND_PLUS_DAMAGE := 12
const PIN_AND_POUND_HITS := 2
## The six authored party-wide / cross-hero support cards (D2-1), base and '+'.
## Their Help row is appended after every keyword and special-rule row, and only
## an exact catalog shape (identity, owner, cost, source slots, target, empty
## target list and the written effect keys/amounts) may claim it.
const PARTY_SUPPORT_IDS := ["warden_hold_the_line", "warden_hold_the_line_plus",
	"warden_bastion_quilt", "warden_bastion_quilt_plus",
	"seamstress_field_mend", "seamstress_field_mend_plus"]
const HOLD_THE_LINE_BASE_ID := "warden_hold_the_line"
const HOLD_THE_LINE_PLUS_ID := "warden_hold_the_line_plus"
const HOLD_THE_LINE_COST := 1
const HOLD_THE_LINE_BASE_BLOCK := 5
const HOLD_THE_LINE_PLUS_BLOCK := 7
const HOLD_THE_LINE_BASE_ALLY_BLOCK := 2
const HOLD_THE_LINE_PLUS_ALLY_BLOCK := 3
const BASTION_QUILT_BASE_ID := "warden_bastion_quilt"
const BASTION_QUILT_PLUS_ID := "warden_bastion_quilt_plus"
const BASTION_QUILT_COST := 3
const BASTION_QUILT_BASE_BLOCK := 10
const BASTION_QUILT_PLUS_BLOCK := 13
const FIELD_MEND_BASE_ID := "seamstress_field_mend"
const FIELD_MEND_PLUS_ID := "seamstress_field_mend_plus"
const FIELD_MEND_COST := 2
const FIELD_MEND_BASE_HEAL := 4
const FIELD_MEND_PLUS_HEAL := 6


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
		var special := _special_line(key, definition, effects)
		if not special.is_empty():
			lines.append(special)
	var support := _party_support_line(definition, effects)
	if not support.is_empty():
		lines.append(support)
	return lines


static func _special_line(rule_key: String, definition: Dictionary, effects: Dictionary) -> Dictionary:
	match rule_key:
		"conditional_damage":
			return _conditional_damage_line(effects)
		"random_hit":
			return _random_hit_line(effects)
		"energy_tradeoff":
			return _energy_tradeoff_line(definition, effects)
		"bleed_doubling":
			return _bleed_doubling_line(definition, effects)
		"two_hits":
			return _two_hits_line(definition, effects)
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


## Overclock's and Tailor's Trance's authored energy trades. Only the exact
## catalog identity and descriptor shape qualify: the owner, cost, self target,
## empty target list, legal source slots and the written effect keys/amounts are
## all re-checked here, so a partial, mis-owned, mispriced or extended record
## never claims this Help. The amounts in the text are the checked ones.
static func _energy_tradeoff_line(definition: Dictionary, effects: Dictionary) -> Dictionary:
	var id_value: Variant = definition.get("id")
	if not id_value is String:
		return {}
	var card_id: String = id_value
	var is_overclock: bool = OVERCLOCK_IDS.has(card_id)
	if not is_overclock and not TRANCE_IDS.has(card_id):
		return {}
	var expected_owner := "tinker" if is_overclock else "seamstress"
	if String(definition.get("owner", "")) != expected_owner:
		return {}
	if definition.get("target_kind") != "self":
		return {}
	var to_value: Variant = definition.get("to_positions")
	if not to_value is Array or not (to_value as Array).is_empty():
		return {}
	var cost_value: Variant = definition.get("cost")
	if not cost_value is int:
		return {}
	var from_value: Variant = definition.get("from_positions")
	if not from_value is Array or (from_value as Array).is_empty():
		return {}
	for position: Variant in (from_value as Array):
		if not position is int or int(position) < 1 or int(position) > PARTY_SIZE:
			return {}
	if is_overclock:
		return _overclock_line(int(cost_value), effects)
	return _trance_line(card_id, int(cost_value), effects)


## Overclock trades HP for energy: it costs nothing, grants one energy and then
## damages its own Tinker through CombatParty.apply_damage, where Block absorbs
## first and any remainder lowers HP (which can leave her torn).
static func _overclock_line(cost: int, effects: Dictionary) -> Dictionary:
	if cost != OVERCLOCK_COST or effects.size() != 2:
		return {}
	var gained: Variant = effects.get("gain_energy")
	var loss: Variant = effects.get("self_hp_loss")
	if not gained is int or int(gained) != OVERCLOCK_GAIN:
		return {}
	if not loss is int or int(loss) != OVERCLOCK_SELF_DAMAGE:
		return {}
	var explanation := "Costs %d energy to play and gains %d energy, for a net gain of %d energy. Tinker then takes %d damage herself: Block absorbs that damage first, and any remainder lowers her HP, so this can leave her torn." % [
		cost, int(gained), int(gained) - cost, int(loss)]
	return {"keyword": "Energy tradeoff", "explanation": explanation}


## Tailor's Trance spends one energy and immediately regains it, so the play is
## net 0 energy but still requires that single energy up front; it then draws the
## exact authored number of cards (2 base, 3 upgraded). Nothing else qualifies.
static func _trance_line(card_id: String, cost: int, effects: Dictionary) -> Dictionary:
	if cost != TRANCE_COST or effects.size() != 2:
		return {}
	var gained: Variant = effects.get("energy")
	var drawn: Variant = effects.get("draw")
	if not gained is int or int(gained) != TRANCE_GAIN:
		return {}
	var is_plus: bool = card_id.ends_with("_plus")
	var required_draw: int = TRANCE_PLUS_DRAW if is_plus else TRANCE_BASE_DRAW
	if not drawn is int or int(drawn) != required_draw:
		return {}
	var explanation := "Costs %d energy, which must be available before the play, then regains that same %d energy, so the play itself is net 0 energy. Draws %d cards." % [
		cost, int(gained), int(drawn)]
	return {"keyword": "Energy tradeoff", "explanation": explanation}


## Hemorrhage Hem multiplies Bleed already on its single enemy target: N -> N + N
## through CombatSeamstressPoolBleed, so 0 stays 0. It is not a fresh "Bleed N"
## application (that is where the Seamstress's usual +1 would come from), and the
## doubled stacks then follow the ordinary turn-end tick and decrement. Only the
## exact authored base/'+' record, owner, cost, legal slots, single-enemy target
## and positive multiplier 2 qualify; anything else gets no row.
static func _bleed_doubling_line(definition: Dictionary, effects: Dictionary) -> Dictionary:
	var id_value: Variant = definition.get("id")
	if not id_value is String:
		return {}
	var card_id: String = id_value
	if card_id != BLEED_DOUBLING_BASE_ID and card_id != BLEED_DOUBLING_PLUS_ID:
		return {}
	if String(definition.get("owner", "")) != BLEED_DOUBLING_OWNER:
		return {}
	if definition.get("target_kind") != "enemy_single":
		return {}
	if not _exact_slots(definition.get("from_positions", null)) \
			or not _exact_slots(definition.get("to_positions", null)):
		return {}
	var cost_value: Variant = definition.get("cost")
	if not cost_value is int:
		return {}
	var required_cost: int = BLEED_DOUBLING_PLUS_COST if card_id == BLEED_DOUBLING_PLUS_ID else BLEED_DOUBLING_BASE_COST
	if int(cost_value) != required_cost:
		return {}
	if effects.size() != 1:
		return {}
	var multiplier_value: Variant = effects.get("bleed_multiplier")
	if not multiplier_value is int or int(multiplier_value) != BLEED_DOUBLING_MULTIPLIER:
		return {}
	var explanation := "Doubles the Bleed already on the target instead of adding new Bleed: Bleed N becomes 2N, and a target with no Bleed stays at 0. The doubled stacks then tick like any Bleed at the affected unit's turn end: that unit loses HP equal to its Bleed, then Bleed decreases by 1 (an enemy tick also adds 1 Unravel). This is not a fresh Bleed application, so the Seamstress's usual +1 Bleed does not apply."
	return {"keyword": "Bleed doubling", "explanation": explanation}


## Pin and Pound's authored multi-hit attack: two sequential hits on the one
## originally chosen enemy (D2-1), with hit 2 skipped if hit 1 kills it. The
## D2-2 Pinned note is exact: only a different hero's single +5 applies, only
## on hit 1 (consumed before hit 2 is computed), and the card itself never pins.
## Only the exact base/'+' identity, owner, cost, source slot, enemy target range
## and {damage, hits: 2} descriptor qualify; anything else gets no row.
static func _two_hits_line(definition: Dictionary, effects: Dictionary) -> Dictionary:
	var id_value: Variant = definition.get("id")
	if not id_value is String:
		return {}
	var card_id: String = id_value
	if card_id != PIN_AND_POUND_BASE_ID and card_id != PIN_AND_POUND_PLUS_ID:
		return {}
	if String(definition.get("owner", "")) != PIN_AND_POUND_OWNER:
		return {}
	if definition.get("target_kind") != "enemy_single":
		return {}
	if not _exact_positions(definition.get("from_positions", null), [1]):
		return {}
	if not _exact_positions(definition.get("to_positions", null), [1, 2, 3]):
		return {}
	var cost_value: Variant = definition.get("cost")
	if not cost_value is int or int(cost_value) != PIN_AND_POUND_COST:
		return {}
	if effects.size() != 2:
		return {}
	var required_damage: int = PIN_AND_POUND_PLUS_DAMAGE if card_id == PIN_AND_POUND_PLUS_ID \
		else PIN_AND_POUND_BASE_DAMAGE
	var damage_value: Variant = effects.get("damage")
	var hit_value: Variant = effects.get("hits")
	if not damage_value is int or int(damage_value) != required_damage:
		return {}
	if not hit_value is int or int(hit_value) != PIN_AND_POUND_HITS:
		return {}
	var explanation := "Costs %d energy to play. Deals two hits of %d damage each, one after the other, to the same originally chosen enemy; if the first hit kills it, the second hit is skipped instead of moving to another enemy. A Pinned token placed by a DIFFERENT hero adds +5 damage to the first hit only, before Weak/Exposed, and is consumed then, so the second hit never gains it; a pin from the same hero does not apply. Pin and Pound itself creates no Pinned token." % [
		int(cost_value), int(damage_value)]
	return {"keyword": "Two hits", "explanation": explanation}


## The three D2-1 party-support families, dispatched only by exact identity.
## Each family re-checks its whole authored catalog shape and repeats only the
## Block/heal amounts it actually read from the caller's authenticated record.
static func _party_support_line(definition: Dictionary, effects: Dictionary) -> Dictionary:
	var id_value: Variant = definition.get("id")
	if not id_value is String:
		return {}
	var card_id: String = id_value
	if not PARTY_SUPPORT_IDS.has(card_id):
		return {}
	if card_id == HOLD_THE_LINE_BASE_ID or card_id == HOLD_THE_LINE_PLUS_ID:
		return _hold_the_line_line(card_id, definition, effects)
	if card_id == BASTION_QUILT_BASE_ID or card_id == BASTION_QUILT_PLUS_ID:
		return _bastion_quilt_line(card_id, definition, effects)
	return _field_mend_line(card_id, definition, effects)


## Hold the Line gives the Warden the first authored amount and every OTHER
## living hero the second; a downed hero gets nothing. The resolver follows the
## Warden's current hero identity, not a fixed seat, so the Help names no slot.
static func _hold_the_line_line(card_id: String, definition: Dictionary,
		effects: Dictionary) -> Dictionary:
	if String(definition.get("owner", "")) != "warden":
		return {}
	if definition.get("target_kind") != "self":
		return {}
	if not _exact_positions(definition.get("from_positions", null), [1, 2]):
		return {}
	if not _empty_positions(definition.get("to_positions", null)):
		return {}
	var cost_value: Variant = definition.get("cost")
	if not cost_value is int or int(cost_value) != HOLD_THE_LINE_COST:
		return {}
	if effects.size() != 2:
		return {}
	var block_value: Variant = effects.get("block")
	var ally_value: Variant = effects.get("other_ally_block")
	if not block_value is int or not ally_value is int:
		return {}
	var upgraded: bool = card_id == HOLD_THE_LINE_PLUS_ID
	var required_block: int = HOLD_THE_LINE_PLUS_BLOCK if upgraded \
		else HOLD_THE_LINE_BASE_BLOCK
	var required_ally: int = HOLD_THE_LINE_PLUS_ALLY_BLOCK if upgraded \
		else HOLD_THE_LINE_BASE_ALLY_BLOCK
	if int(block_value) != required_block or int(ally_value) != required_ally:
		return {}
	var explanation := "Warden gains %d Block, and every OTHER living hero gains %d Block. Costs %d energy and is playable by the Warden from positions 1-2. A downed hero gains nothing, and the Warden's share follows her current position rather than a fixed slot." % [
		int(block_value), int(ally_value), int(cost_value)]
	return {"keyword": "Party support", "explanation": explanation}


## Bastion Quilt gives the one authored amount to EVERY living hero, wherever
## each hero currently stands; a downed hero is skipped.
static func _bastion_quilt_line(card_id: String, definition: Dictionary,
		effects: Dictionary) -> Dictionary:
	if String(definition.get("owner", "")) != "warden":
		return {}
	if definition.get("target_kind") != "party_all":
		return {}
	if not _exact_slots(definition.get("from_positions", null)):
		return {}
	if not _empty_positions(definition.get("to_positions", null)):
		return {}
	var cost_value: Variant = definition.get("cost")
	if not cost_value is int or int(cost_value) != BASTION_QUILT_COST:
		return {}
	if effects.size() != 1:
		return {}
	var block_value: Variant = effects.get("block_all")
	if not block_value is int:
		return {}
	var required_block: int = BASTION_QUILT_PLUS_BLOCK \
		if card_id == BASTION_QUILT_PLUS_ID else BASTION_QUILT_BASE_BLOCK
	if int(block_value) != required_block:
		return {}
	var explanation := "Every living hero gains %d Block, even after the party changes positions. Costs %d energy and is playable by the Warden from any of the three positions. A downed hero gains nothing." % [
		int(block_value), int(cost_value)]
	return {"keyword": "Party support", "explanation": explanation}


## Field Mend heals each living hero the one authored amount, capped at that
## hero's current maximum HP; a downed hero is skipped and never revived.
static func _field_mend_line(card_id: String, definition: Dictionary,
		effects: Dictionary) -> Dictionary:
	if String(definition.get("owner", "")) != "seamstress":
		return {}
	if definition.get("target_kind") != "party_all":
		return {}
	if not _exact_positions(definition.get("from_positions", null), [2, 3]):
		return {}
	if not _empty_positions(definition.get("to_positions", null)):
		return {}
	var cost_value: Variant = definition.get("cost")
	if not cost_value is int or int(cost_value) != FIELD_MEND_COST:
		return {}
	if effects.size() != 1:
		return {}
	var heal_value: Variant = effects.get("heal")
	if not heal_value is int:
		return {}
	var required_heal: int = FIELD_MEND_PLUS_HEAL \
		if card_id == FIELD_MEND_PLUS_ID else FIELD_MEND_BASE_HEAL
	if int(heal_value) != required_heal:
		return {}
	var explanation := "Each living hero recovers %d HP, capped at that hero's current maximum HP. Costs %d energy and is playable by the Seamstress from positions 2-3. A downed hero is skipped and is not revived by this card." % [
		int(heal_value), int(cost_value)]
	return {"keyword": "Party support", "explanation": explanation}


## An authored empty target list, exactly as expected and nothing else.
static func _empty_positions(value: Variant) -> bool:
	return value is Array and (value as Array).is_empty()


## The authored positions, exactly as expected in order and nothing else.
static func _exact_positions(value: Variant, expected: Array) -> bool:
	if not value is Array:
		return false
	var positions: Array = value
	if positions.size() != expected.size():
		return false
	for index in range(expected.size()):
		var slot: Variant = positions[index]
		if not slot is int or int(slot) != int(expected[index]):
			return false
	return true


## The authored party slots, exactly 1..3 in order and nothing else.
static func _exact_slots(value: Variant) -> bool:
	if not value is Array:
		return false
	var slots: Array = value
	if slots.size() != PARTY_SIZE:
		return false
	for index in range(PARTY_SIZE):
		var slot: Variant = slots[index]
		if not slot is int or int(slot) != index + 1:
			return false
	return true

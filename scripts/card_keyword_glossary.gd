class_name CardKeywordGlossary
extends RefCounted
## Read-only explanations for authored card effects. No run, scene or RNG state.
## The fixed order is independent of Dictionary insertion order: the keyword
## rows first (the legacy seven, then Riposte, Tangled, Blind and Fear), then the
## authored special-rule rows in SPECIAL_ORDER.
## Help is explanatory only; it never says an unheld card can be played.

const KEYWORD_ORDER := ["bleed", "weak", "exposed", "pinned", "unravel", "guarding",
	"thorns", "riposte", "tangled", "blind", "fear"]
## Non-keyword rules are explained after the keyword rows, always in this
## order and only for the exact authored descriptor shape (never a guess).
const SPECIAL_ORDER := ["conditional_damage", "random_hit", "energy_tradeoff", "bleed_doubling", "two_hits", "dodge", "exhaust"]
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
## Darning's authored mixed rescue (D2-1): heal and Block on one chosen ally.
## Both base and '+' share the same 1 energy cost, positions 1-3, and single-ally
## target. The whole catalog shape is re-checked so no forged, mis-owned,
## mispriced, mistargeted or extended record can claim this explanation.
const DARNING_IDS := ["seamstress_darning", "seamstress_darning_plus"]
const DARNING_BASE_ID := "seamstress_darning"
const DARNING_PLUS_ID := "seamstress_darning_plus"
const DARNING_OWNER := "seamstress"
const DARNING_COST := 1
const DARNING_BASE_HEAL := 4
const DARNING_BASE_BLOCK := 3
const DARNING_PLUS_HEAL := 6
const DARNING_PLUS_BLOCK := 4
## The six authored one-shot Dodge variants: four Rag Duelist cape cards
## (self target) and two Lantern Monk Moth Shroud cards (chosen ally, with Block).
## Only these exact IDs with the integer one descriptor and correct owner/target
## receive the Dodge Help row.
const DODGE_SELF_IDS := ["rag_duelist_cape_slip", "rag_duelist_cape_slip_plus",
	"rag_duelist_cape_flourish", "rag_duelist_cape_flourish_plus"]
const DODGE_ALLY_IDS := ["lantern_monk_moth_shroud", "lantern_monk_moth_shroud_plus"]
const DODGE_IDS := DODGE_SELF_IDS + DODGE_ALLY_IDS
## The two Moth Cloud variants that carry both Blind and Exhaust.
const EXHAUST_IDS := ["lantern_monk_moth_cloud", "lantern_monk_moth_cloud_plus"]
## Fear is the Scarecrow's authored one-turn buff lock, printed as one compact
## Help row. Only the eight authentic catalog printings that CardShortRules
## authenticates receive it, so no same-shaped forged or mis-owned record can
## borrow the rule. The Scarecrow is a selectable live party hero (any three of
## the eight heroes form a run). The row states the authored design and the live
## held-card split: the four single-target sack printings already play from the
## shared hand, while the two area-card families are not applied by that path.
const FEAR_EXPLANATION := "Fear is the authored Scarecrow keyword: the affected enemy cannot buff on its NEXT enemy turn, and the buff lock then expires at the end of that turn, so it never covers a second turn. Upgrades never lengthen the lock. Fear is applied together with a separate Weak, which reduces the enemy's outgoing attack damage by 25% (rounded down) for its authored Weak turns: Sack Glare, Sack Grin and Crow Flock author Weak 1 on the base card and Weak 2 on the upgraded card, while Harvest Fright authors Weak 2 on the base card and Weak 3 on the upgraded card. Fear adds no damage, Bleed or Blind of its own. The Scarecrow is one of the eight selectable heroes and can join any three-hero party. The four live sack variants, Sack Glare and Sack Grin with their '+' upgrades, already play from the shared hand and apply this Fear lock to the chosen living enemy. Crow Flock and Harvest Fright are the two authored area-card families: they carry the same Fear flag, but the live sack-card path does not play them, so their Fear is not yet applied in battle."
## Pierce Block is the Scarecrow's shoulder crow strike (Crow Dive and Crow Peck,
## base and '+'). It pierces Block straight to HP against the backmost living enemy.
## Only the four authentic catalog printings that CardShortRules authenticates
## receive this Help row.
const BLOCK_PIERCE_KEYWORD := "Pierce Block"
const BLOCK_PIERCE_EXPLANATION := "Pierce Block strikes the backmost living enemy (the highest-position living enemy): damage reduces that enemy's HP directly without reducing or consuming its Block, leaving enemy Block intact. Weak, Exposed and Tangled still adjust damage normally. This Help explains the authored card rule only; live combat does not yet play this card from the shared hand."
## Tether is the Seamstress's authored two-foe link and 50% confirmed-hit HP-loss echo.
## Only the four authentic catalog printings that CardShortRules authenticates
## receive this Help row, so no same-shaped forged or mis-owned record can
## borrow the rule.
const TETHER_KEYWORD := "Tether"
const TETHER_EXPLANATION := "Tether links two distinct living enemies and deals zero immediate damage on play. When a later confirmed hit against either linked enemy causes positive HP loss, half of that HP loss (50%, rounded down) is echoed as raw damage to the other linked living enemy, with that recipient's Block absorbing before HP. If the primary hit is wholly absorbed by Block, there is no echo. The echo is not a separate card attack and cannot trigger another echo, status, Thorns or Riposte. This Help explains the authored rules helper; it does not specify link lifetime or claim live hand wiring for Tether Stitch."


static func describe(definition: Variant) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	if not definition is Dictionary:
		return lines
	var effects_value: Variant = (definition as Dictionary).get("effects", {})
	if not effects_value is Dictionary:
		return lines
	var effects: Dictionary = effects_value
	for key: String in KEYWORD_ORDER:
		if key == "fear":
			# Fear is authored under its own flag key, so its presence is the
			# strict authenticated Scarecrow check rather than one plain lookup.
			if not _authored_fear(definition):
				continue
		elif key == "blind":
			# Blind is authored under two different keys, so its presence is the
			# strict two-spelling check rather than one plain key lookup.
			if not _authored_blind(definition, effects):
				continue
		elif not effects.has(key):
			continue
		var raw: Variant = effects.get(key)
		var keyword := ""
		var explanation := ""
		if key in ["bleed", "weak", "exposed", "unravel", "thorns"]:
			if not raw is int or int(raw) <= 0:
				continue
			keyword = "%s %d" % [key.capitalize(), int(raw)]
		elif key == "fear":
			# Fear is a bare keyword with no authored count; it never prints the
			# buff-lock duration or the separate Weak stacks as a second number.
			keyword = "Fear"
		elif key == "riposte":
			# Riposte is only explained with a positive amount and the authored
			# one-turn duration; any other shape gets no row.
			if not raw is int or int(raw) <= 0 or not _one_turn(effects):
				continue
			keyword = "Riposte %d" % int(raw)
		elif key == "tangled":
			if not raw is int or int(raw) <= 0:
				continue
			keyword = "Tangled %d" % int(raw)
		elif key == "blind":
			# Blind is the Lantern Monk's one-shot keyword, already accepted by
			# the strict presence check above; it prints no amount.
			keyword = "Blind"
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
				explanation = "An attacker that confirms a positive-damage hit against the bearer takes %d damage in return. Thorns retaliates once per confirmed positive-damage hit, including a blow fully absorbed by Block. The retaliation goes through the attacker's own Block before HP, so Block absorbs it before any HP loss. Misses, previews and rejected plays do not trigger Thorns." % int(raw)
				var duration_value: Variant = effects.get("duration")
				if duration_value is String and duration_value == "until_next_turn":
					explanation += " It lasts until the next turn."
			"riposte":
				explanation = "When the Rag Duelist is hit, she strikes back for %d damage. This is counterdamage, not a number of turns: Riposte lasts one turn and expires fully at that turn's end. The combat status rules apply this counter on each confirmed hit; this Help states the printed design, and not every live confirmed-hit route reaches the retaliation." % int(raw)
			"tangled":
				explanation = "For %d turns, the Tangled unit cannot move or be moved by its own side, and attacks against it deal +2 damage, applied once per positive-base status-aware attack after Weak and Exposed rounding down, regardless of the Tangled count. Tangled decrements at owner-turn end. The combat status rules apply this effect; not every live own-side movement route is wired." % int(raw)
			"blind":
				explanation = "Blind is one-shot, never a stack and never a number of turns: the affected enemy's NEXT attempted attack misses in full, including every hit of a multi-hit sequence, and the Blind is spent once on that attempt. An enemy buff or debuff is not an attack, so an enemy turn that ends without attacking keeps the unspent Blind until a real attack is attempted. Live combat already resolves this: the enemy phase spends the Blind before any hit of that attack lands."
			"fear":
				explanation = FEAR_EXPLANATION
		lines.append({"keyword": keyword, "explanation": explanation})
	var tether := _tether_line(definition, effects)
	if not tether.is_empty():
		lines.append(tether)
	for key: String in SPECIAL_ORDER:
		var special := _special_line(key, definition, effects)
		if not special.is_empty():
			lines.append(special)
	var support := _party_support_line(definition, effects)
	if not support.is_empty():
		lines.append(support)
	var darning := _darning_line(definition, effects)
	if not darning.is_empty():
		lines.append(darning)
	var crow := _crow_line(definition, effects)
	if not crow.is_empty():
		lines.append(crow)
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
		"dodge":
			return _dodge_line(definition, effects)
		"exhaust":
			return _exhaust_line(definition, effects)
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


## The six authored one-shot Dodge variants. Only a complete authored catalog
## shape earns the row: the named ID, a real String owner and recipient, the
## per-ID cost, the authored source and target slots and the whole effect
## descriptor. A partial, altered or extended record gets no row rather than
## borrowing the explanation.
static func _dodge_line(definition: Dictionary, effects: Dictionary) -> Dictionary:
	var id_value: Variant = definition.get("id")
	if not id_value is String:
		return {}
	var card_id: String = id_value
	if not DODGE_IDS.has(card_id):
		return {}
	var owner_value: Variant = definition.get("owner")
	var target_value: Variant = definition.get("target_kind")
	var cost_value: Variant = definition.get("cost")
	if typeof(cost_value) != TYPE_INT:
		return {}
	var cost: int = int(cost_value)
	var is_plus: bool = card_id.ends_with("_plus")
	if DODGE_SELF_IDS.has(card_id):
		if not owner_value is String or String(owner_value) != "rag_duelist":
			return {}
		if not target_value is String or String(target_value) != "self":
			return {}
		if cost != (0 if is_plus else 1):
			return {}
		if not _exact_positions(definition.get("from_positions", null), [1, 2, 3]):
			return {}
		if not _empty_positions(definition.get("to_positions", null)):
			return {}
		# Rag cape cards author exactly {dodge_next_attack: 1, duration: 1}.
		if effects.size() != 2 or not effects.has("dodge_next_attack") \
				or not effects.has("duration"):
			return {}
		if typeof(effects["dodge_next_attack"]) != TYPE_INT \
				or int(effects["dodge_next_attack"]) != 1:
			return {}
		if typeof(effects["duration"]) != TYPE_INT or int(effects["duration"]) != 1:
			return {}
	else:
		if not owner_value is String or String(owner_value) != "lantern_monk":
			return {}
		if not target_value is String or String(target_value) != "ally_single":
			return {}
		if cost != 1:
			return {}
		if not _exact_positions(definition.get("from_positions", null), [2, 3]):
			return {}
		if not _empty_positions(definition.get("to_positions", null)):
			return {}
		# Moth Shroud authors exactly {block: 6 (8 upgraded), dodge_next_attack: 1}.
		if effects.size() != 2 or not effects.has("block") \
				or not effects.has("dodge_next_attack"):
			return {}
		if typeof(effects["block"]) != TYPE_INT \
				or int(effects["block"]) != (8 if is_plus else 6):
			return {}
		if typeof(effects["dodge_next_attack"]) != TYPE_INT \
				or int(effects["dodge_next_attack"]) != 1:
			return {}
	var explanation := "Dodge is one-shot, never a stack and never a number of turns: the next incoming attack HIT against the living hero who actually receives it misses once, and that hero's Dodge is spent on it. It goes to the caster for the Rag Duelist's cape cards, or to a chosen ally (with the authored Block) for Moth Shroud. Warden Guard redirection decides who really receives the attack, so the receiving hero's Dodge is the one spent, while a skipped or downed target keeps its own. A multi-hit attack is several separate hit attempts, so one Dodge avoids one of those hits, not all of them. An unused Dodge expires at that hero's owner-turn end. Live combat already applies this: the attack rules spend the token for the real recipient before any damage lands."
	return {"keyword": "Dodge", "explanation": explanation}


## The two Moth Cloud variants that carry both Blind and Exhaust.
## Only these exact IDs, with the true boolean for both descriptors and the exact
## authored cost, source slots and target slots, receive the Exhaust Help row;
## missing Blind, any extra/altered effect, conflicting Blind flags, wrong cost
## or wrong positions all stay silent.
static func _exhaust_line(definition: Dictionary, effects: Dictionary) -> Dictionary:
	var id_value: Variant = definition.get("id")
	if not id_value is String:
		return {}
	var card_id: String = id_value
	if not EXHAUST_IDS.has(card_id):
		return {}
	var owner_value: Variant = definition.get("owner")
	if not owner_value is String or String(owner_value) != "lantern_monk":
		return {}
	var target_value: Variant = definition.get("target_kind")
	if not target_value is String or String(target_value) != "enemy_all":
		return {}
	# Moth Cloud base costs 2, plus costs 1.
	var cost_value: Variant = definition.get("cost")
	if typeof(cost_value) != TYPE_INT:
		return {}
	var expected_cost := 1 if card_id.ends_with("_plus") else 2
	if int(cost_value) != expected_cost:
		return {}
	if not _exact_positions(definition.get("from_positions", null), [2, 3]):
		return {}
	if not _exact_positions(definition.get("to_positions", null), [1, 2, 3]):
		return {}
	# Effects must be exactly {blind_next_attack:true, exhaust:true}, nothing more,
	# nothing less, nothing in a conflicting or altered spelling.
	if effects.size() != 2 or not effects.has("blind_next_attack") \
			or not effects.has("exhaust"):
		return {}
	if typeof(effects["exhaust"]) != TYPE_BOOL or not bool(effects["exhaust"]):
		return {}
	if typeof(effects["blind_next_attack"]) != TYPE_BOOL \
			or not bool(effects["blind_next_attack"]):
		return {}
	var explanation := "Exhaust is an intended one-play removal from the remaining combat draw/discard cycle: the card is removed once, not normally discarded and redrawn. This Help explains the authored design description only; it is currently design-only and live combat does not yet apply Exhaust."
	return {"keyword": "Exhaust", "explanation": explanation}


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


## Darning heals a chosen living ally and grants it Block. Only the exact
## canonical base/'+' catalog record, owner, cost, source slots 1-3, single-ally
## target, empty to_positions, and exact {heal, block} amounts qualify. Anything
## else (wrong ID, cost, owner, slot, target, extra/missing effect) gets no row.
static func _darning_line(definition: Dictionary, effects: Dictionary) -> Dictionary:
	var id_value: Variant = definition.get("id")
	if not id_value is String:
		return {}
	var card_id: String = id_value
	if not DARNING_IDS.has(card_id):
		return {}
	if String(definition.get("owner", "")) != DARNING_OWNER:
		return {}
	if definition.get("target_kind") != "ally_single":
		return {}
	if not _exact_slots(definition.get("from_positions", null)):
		return {}
	if not _empty_positions(definition.get("to_positions", null)):
		return {}
	var cost_value: Variant = definition.get("cost")
	if not cost_value is int or int(cost_value) != DARNING_COST:
		return {}
	if effects.size() != 2:
		return {}
	var heal_value: Variant = effects.get("heal")
	var block_value: Variant = effects.get("block")
	if not heal_value is int or not block_value is int:
		return {}
	var upgraded: bool = card_id == DARNING_PLUS_ID
	var required_heal: int = DARNING_PLUS_HEAL if upgraded else DARNING_BASE_HEAL
	var required_block: int = DARNING_PLUS_BLOCK if upgraded else DARNING_BASE_BLOCK
	if int(heal_value) != required_heal or int(block_value) != required_block:
		return {}
	var explanation := "Heals a chosen living ally %d HP and grants that ally %d Block. Costs %d energy and is playable by the Seamstress from positions 1-3. Healing is capped by the chosen living ally's missing HP, while the Block portion still applies even if the ally is already at full HP. A downed hero cannot be chosen and is not revived." % [
		int(heal_value), int(block_value), int(cost_value)]
	return {"keyword": "Mixed rescue", "explanation": explanation}


## Pierce Block is the Scarecrow's shoulder crow strike. Its single authority is
## CardShortRules' strict printing check, which validates the complete canonical
## Scarecrow starter/pool record (ID, display_name, owner, cost, slots, target,
## damage, ignore_block, illustration_path, starting_copies, reward_eligible,
## rarity, upgrade link, and no unexpected fields). Delegating keeps the sewn face
## and Help from disagreeing, and any mismatch, altered property or forged record
## never earns the row.
static func _crow_line(definition: Dictionary, _effects: Dictionary) -> Dictionary:
	if not CardShortRules.is_authored_block_pierce(definition):
		return {}
	return {"keyword": BLOCK_PIERCE_KEYWORD, "explanation": BLOCK_PIERCE_EXPLANATION}


## Tether is the Seamstress's authored two-foe link and confirmed-hit echo.
## Its single authority is CardShortRules' strict printing check, which validates
## the complete canonical Seamstress starter/pool record against CombatSeamstressTetherRules.
static func _tether_line(definition: Dictionary, _effects: Dictionary) -> Dictionary:
	if not _authored_tether(definition):
		return {}
	return {"keyword": TETHER_KEYWORD, "explanation": TETHER_EXPLANATION}


static func _authored_tether(definition: Dictionary) -> bool:
	return CardShortRules.is_authored_tether(definition)


## Fear is the Scarecrow's authored one-turn buff lock. Its single authority is
## CardShortRules' strict printing check, which re-reads the exact ID, owner,
## recipient, cost, slots, Weak amount and the whole effect descriptor. Delegating
## keeps the sewn face and Help from disagreeing, and a Boolean false, a numeric
## one, a null, a rebuilt same-shaped card or a self/ally recipient never earns
## the row.
static func _authored_fear(definition: Dictionary) -> bool:
	return CardShortRules.is_authored_fear(definition)


## Blind is the Lantern Monk's look-driven one-shot status, authored in exactly
## two shapes: the starter catalogs' integer `blind: 1` and the reward pool's
## boolean `blind_next_attack: true`. Both mean "the target's next attack misses,
## then the Blind is spent", so two spellings on one record are ambiguous and a
## non-one count is never normalized into stacks. It is an enemy-only keyword:
## a party, ally, self or unreadable recipient never borrows the row.
static func _authored_blind(definition: Dictionary, effects: Dictionary) -> bool:
	var has_count: bool = effects.has("blind")
	var has_flag: bool = effects.has("blind_next_attack")
	if has_count == has_flag:
		return false
	if has_count:
		var count_value: Variant = effects["blind"]
		# `true` and `1.0` are not the authored integer one.
		if not count_value is int or int(count_value) != 1:
			return false
	else:
		var flag_value: Variant = effects["blind_next_attack"]
		if not flag_value is bool or not bool(flag_value):
			return false
	match str(definition.get("target_kind", "")):
		"enemy_single", "enemy_all", "enemy_random":
			return true
	return false


## An authored empty target list, exactly as expected and nothing else.
static func _empty_positions(value: Variant) -> bool:
	return value is Array and (value as Array).is_empty()


## The authored one-turn duration a Riposte is written for. Any other value (or
## an absent one) is a shape this Help cannot explain, so no Riposte row appears.
static func _one_turn(effects: Dictionary) -> bool:
	var value: Variant = effects.get("duration")
	return value is int and int(value) == 1


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

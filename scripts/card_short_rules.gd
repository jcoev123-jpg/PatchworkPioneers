class_name CardShortRules
extends RefCounted
## Deterministic, read-only formatter for the terse effect sentence printed on a
## hand or reward card face. Every sentence comes from one already-validated
## authored card record: this class plays no card, resolves no damage or status
## order, rolls no RNG and never predicts what a cast would actually do.
##
## `applied` optionally carries amounts the caller has already read from the same
## validated record (for example an authored Path/passive bonus printed by the
## owning catalog). It is never computed here.
##
## The face prints short combat sentences only: legal slots never appear as
## prose, because the drawn pips and the hover legend carry them.

## Every effect key this formatter can print. An authored key outside this list
## is reported honestly as an undescribed effect instead of being guessed at.
const KNOWN_EFFECT_KEYS := [
	"damage", "hits", "hit_count", "block", "other_ally_block", "block_all",
	"heal", "exposed", "weak", "bleed", "unravel", "bleed_multiplier", "pinned",
	"guarding", "thorns", "riposte", "tangled", "draw", "energy", "gain_energy",
	"self_hp_loss", "conditional_damage", "random_target_each_hit", "rng_source",
	"living_targets_only", "duration", "next_attack_damage_bonus",
	"next_turn_energy", "expires", "blind", "blind_next_attack",
	"dodge_next_attack", "exhaust", "cannot_buff_next_turn", "ignore_block",
	"tether_share_percent", "guard_next_hit", "damage_equal_to_owner_block",
	"bonus_damage", "taunt_next_enemy_turn", "combat_scrap_gain",
	"damage_per_combat_scrap", "consume_all_combat_scrap",
	"combat_scrap_spend_max", "bonus_damage_per_combat_scrap",
]
## The two V3 one-shot descriptors the face names beside the classic effects.
## They are printed design wording only: this formatter assumes no enemy attack
## will actually miss and no played card enters an exhaust pile.
const SELF_DODGE_CLAUSE := "dodge the next attack"
const ALLY_DODGE_CLAUSE := "dodges the next attack"
const EXHAUST_SENTENCE := "Exhaust."
## Sentences are separated by one space, so the face reads as ordinary prose.
const SEPARATOR := " "
## Terse markers the hover legend still explains for the painted pips.
const ALL_TARGET := "ALL"
const RANDOM_TARGET := "RND"
const SWAP_SENTENCE := "Swap with adjacent ally."
const UNKNOWN_SENTENCE := "Other authored effects are not described."
## Statuses keep one fixed printed order whatever the authoring order is.
const STATUS_ORDER := ["exposed", "weak", "bleed"]
## Fear is the Scarecrow's authored flag `cannot_buff_next_turn: true`. The face
## names the keyword only; the one-turn buff lock (and the independence of Weak)
## belongs to the sewn Help glossary. The whole catalog record is re-checked
## below, so a rebuilt or forged look-alike card cannot borrow the sentence.
const FEAR_KEY := "cannot_buff_next_turn"
const FEAR_OWNER := "scarecrow"
const FEAR_CLAUSE := "fear"
## The eight authentic Scarecrow Fear printings and their complete authored
## shape. `damage` 0 means the record authors no damage clause at all.
const FEAR_PRINTINGS := {
	"scarecrow_sack_glare": {"cost": 1, "target_kind": "enemy_single",
		"from_positions": [1, 2, 3], "to_positions": [1, 2, 3],
		"weak": 1, "damage": 0},
	"scarecrow_sack_glare_plus": {"cost": 1, "target_kind": "enemy_single",
		"from_positions": [1, 2, 3], "to_positions": [1, 2, 3],
		"weak": 2, "damage": 0},
	"scarecrow_sack_grin": {"cost": 1, "target_kind": "enemy_single",
		"from_positions": [1, 2, 3], "to_positions": [1, 2, 3],
		"weak": 1, "damage": 0},
	"scarecrow_sack_grin_plus": {"cost": 1, "target_kind": "enemy_single",
		"from_positions": [1, 2, 3], "to_positions": [1, 2, 3],
		"weak": 2, "damage": 0},
	"scarecrow_crow_flock": {"cost": 2, "target_kind": "enemy_all",
		"from_positions": [2, 3], "to_positions": [1, 2, 3],
		"weak": 1, "damage": 0},
	"scarecrow_crow_flock_plus": {"cost": 2, "target_kind": "enemy_all",
		"from_positions": [2, 3], "to_positions": [1, 2, 3],
		"weak": 2, "damage": 0},
	"scarecrow_harvest_fright": {"cost": 3, "target_kind": "enemy_all",
		"from_positions": [1, 2, 3], "to_positions": [1, 2, 3],
		"weak": 2, "damage": 4},
	"scarecrow_harvest_fright_plus": {"cost": 3, "target_kind": "enemy_all",
		"from_positions": [1, 2, 3], "to_positions": [1, 2, 3],
		"weak": 3, "damage": 6},
}
## Block piercing is the Scarecrow's shoulder crow strike (`ignore_block: true`).
## The face prints 'Pierce Block.' following the authentic damage aimed at the
## backmost living enemy. The whole catalog record is re-checked below, so a rebuilt
## or forged look-alike card cannot borrow the sentence.
const CROW_KEY := "ignore_block"
const CROW_OWNER := "scarecrow"
const CROW_TARGET_KIND := "enemy_back"
const CROW_CLAUSE := "pierce Block"
## The four authentic Scarecrow shoulder-crow printings and their complete authored
## shape.
const CROW_PRINTINGS := {
	"scarecrow_crow_dive": {
		"cost": 1, "damage": 3,
		"from_positions": [1, 2, 3], "to_positions": [1, 2, 3],
		"upgrade_id": "scarecrow_crow_dive_plus",
	},
	"scarecrow_crow_dive_plus": {
		"cost": 1, "damage": 5,
		"from_positions": [1, 2, 3], "to_positions": [1, 2, 3],
		"upgrade_of": "scarecrow_crow_dive",
	},
	"scarecrow_crow_peck": {
		"cost": 1, "damage": 4,
		"from_positions": [1, 2, 3], "to_positions": [1, 2, 3],
		"upgrade_id": "scarecrow_crow_peck_plus",
	},
	"scarecrow_crow_peck_plus": {
		"cost": 1, "damage": 6,
		"from_positions": [1, 2, 3], "to_positions": [1, 2, 3],
		"upgrade_of": "scarecrow_crow_peck",
	},

}
## Tether is the Seamstress's authored two-foe red-thread link (`tether_share_percent: 50`).
## The face prints 'Link 2 living enemies. Echo 50% of a later confirmed hit's HP loss.'
## The full mechanics (two distinct living enemies, zero immediate damage, floor-half
## primary HP loss, secondary Block order, non-recursive echo, and pure helper scope)
## belong to CardKeywordGlossary's Help row. The whole catalog record is authenticated
## via CombatSeamstressTetherRules, so rebuilt or forged look-alikes cannot borrow the line.
const TETHER_KEY := "tether_share_percent"
const TETHER_OWNER := "seamstress"
const TETHER_SENTENCE := "Link 2 living enemies. Echo 50% of a later confirmed hit's HP loss."

## The authentic V3 Warden Guard, Taunt and Shield Toss printings.
const V3_WARDEN_GUARD_IDS: Array[String] = [
	"warden_v3_shield_catch",
	"warden_v3_shield_catch_plus",
	"warden_v3_guard_stitch",
	"warden_v3_guard_stitch_plus",
	"warden_v3_final_bastion",
	"warden_v3_final_bastion_plus",
]

const V3_WARDEN_TAUNT_IDS: Array[String] = [
	"warden_v3_iron_challenge",
	"warden_v3_iron_challenge_plus",
	"warden_v3_iron_taunt",
	"warden_v3_iron_taunt_plus",
	"warden_v3_shieldwall_chorus",
	"warden_v3_shieldwall_chorus_plus",
	"warden_v3_final_bastion",
	"warden_v3_final_bastion_plus",
]

const V3_WARDEN_SHIELD_TOSS_IDS: Array[String] = [
	"warden_v3_rim_toss",
	"warden_v3_rim_toss_plus",
	"warden_v3_shield_toss",
	"warden_v3_shield_toss_plus",
]

## The authentic V3 Tinker Combat Scrap printings (starter and pool).
const V3_TINKER_COMBAT_SCRAP_STARTER_IDS: Array[String] = [
	"tinker_v3_cog_shot",
	"tinker_v3_cog_shot_plus",
	"tinker_v3_casing_ward",
	"tinker_v3_casing_ward_plus",
	"tinker_v3_scrap_bomb",
	"tinker_v3_scrap_bomb_plus",
	"tinker_v3_tune_up",
	"tinker_v3_tune_up_plus",
]

const V3_TINKER_COMBAT_SCRAP_POOL_IDS: Array[String] = [
	"tinker_v3_brass_casing",
	"tinker_v3_brass_casing_plus",
	"tinker_v3_gear_brace",
	"tinker_v3_gear_brace_plus",
	"tinker_v3_spare_screws",
	"tinker_v3_spare_screws_plus",
	"tinker_v3_spring_clamp",
	"tinker_v3_spring_clamp_plus",
	"tinker_v3_overload",
	"tinker_v3_overload_plus",
	"tinker_v3_scrapstorm",
	"tinker_v3_scrapstorm_plus",
]


## One description of a validated card record:
## {known: bool, phrases: Array[String], line: String, unknown: bool}
## `phrases` are the complete short sentences in printed order.
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
		phrases.append(SWAP_SENTENCE)
	for part in [
		_tether_sentence(card, effects),
		_enemy_sentence(card, effects, applied),
		_other_heal_sentence(card, effects),
		_ally_sentence(card, effects, applied),
		_party_sentence(card, effects),
		_self_sentence(card, effects),
		_v3_guard_sentence(card, effects),
		_v3_taunt_sentence(card, effects),
		_v3_tinker_scrap_sentence(card, effects),
	]:
		var sentence := str(part.get("sentence", ""))
		if bool(part.get("unknown", false)):
			undescribed = true
		if not sentence.is_empty():
			phrases.append(sentence)
	# Exhaust is a card-level descriptor, so it follows every affected-target
	# sentence ("Blind to all. Exhaust.") when the record authors the boolean
	# true. Only that exact flag is read; any other value stays undescribed. The
	# sentence states the printed design rule only: it claims no live discard or
	# exhaust pile.
	if effects.has("exhaust"):
		if effects["exhaust"] is bool and bool(effects["exhaust"]):
			phrases.append(EXHAUST_SENTENCE)
		else:
			undescribed = true
	var unknown := undescribed or has_unknown(definition)
	if unknown:
		phrases.append(UNKNOWN_SENTENCE)
	return _result(true, phrases, unknown)


## The complete terse face line, sentences in the fixed printed order.
static func line(definition: Variant, applied: Dictionary = {}) -> String:
	return str(describe(definition, applied).get("line", ""))


## True when the record authors a field this formatter cannot describe.
static func has_unknown(definition: Variant) -> bool:
	if not definition is Dictionary:
		return false
	var card: Dictionary = definition
	var raw_effects: Variant = card.get("effects", {})
	if not raw_effects is Dictionary:
		return false
	var effects: Dictionary = raw_effects
	for key in effects:
		if str(key) not in KNOWN_EFFECT_KEYS:
			return true
	# `cannot_buff_next_turn` is only a known effect in the complete authored
	# Scarecrow printing; every other value, recipient or companion effect stays
	# an honest unknown instead of a guessed Fear keyword.
	if effects.has(FEAR_KEY) and not bool(_fear_clause(card, effects).get("valid", false)):
		return true
	# `ignore_block` is only a known effect in the four authentic Scarecrow crow
	# printings; every other value, recipient, damage or companion effect stays
	# an honest unknown instead of a guessed Block-piercing clause.
	if effects.has(CROW_KEY) and not bool(_crow_clause(card, effects).get("valid", false)):
		return true
	# `tether_share_percent` is only a known effect in the four authentic Seamstress
	# Tether printings; every other value, recipient, cost, slots or companion effect
	# stays an honest unknown instead of a guessed Tether rule.
	if effects.has(TETHER_KEY) and not is_authored_tether(card):
		return true
	# V3 Warden effect keys are known only in their authentic catalog printings;
	# any forged, altered, mis-owned or re-scoped card stays an honest unknown.
	if effects.has("guard_next_hit") and not is_authored_v3_guard(card):
		return true
	if effects.has("taunt_next_enemy_turn") and not is_authored_v3_taunt(card):
		return true
	if (effects.has("damage_equal_to_owner_block") or effects.has("bonus_damage")) \
			and not is_authored_v3_shield_toss(card):
		return true
	# V3 Tinker Combat Scrap effect keys are known only in their authentic catalog printings;
	# any forged, altered, mis-owned or re-scoped card stays an honest unknown.
	for key in [
		"combat_scrap_gain", "damage_per_combat_scrap", "consume_all_combat_scrap",
		"combat_scrap_spend_max", "bonus_damage_per_combat_scrap"
	]:
		if effects.has(key) and not is_authored_combat_scrap(card):
			return true
	return false


## True when this exact record is one of the eight authentic Scarecrow Fear
## printings. The Help glossary reuses this single authority so the sewn face and
## Help can never disagree about which cards really author Fear.
static func is_authored_fear(definition: Variant) -> bool:
	if not definition is Dictionary:
		return false
	var card: Dictionary = definition
	var raw_effects: Variant = card.get("effects", {})
	if not raw_effects is Dictionary:
		return false
	return bool(_fear_clause(card, raw_effects).get("valid", false))


## True when this exact record is one of the four authentic Scarecrow crow
## printings (Crow Dive and Crow Peck, base and '+'). The Help glossary reuses
## this single authority so the sewn face and Help can never disagree about
## which cards really author Block piercing.
static func is_authored_block_pierce(definition: Variant) -> bool:
	if not definition is Dictionary:
		return false
	var card: Dictionary = definition
	var raw_effects: Variant = card.get("effects", {})
	if not raw_effects is Dictionary:
		return false
	return bool(_crow_clause(card, raw_effects).get("valid", false))


static func is_authored_crow(definition: Variant) -> bool:
	return is_authored_block_pierce(definition)


## True when this exact record is one of the four authentic Seamstress Tether
## printings (Tether Loop and Tether Stitch, base and '+'). The Help glossary
## reuses this single authority so the sewn face and Help can never disagree about
## which cards really author Tether.
static func is_authored_tether(definition: Variant) -> bool:
	if not definition is Dictionary:
		return false
	return CombatSeamstressTetherRules.new().is_authentic_definition(definition)


static func _tether_sentence(card: Dictionary, effects: Dictionary) -> Dictionary:
	if not effects.has(TETHER_KEY):
		return {}
	if not is_authored_tether(card):
		return {"sentence": "", "unknown": true}
	return {"sentence": TETHER_SENTENCE, "unknown": false}


## True when this exact record is one of the authentic V3 Warden Guard printings
## (Shield Catch, Guard Stitch, Final Bastion, base and '+').
static func is_authored_v3_guard(definition: Variant) -> bool:
	return _is_authentic_v3_warden_card(definition, V3_WARDEN_GUARD_IDS)


static func is_authored_guard(definition: Variant) -> bool:
	return is_authored_v3_guard(definition)


## True when this exact record is one of the authentic V3 Warden Taunt printings
## (Iron Challenge, Iron Taunt, Shieldwall Chorus, Final Bastion, base and '+').
static func is_authored_v3_taunt(definition: Variant) -> bool:
	return _is_authentic_v3_warden_card(definition, V3_WARDEN_TAUNT_IDS)


static func is_authored_taunt(definition: Variant) -> bool:
	return is_authored_v3_taunt(definition)


## True when this exact record is one of the authentic V3 Warden Shield Toss printings
## (Rim Toss and Shield Toss, base and '+').
static func is_authored_v3_shield_toss(definition: Variant) -> bool:
	return _is_authentic_v3_warden_card(definition, V3_WARDEN_SHIELD_TOSS_IDS)


static func is_authored_shield_toss(definition: Variant) -> bool:
	return is_authored_v3_shield_toss(definition)


static func _v3_guard_sentence(card: Dictionary, effects: Dictionary) -> Dictionary:
	if not effects.has("guard_next_hit"):
		return {}
	if not is_authored_v3_guard(card):
		return {"sentence": "", "unknown": true}
	var flag: Variant = effects["guard_next_hit"]
	if not flag is bool or not bool(flag):
		return {"sentence": "", "unknown": true}
	return {"sentence": "Guard.", "unknown": false}


static func _v3_taunt_sentence(card: Dictionary, effects: Dictionary) -> Dictionary:
	if not effects.has("taunt_next_enemy_turn"):
		return {}
	if not is_authored_v3_taunt(card):
		return {"sentence": "", "unknown": true}
	var flag: Variant = effects["taunt_next_enemy_turn"]
	if not flag is bool or not bool(flag):
		return {"sentence": "", "unknown": true}
	return {"sentence": "Taunt.", "unknown": false}

## True when this exact record is one of the authentic V3 Tinker Combat Scrap printings.
static func is_authored_v3_tinker_combat_scrap(definition: Variant) -> bool:
	return _is_authentic_v3_tinker_combat_scrap_card(definition)


static func is_authored_combat_scrap(definition: Variant) -> bool:
	return is_authored_v3_tinker_combat_scrap(definition)


static func _catalog_v3_tinker_definition(card_id: String) -> Dictionary:
	if V3_TINKER_COMBAT_SCRAP_STARTER_IDS.has(card_id):
		return V3TinkerStarterCards.new().get_definition(card_id)
	if V3_TINKER_COMBAT_SCRAP_POOL_IDS.has(card_id):
		return V3TinkerPoolCards.new().get_definition(card_id)
	return {}


static func _is_authentic_v3_tinker_combat_scrap_card(definition: Variant) -> bool:
	if not definition is Dictionary:
		return false
	var card: Dictionary = definition
	var id_value: Variant = card.get("id")
	if not id_value is String:
		return false
	var card_id: String = id_value
	var is_starter := V3_TINKER_COMBAT_SCRAP_STARTER_IDS.has(card_id)
	var is_pool := V3_TINKER_COMBAT_SCRAP_POOL_IDS.has(card_id)
	if not is_starter and not is_pool:
		return false
	var canonical: Dictionary = _catalog_v3_tinker_definition(card_id)
	if canonical.is_empty():
		return false
	if not _deep_exact_equal(card, canonical):
		return false
	var effects_value: Variant = card.get("effects")
	if not effects_value is Dictionary:
		return false
	if not _deep_exact_equal(effects_value, canonical.get("effects", {})):
		return false
	if is_starter:
		if canonical.has("upgrade_id"):
			if canonical.has("upgrade_of"):
				return false
			var plus_id_val: Variant = canonical["upgrade_id"]
			if not plus_id_val is String:
				return false
			var plus_id: String = plus_id_val
			var plus_canonical: Dictionary = _catalog_v3_tinker_definition(plus_id)
			if plus_canonical.is_empty() or str(plus_canonical.get("upgrade_of", "")) != card_id:
				return false
		elif canonical.has("upgrade_of"):
			if canonical.has("upgrade_id"):
				return false
			var base_id_val: Variant = canonical["upgrade_of"]
			if not base_id_val is String:
				return false
			var base_id: String = base_id_val
			var base_canonical: Dictionary = _catalog_v3_tinker_definition(base_id)
			if base_canonical.is_empty() or str(base_canonical.get("upgrade_id", "")) != card_id:
				return false
		else:
			return false
	elif is_pool:
		if not canonical.has("base_id") or not canonical.has("upgrade_id") or not canonical.has("is_upgrade"):
			return false
		var is_plus: bool = bool(canonical.get("is_upgrade", false))
		var base_id: String = str(canonical.get("base_id", ""))
		var plus_id: String = str(canonical.get("upgrade_id", ""))
		if not is_plus:
			if card_id != base_id:
				return false
			var plus_canonical: Dictionary = _catalog_v3_tinker_definition(plus_id)
			if plus_canonical.is_empty() or str(plus_canonical.get("base_id", "")) != card_id or not bool(plus_canonical.get("is_upgrade", false)):
				return false
		else:
			if card_id != plus_id:
				return false
			var base_canonical: Dictionary = _catalog_v3_tinker_definition(base_id)
			if base_canonical.is_empty() or str(base_canonical.get("upgrade_id", "")) != card_id or bool(base_canonical.get("is_upgrade", true)):
				return false
	return true


static func _has_tinker_scrap_effects(effects: Dictionary) -> bool:
	for key in [
		"combat_scrap_gain", "damage_per_combat_scrap", "consume_all_combat_scrap",
		"combat_scrap_spend_max", "bonus_damage_per_combat_scrap"
	]:
		if effects.has(key):
			return true
	return false


static func _v3_tinker_scrap_sentence(card: Dictionary, effects: Dictionary) -> Dictionary:
	if not _has_tinker_scrap_effects(effects):
		return {}
	if not is_authored_combat_scrap(card):
		return {"sentence": "", "unknown": true}
	if effects.has("combat_scrap_gain"):
		var amount := _amount(effects["combat_scrap_gain"], -1)
		if amount <= 0:
			return {"sentence": "", "unknown": true}
		return {"sentence": "Gain %d Combat Scrap." % amount, "unknown": false}
	if effects.has("damage_per_combat_scrap") and effects.has("consume_all_combat_scrap"):
		var per := _amount(effects["damage_per_combat_scrap"], -1)
		var consume: Variant = effects["consume_all_combat_scrap"]
		if per <= 0 or not consume is bool or not bool(consume):
			return {"sentence": "", "unknown": true}
		return {"sentence": "Spend all Combat Scrap for +%d damage per Scrap." % per, "unknown": false}
	if effects.has("combat_scrap_spend_max") and effects.has("bonus_damage_per_combat_scrap"):
		var spend_max := _amount(effects["combat_scrap_spend_max"], -1)
		var bonus := _amount(effects["bonus_damage_per_combat_scrap"], -1)
		if spend_max <= 0 or bonus <= 0:
			return {"sentence": "", "unknown": true}
		return {"sentence": "Spend up to %d Combat Scrap for +%d per spent Scrap to each living enemy." % [spend_max, bonus], "unknown": false}
	return {"sentence": "", "unknown": true}


## Reads the detached canonical record from the V3 Warden catalogs.
static func _catalog_v3_warden_definition(card_id: String) -> Dictionary:
	match card_id:
		"warden_v3_shield_catch", "warden_v3_shield_catch_plus", \
		"warden_v3_rim_toss", "warden_v3_rim_toss_plus", \
		"warden_v3_iron_challenge", "warden_v3_iron_challenge_plus":
			return V3WardenStarterCards.new().get_definition(card_id)
		"warden_v3_shield_toss", "warden_v3_shield_toss_plus", \
		"warden_v3_guard_stitch", "warden_v3_guard_stitch_plus", \
		"warden_v3_iron_taunt", "warden_v3_iron_taunt_plus", \
		"warden_v3_shieldwall_chorus", "warden_v3_shieldwall_chorus_plus", \
		"warden_v3_final_bastion", "warden_v3_final_bastion_plus":
			return V3WardenPoolCards.new().get_definition(card_id)
	return {}


static func _is_authentic_v3_warden_card(definition: Variant, valid_ids: Array[String]) -> bool:
	if not definition is Dictionary:
		return false
	var card: Dictionary = definition
	var id_value: Variant = card.get("id")
	if not id_value is String:
		return false
	var card_id: String = id_value
	if not valid_ids.has(card_id):
		return false
	var canonical: Dictionary = _catalog_v3_warden_definition(card_id)
	if canonical.is_empty():
		return false
	if not _deep_exact_equal(card, canonical):
		return false
	var effects_value: Variant = card.get("effects")
	if not effects_value is Dictionary:
		return false
	if not _deep_exact_equal(effects_value, canonical.get("effects", {})):
		return false
	# Verify reciprocal upgrade link
	if canonical.has("upgrade_id"):
		if canonical.has("upgrade_of"):
			return false
		var plus_id_val: Variant = canonical["upgrade_id"]
		if not plus_id_val is String:
			return false
		var plus_id: String = plus_id_val
		var plus_canonical: Dictionary = _catalog_v3_warden_definition(plus_id)
		if plus_canonical.is_empty() or str(plus_canonical.get("upgrade_of", "")) != card_id:
			return false
	elif canonical.has("upgrade_of"):
		if canonical.has("upgrade_id"):
			return false
		var base_id_val: Variant = canonical["upgrade_of"]
		if not base_id_val is String:
			return false
		var base_id: String = base_id_val
		var base_canonical: Dictionary = _catalog_v3_warden_definition(base_id)
		if base_canonical.is_empty() or str(base_canonical.get("upgrade_id", "")) != card_id:
			return false
	else:
		return false
	return true


## Fear is the Scarecrow's authored one-turn buff lock, never a status stack. The
## face prints it only when the whole descriptor matches one of the eight real
## catalog printings: boolean true, exact identity/owner/cost/recipient/slots,
## the authored Weak amount and no extra or missing effect key. Anything else is
## not a Fear this formatter will name. It claims no live combat effect.
static func _fear_clause(card: Dictionary, effects: Dictionary) -> Dictionary:
	var invalid := {"valid": false, "clause": ""}
	if not effects.has(FEAR_KEY):
		return invalid
	var flag: Variant = effects[FEAR_KEY]
	# `1`, `"true"` and `1.0` are not the authored boolean true.
	if not flag is bool or not bool(flag):
		return invalid
	var id_value: Variant = card.get("id")
	if not id_value is String:
		return invalid
	var card_id: String = id_value
	if not FEAR_PRINTINGS.has(card_id):
		return invalid
	var expected: Dictionary = FEAR_PRINTINGS[card_id]
	var owner_value: Variant = card.get("owner")
	if not owner_value is String or String(owner_value) != FEAR_OWNER:
		return invalid
	var target_value: Variant = card.get("target_kind")
	if not target_value is String or String(target_value) != str(expected["target_kind"]):
		return invalid
	var cost_value: Variant = card.get("cost")
	if not cost_value is int or int(cost_value) != int(expected["cost"]):
		return invalid
	if not _exact_positions(card.get("from_positions", null),
			expected["from_positions"]):
		return invalid
	if not _exact_positions(card.get("to_positions", null), expected["to_positions"]):
		return invalid
	var weak_value: Variant = effects.get("weak")
	if not weak_value is int or int(weak_value) != int(expected["weak"]):
		return invalid
	var expected_damage: int = int(expected["damage"])
	if effects.size() != (3 if expected_damage > 0 else 2):
		return invalid
	if expected_damage > 0:
		var damage_value: Variant = effects.get("damage")
		if not damage_value is int or int(damage_value) != expected_damage:
			return invalid
	return {"valid": true, "clause": FEAR_CLAUSE + _enemy_object_suffix(card)}


## Reads the detached canonical record from the catalog that authors this crow card.
static func _catalog_crow_definition(card_id: String) -> Dictionary:
	match card_id:
		"scarecrow_crow_dive", "scarecrow_crow_dive_plus":
			return ScarecrowStarterCards.new().get_definition(card_id)
		"scarecrow_crow_peck", "scarecrow_crow_peck_plus":
			return ScarecrowPoolCards.new().get_definition(card_id)
	return {}


## Strict deep comparison requiring exact matching types, keys and values.
static func _deep_exact_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	match typeof(a):
		TYPE_DICTIONARY:
			var dict_a: Dictionary = a
			var dict_b: Dictionary = b
			if dict_a.size() != dict_b.size():
				return false
			for key in dict_a:
				if not dict_b.has(key):
					return false
				if not _deep_exact_equal(dict_a[key], dict_b[key]):
					return false
			return true
		TYPE_ARRAY:
			var arr_a: Array = a
			var arr_b: Array = b
			if arr_a.size() != arr_b.size():
				return false
			for i in range(arr_a.size()):
				if not _deep_exact_equal(arr_a[i], arr_b[i]):
					return false
			return true
		_:
			return a == b


## Block piercing is the Scarecrow's shoulder crow strike, ignoring enemy Block.
## The face prints it only when the complete supplied card definition matches the
## detached canonical ScarecrowStarterCards/ScarecrowPoolCards catalog definition:
## all keys (display_name, illustration_path, starting_copies, reward_eligible,
## pool rarity, cost, target, positions, damage, ignore_block, upgrade links)
## and nested values, with no missing or unexpected fields. Anything else is not
## a Block pierce this formatter will name.
static func _crow_clause(card: Dictionary, effects: Dictionary) -> Dictionary:
	var invalid := {"valid": false, "clause": ""}
	if not effects.has(CROW_KEY):
		return invalid
	var flag: Variant = effects[CROW_KEY]
	# `1`, `"true"` and `1.0` are not the authored boolean true.
	if not flag is bool or not bool(flag):
		return invalid
	var id_value: Variant = card.get("id")
	if not id_value is String:
		return invalid
	var card_id: String = id_value
	if not CROW_PRINTINGS.has(card_id):
		return invalid
	var canonical: Dictionary = _catalog_crow_definition(card_id)
	if canonical.is_empty():
		return invalid
	if not _deep_exact_equal(card, canonical):
		return invalid
	if not _deep_exact_equal(effects, canonical.get("effects", {})):
		return invalid
	return {"valid": true, "clause": CROW_CLAUSE}


static func _result(known: bool, phrases: Array[String], unknown: bool) -> Dictionary:
	return {"known": known, "phrases": phrases, "line": SEPARATOR.join(phrases),
		"unknown": unknown}


## The authored recipient as the sentence names it; never a slot number.
static func _recipient(card: Dictionary) -> String:
	match str(card.get("target_kind", "")):
		"enemy_single":
			return "one enemy"
		"enemy_all":
			return "every enemy"
		"enemy_random":
			return "a random enemy"
		"enemy_back":
			return "the backmost living enemy"
		"ally_single":
			return "a chosen ally"
		"party_all":
			return "every ally"
		"self":
			return "yourself"
	return "the target"


static func _has_enemy_effects(effects: Dictionary) -> bool:
	for key in ["damage", "conditional_damage", "exposed", "weak", "bleed",
			"unravel", "bleed_multiplier", "pinned", "tangled", "blind",
			"blind_next_attack", FEAR_KEY, CROW_KEY, "damage_equal_to_owner_block"]:
		if effects.has(key):
			return true
	return false


## Damage, statuses, Unravel and Pin all target the cast's own recipient. The face
## prints them as compact clauses with the amount in front and a full stop between
## effects ("Deal 4. Exposed 1.", "Deal 3 to all.", "Deal 2 x3, random.") instead
## of one long "damage to one enemy and apply" sentence.
static func _enemy_sentence(card: Dictionary, effects: Dictionary,
		applied: Dictionary) -> Dictionary:
	if not _has_enemy_effects(effects):
		return {}
	var unknown := false
	var hits := _hits(effects)
	var random_each := bool(effects.get("random_target_each_hit", false))
	var object_suffix := _enemy_object_suffix(card)
	var clauses: Array[String] = []
	var damage := ""
	if effects.has("damage"):
		var authored := _amount(effects["damage"], -1)
		if authored >= 0:
			damage = "deal %d" % authored
			if hits > 1:
				damage += " x%d" % hits
			# A per-hit random cast says so; every other cast names its recipient.
			damage += ", random" if random_each else object_suffix
		else:
			unknown = true
	if effects.has("conditional_damage"):
		var condition: Variant = effects["conditional_damage"]
		var empowered := _amount((condition as Dictionary).get("damage", -1) \
			if condition is Dictionary else -1, -1)
		if empowered < 0:
			unknown = true
		elif damage.is_empty():
			var conditional_damage := "deal %d" % empowered
			conditional_damage += ", random" if random_each else object_suffix
			damage = "%s if %s" % [conditional_damage, _condition_text(condition)]
		else:
			# The empowered amount replaces the base damage; it is not a second hit.
			damage += ", or %d if %s" % [empowered, _condition_text(condition)]
	if effects.has("damage_equal_to_owner_block"):
		if is_authored_v3_shield_toss(card) and not effects.has("damage"):
			var flag: Variant = effects["damage_equal_to_owner_block"]
			if flag is bool and bool(flag):
				var bonus_val: Variant = effects.get("bonus_damage")
				var bonus := 0
				if bonus_val != null:
					if bonus_val is int and int(bonus_val) > 0:
						bonus = int(bonus_val)
					else:
						unknown = true
				if not unknown:
					if bonus > 0:
						damage = "deal damage equal to current Block + %d" % bonus
					else:
						damage = "deal damage equal to current Block"
			else:
				unknown = true
		else:
			unknown = true
	if effects.has("bonus_damage") and not effects.has("damage_equal_to_owner_block"):
		unknown = true
	if not damage.is_empty():
		clauses.append(damage)
	if effects.has(CROW_KEY):
		var crow := _crow_clause(card, effects)
		if bool(crow.get("valid", false)):
			clauses.append(str(crow["clause"]))
		else:
			unknown = true
	# One merged status clause in the fixed order, then Unravel and Pin.
	var status := _status_labels(effects, applied)
	if bool(status.get("unknown", false)):
		unknown = true
	var labels: Array = status.get("labels", [])
	var status_texts: Array[String] = []
	for label in labels:
		status_texts.append(str(label))
	if not status_texts.is_empty():
		clauses.append(", ".join(status_texts) + object_suffix)
	if effects.has("unravel"):
		var authored := _amount(effects["unravel"], -1)
		if authored > 0:
			clauses.append("unravel %d%s" % [
				_amount(applied.get("unravel", authored), authored), object_suffix])
		else:
			unknown = true
	# The face names the keyword only: the different-owner +5 and its single
	# consumption stay in the sewn Help glossary, which explains them in full.
	if effects.has("pinned"):
		if _pin_bonus(effects["pinned"]) < 0:
			unknown = true
		else:
			clauses.append("pin" + object_suffix)
	# Tangled is an enemy-only status and needs no damage clause beside it. Only a
	# positive authored count on an enemy cast is printed; anything else stays
	# undescribed instead of inventing turns.
	if effects.has("tangled"):
		var tangled := _amount(effects["tangled"], -1)
		if tangled > 0 and _is_enemy_target(card):
			clauses.append("tangled %d%s" % [tangled, object_suffix])
		else:
			unknown = true
	# Blind is a one-shot keyword: the recipient's next attack misses and the
	# Blind is spent, so the face prints the keyword and no duration. Only the
	# two authored spellings on an enemy cast are read; a malformed value, two
	# spellings at once or a non-enemy recipient stays undescribed instead of
	# inventing a Blind.
	if effects.has("blind") or effects.has("blind_next_attack"):
		var blind := _blind_clause(card, effects)
		if bool(blind.get("valid", false)):
			clauses.append(str(blind["clause"]))
		else:
			unknown = true
	# Fear follows Weak (and any damage clause) as one bare keyword on the
	# authentic Scarecrow printing. The buff lock is not a status count, so no
	# number is printed and the flag is never normalized into a duration.
	if effects.has(FEAR_KEY):
		var fear := _fear_clause(card, effects)
		if bool(fear.get("valid", false)):
			clauses.append(str(fear["clause"]))
		else:
			unknown = true
	var phrases: Array[String] = []
	for clause in clauses:
		phrases.append(_capitalize(clause) + ".")
	if effects.has("bleed_multiplier"):
		var multiplier := _amount(effects["bleed_multiplier"], -1)
		if multiplier == 2:
			phrases.append("Double Bleed%s." % object_suffix)
		elif multiplier > 2:
			phrases.append("Multiply Bleed x%d%s." % [multiplier, object_suffix])
		else:
			unknown = true
	return {"sentence": SEPARATOR.join(phrases).strip_edges(), "unknown": unknown}


## The authored Blind spellings: the starter catalogs write `blind: 1` (the
## literal integer one) and the reward pool writes `blind_next_attack: true`
## (a boolean, not an integer). Both mean the same one-shot keyword, so two
## spellings on one record are ambiguous. Any other value, a missing/extra
## spelling or a non-enemy recipient is not a Blind this formatter will print.
static func _blind_clause(card: Dictionary, effects: Dictionary) -> Dictionary:
	if not _is_enemy_target(card):
		return {"valid": false, "clause": ""}
	if effects.has("blind") == effects.has("blind_next_attack"):
		return {"valid": false, "clause": ""}
	var valid := false
	if effects.has("blind"):
		var stacks: Variant = effects["blind"]
		# `true` and `1.0` are not the authored integer one.
		valid = stacks is int and int(stacks) == 1
	else:
		var flag: Variant = effects["blind_next_attack"]
		valid = flag is bool and bool(flag)
	if not valid:
		return {"valid": false, "clause": ""}
	return {"valid": true, "clause": "blind" + _enemy_object_suffix(card)}


## The recipient a non-damage clause names: an area cast says "to all" once per
## clause, a random cast keeps its random object, and a single enemy needs none.
static func _enemy_object_suffix(card: Dictionary) -> String:
	match str(card.get("target_kind", "")):
		"enemy_single":
			return ""
		"enemy_all":
			return " to all"
		"enemy_random":
			return " to a random enemy"
	return " to " + _recipient(card)


## The authored status labels in the fixed printed order, with applied amounts.
static func _status_labels(effects: Dictionary, applied: Dictionary) -> Dictionary:
	var labels: Array[String] = []
	var unknown := false
	for status in STATUS_ORDER:
		if not effects.has(status):
			continue
		var authored := _amount(effects[status], -1)
		if authored <= 0:
			unknown = true
			continue
		var amount := _amount(applied.get(status, authored), authored)
		labels.append("%s %d" % [status.capitalize(), amount])
	return {"labels": labels, "unknown": unknown}


## The ally/support sentence keeps its explicit "apply Exposed 1 and Bleed 3"
## wording; only the enemy face uses the terse status list.
static func _status_clause(effects: Dictionary, applied: Dictionary) -> Dictionary:
	var status := _status_labels(effects, applied)
	var unknown := bool(status.get("unknown", false))
	var labels: Array = status.get("labels", [])
	var typed: Array[String] = []
	for label in labels:
		typed.append(str(label))
	if typed.is_empty():
		return {"text": "", "empty": true, "unknown": unknown}
	return {"text": "apply " + _join_and(typed), "empty": false, "unknown": unknown}


## Self-directed effects: Block, draw, energy, HP loss, Guard, Thorns, the
## one-shot Dodge and the bonus that arms a later attack. `other_ally_block`
## shares this sentence because it is paid by the same cast while the rest of
## the line stays short.
static func _self_sentence(card: Dictionary, effects: Dictionary) -> Dictionary:
	var unknown := false
	var clauses: Array[String] = []
	var ally_single := str(card.get("target_kind", "")) == "ally_single"
	if effects.has("block") and not ally_single:
		var block := _amount(effects["block"], -1)
		if block >= 0:
			clauses.append("gain %d Block" % block)
		else:
			unknown = true
	if effects.has("other_ally_block"):
		var ally_block := _amount(effects["other_ally_block"], -1)
		if ally_block >= 0:
			clauses.append("other allies gain %d Block" % ally_block)
		else:
			unknown = true
	if effects.has("draw"):
		var draw := _amount(effects["draw"], -1)
		if draw > 0:
			clauses.append("draw %d" % draw)
		else:
			unknown = true
	for key in ["gain_energy", "energy"]:
		if not effects.has(key):
			continue
		# One energy clause only: an explicit gain_energy wins over a bare energy.
		if key == "energy" and effects.has("gain_energy"):
			continue
		var energy := _amount(effects[key], -1)
		if energy > 0:
			clauses.append("gain %d energy" % energy)
		else:
			unknown = true
	if effects.has("next_turn_energy"):
		var credit := _amount(effects["next_turn_energy"], -1)
		if credit > 0:
			clauses.append("gain %d energy next turn" % credit)
		else:
			unknown = true
	if effects.has("next_attack_damage_bonus"):
		var bonus := _amount(effects["next_attack_damage_bonus"], -1)
		if bonus > 0:
			var timing := " this turn" \
				if str(effects.get("expires", "")) == "end_of_player_turn" else ""
			clauses.append("your next attack%s deals +%d damage" % [timing, bonus])
		else:
			unknown = true
	if effects.has("self_hp_loss"):
		var cost_hp := _amount(effects["self_hp_loss"], -1)
		if cost_hp > 0:
			clauses.append("lose %d HP" % cost_hp)
		else:
			unknown = true
	# Guard and Thorns print their keyword and authored amount only; the Help
	# glossary owns the redirect/return-damage rules and their expiry.
	if effects.has("guarding"):
		if _flag(effects["guarding"]):
			clauses.append("Guard")
		else:
			unknown = true
	if effects.has("thorns"):
		var thorns := _amount(effects["thorns"], -1)
		if thorns > 0:
			clauses.append("gain %d Thorns" % thorns)
		else:
			unknown = true
	# Riposte is a self effect: only a positive authored amount on the caster's own
	# record with the authored one-turn duration is printed. The counterhit rule
	# itself belongs to the Help glossary.
	if effects.has("riposte"):
		var riposte := _amount(effects["riposte"], -1)
		if riposte > 0 and _one_turn(effects) \
				and str(card.get("target_kind", "")) == "self":
			clauses.append("gain %d Riposte" % riposte)
		else:
			unknown = true
	# Dodge is the Rag Duelist's and Lantern Monk's one-shot next-attack
	# avoidance. A single chosen ally prints it in the ally sentence, so this
	# sentence only owns the caster's own record; every other recipient stays
	# undescribed rather than borrowing a self Dodge.
	if effects.has("dodge_next_attack") \
			and str(card.get("target_kind", "")) != "ally_single":
		var dodge := _dodge_clause(card, effects)
		if bool(dodge.get("valid", false)):
			clauses.append(str(dodge["clause"]))
		else:
			unknown = true
	if clauses.is_empty():
		return {"sentence": "", "unknown": unknown}
	var sentences: Array[String] = []
	for clause in clauses:
		sentences.append(_capitalize(clause) + ".")
	return {"sentence": SEPARATOR.join(sentences), "unknown": unknown}


## A single chosen ally: healing first, then the Block and one-shot Dodge it
## also receives, joined into one natural short sentence.
static func _ally_sentence(card: Dictionary, effects: Dictionary,
		applied: Dictionary) -> Dictionary:
	if str(card.get("target_kind", "")) != "ally_single":
		return {}
	var unknown := false
	var clauses: Array[String] = []
	var healed := false
	if effects.get("heal") is int:
		var heal := _amount(effects["heal"], -1)
		if heal >= 0:
			clauses.append("heal ally %d HP" % heal)
			healed = true
		else:
			unknown = true
	if effects.has("block"):
		var block := _amount(effects["block"], -1)
		if block >= 0:
			clauses.append("grant %d Block" % block if healed
				else "ally gains %d Block" % block)
		else:
			unknown = true
	# An ally Dodge joins the Block in the same sentence: "Ally gains 6 Block
	# and dodges the next attack."
	if effects.has("dodge_next_attack"):
		var dodge := _dodge_clause(card, effects)
		if bool(dodge.get("valid", false)):
			clauses.append(str(dodge["clause"]))
		else:
			unknown = true
	var status_clause := _status_clause(effects, applied)
	if not bool(status_clause.get("empty", true)):
		clauses.append(str(status_clause["text"]))
	if bool(status_clause.get("unknown", false)):
		unknown = true
	if effects.has("unravel"):
		var authored := _amount(effects["unravel"], -1)
		if authored > 0:
			clauses.append("add %d Unravel" % _amount(applied.get("unravel", authored), authored))
		else:
			unknown = true
	if clauses.is_empty():
		return {"sentence": "", "unknown": unknown}
	return {"sentence": _capitalize(_join_and(clauses)) + ".", "unknown": unknown}


## Every ally: an area Block or heal.
static func _party_sentence(card: Dictionary, effects: Dictionary) -> Dictionary:
	if str(card.get("target_kind", "")) != "party_all":
		return {}
	var unknown := false
	var clauses: Array[String] = []
	if effects.get("heal") is int:
		var heal := _amount(effects["heal"], -1)
		if heal >= 0:
			clauses.append("heal all allies %d HP" % heal)
		else:
			unknown = true
	if effects.has("block_all"):
		var all_block := _amount(effects["block_all"], -1)
		if all_block >= 0:
			clauses.append("all allies gain %d Block" % all_block)
		else:
			unknown = true
	if clauses.is_empty():
		return {"sentence": "", "unknown": unknown}
	return {"sentence": _capitalize(_join_and(clauses)) + ".", "unknown": unknown}


## An authored descriptor heal names its own recipient, so it never borrows the
## cast's target. Capped amounts say so instead of promising a full heal.
static func _other_heal_sentence(card: Dictionary, effects: Dictionary) -> Dictionary:
	if not effects.get("heal") is Dictionary:
		return {}
	var heal: Dictionary = effects["heal"]
	var amount := _amount(heal.get("amount", -1), -1)
	if amount < 0:
		return {"sentence": "", "unknown": true}
	var who := "weakest ally" \
		if str(heal.get("target", "")) == "weakest_living_ally" else _recipient(card)
	var sentence := "Heal %s %d HP" % [who, amount]
	if str(heal.get("cap", "")) == "missing_hp":
		sentence += " (up to missing HP)"
	return {"sentence": sentence + ".", "unknown": false}


static func _condition_text(value: Variant) -> String:
	var conditions: Array[String] = []
	if value is Dictionary and (value as Dictionary).get("conditions") is Array:
		for entry in (value as Dictionary)["conditions"]:
			if not entry is Dictionary:
				continue
			var predicate: Dictionary = entry
			if str(predicate.get("status", "")) == "unravelled":
				if not conditions.has("Unravelled"):
					conditions.append("Unravelled")
			elif str(predicate.get("gauge", "")) == "unravel" \
					and str(predicate.get("comparison", "")) == "at_least_half":
				if not conditions.has("half gauge"):
					conditions.append("half gauge")
	if conditions.is_empty():
		return "an unstated condition"
	var joiner := " and " if value is Dictionary \
		and str((value as Dictionary).get("operator", "or")) == "and" else " or "
	return joiner.join(conditions)


## Only an authored true flag or a well-formed descriptor is a Pin; the amount it
## would add is validated here but never printed on the face.
static func _pin_bonus(value: Variant) -> int:
	if value is bool:
		return 0 if bool(value) else -1
	if not value is Dictionary:
		return -1
	var rule: Dictionary = value
	if rule.is_empty():
		return -1
	return _amount(rule.get("bonus_damage", 0), 0)


static func _hits(effects: Dictionary) -> int:
	if effects.get("hits") is int:
		return maxi(1, int(effects["hits"]))
	if effects.get("hit_count") is int:
		return maxi(1, int(effects["hit_count"]))
	return 1


## The authored one-turn duration a Riposte is written for; anything else is not
## described, so no amount is printed against a duration the record does not state.
static func _one_turn(effects: Dictionary) -> bool:
	var value: Variant = effects.get("duration")
	return value is int and int(value) == 1


## The authored one-shot Dodge: the integer one on the caster's own record or on
## a single chosen ally, with the optional authored one-turn duration when the
## record carries one. Any other amount or type, another recipient, a malformed
## duration or an absent `dodge_next_attack` is not a Dodge this formatter will
## print, so the face keeps the honest fallback. The wording repeats the printed
## design rule only; live combat does not cancel an enemy attack here.
static func _dodge_clause(card: Dictionary, effects: Dictionary) -> Dictionary:
	var target := str(card.get("target_kind", ""))
	if target != "self" and target != "ally_single":
		return {"valid": false, "clause": ""}
	var amount: Variant = effects.get("dodge_next_attack")
	# `true` and `1.0` are not the authored integer one.
	if not amount is int or int(amount) != 1:
		return {"valid": false, "clause": ""}
	# The duration is optional, but a present one must be the authored one turn.
	if effects.has("duration") and not _one_turn(effects):
		return {"valid": false, "clause": ""}
	return {"valid": true,
		"clause": ALLY_DODGE_CLAUSE if target == "ally_single" else SELF_DODGE_CLAUSE}


## Tangled is applied to an enemy only; a self or ally cast never borrows its count.
static func _is_enemy_target(card: Dictionary) -> bool:
	return str(card.get("target_kind", "")).begins_with("enemy_")


## The authored position list, exactly as expected in order and nothing else.
static func _exact_positions(value: Variant, expected: Variant) -> bool:
	if not value is Array or not expected is Array:
		return false
	var actual: Array = value
	var wanted: Array = expected
	if actual.size() != wanted.size():
		return false
	for index in range(wanted.size()):
		var slot: Variant = actual[index]
		if not slot is int or int(slot) != int(wanted[index]):
			return false
	return true


static func _amount(value: Variant, fallback: int) -> int:
	return int(value) if value is int else fallback


## Only an authored true flag or a non-empty authored rule dictionary is described.
static func _flag(value: Variant) -> bool:
	if value is bool:
		return bool(value)
	return value is Dictionary and not (value as Dictionary).is_empty()


static func _join_and(parts: Array[String]) -> String:
	if parts.is_empty():
		return ""
	if parts.size() == 1:
		return parts[0]
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts.back()


static func _capitalize(text: String) -> String:
	if text.is_empty():
		return text
	return text.substr(0, 1).to_upper() + text.substr(1)

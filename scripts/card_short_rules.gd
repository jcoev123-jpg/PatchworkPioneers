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
]
## Sentences are separated by one space, so the face reads as ordinary prose.
const SEPARATOR := " "
## Terse markers the hover legend still explains for the painted pips.
const ALL_TARGET := "ALL"
const RANDOM_TARGET := "RND"
const SWAP_SENTENCE := "Swap with adjacent ally."
const UNKNOWN_SENTENCE := "Other authored effects are not described."
## Statuses keep one fixed printed order whatever the authoring order is.
const STATUS_ORDER := ["exposed", "weak", "bleed"]


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
		_enemy_sentence(card, effects, applied),
		_other_heal_sentence(card, effects),
		_ally_sentence(card, effects, applied),
		_party_sentence(card, effects),
		_self_sentence(card, effects),
	]:
		var sentence := str(part.get("sentence", ""))
		if bool(part.get("unknown", false)):
			undescribed = true
		if not sentence.is_empty():
			phrases.append(sentence)
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


## The authored recipient as the sentence names it; never a slot number.
static func _recipient(card: Dictionary) -> String:
	match str(card.get("target_kind", "")):
		"enemy_single":
			return "one enemy"
		"enemy_all":
			return "every enemy"
		"enemy_random":
			return "a random enemy"
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
			"blind_next_attack"]:
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
	if not damage.is_empty():
		clauses.append(damage)
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


## Self-directed effects: Block, draw, energy, HP loss, Guard, Thorns and the
## bonus that arms a later attack. `other_ally_block` shares this sentence
## because it is paid by the same cast while the rest of the line stays short.
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
	if clauses.is_empty():
		return {"sentence": "", "unknown": unknown}
	var sentences: Array[String] = []
	for clause in clauses:
		sentences.append(_capitalize(clause) + ".")
	return {"sentence": SEPARATOR.join(sentences), "unknown": unknown}


## A single chosen ally: healing first, then the Block it also receives.
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


## Tangled is applied to an enemy only; a self or ally cast never borrows its count.
static func _is_enemy_target(card: Dictionary) -> bool:
	return str(card.get("target_kind", "")).begins_with("enemy_")


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

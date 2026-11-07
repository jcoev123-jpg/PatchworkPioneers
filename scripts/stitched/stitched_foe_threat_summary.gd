class_name StitchedFoeThreatSummary
extends RefCounted
## Pure, read-only wording for a detached StitchedFoeIntent projection.
## It only reads the dictionary it is given: no battle instance, no random calls, no
## combat resolution, no state and no scene dependency. Anything it cannot read with
## certainty (unknown side, absent or malformed ranks, PASS/STUN) yields "" rather
## than an invented target, hit, damage amount or status.

const SIDE_LABELS := {"hero": "HERO", "foe": "FOE"}
## Authored effects this summary can explain, in a stable reading order.
const EFFECT_ORDER := [
	"bleed", "weak", "exposed", "tangled", "blind", "stun", "mark",
	"thorns", "riposte", "guard", "snip", "tear", "fray", "push", "pull",
	"dodge", "heal",
]
const FRAY_MAX := 200


static func _amount(value: Variant) -> int:
	if value is int:
		return int(value)
	if value is float:
		return int(value)
	return 0


## Every rank the projection actually reaches, in ascending order, or an empty array
## when the rank list is absent, empty or malformed. No rank is ever invented.
static func _affected_ranks(intent: Dictionary) -> Array[int]:
	var ranks: Array[int] = []
	var raw: Variant = intent.get("affected_ranks", [])
	if not raw is Array:
		return ranks
	for value in raw:
		if not value is int:
			return []
		var rank := int(value)
		if rank < 1 or rank > 4:
			return []
		if not ranks.has(rank):
			ranks.append(rank)
	ranks.sort()
	return ranks


static func _damage_range(intent: Dictionary) -> Array[int]:
	var raw: Variant = intent.get("base_damage", [])
	if not raw is Array or (raw as Array).size() != 2:
		return []
	if not (raw as Array)[0] is int or not (raw as Array)[1] is int:
		return []
	return [int((raw as Array)[0]), int((raw as Array)[1])]


static func _status_note(key: String, effects: Dictionary) -> String:
	var amount := _amount(effects.get(key))
	# Snip, Tear, Push and Pull act on their presence in the authored effects; every
	# other entry needs a positive magnitude before it can be described as a status.
	var present_only := key in ["snip", "tear", "push", "pull"]
	if amount <= 0 and not present_only:
		return ""
	match key:
		"bleed":
			return "Bleed %d: %d HP at turn start, ignores PROT" % [amount, amount]
		"weak":
			return "Weak %d: attack damage -25%%" % amount
		"exposed":
			return "Exposed %d: incoming damage +50%%" % amount
		"tangled":
			return "Tangled %d: cannot move; incoming damage +2" % amount
		"blind":
			return "Blind %d: next attack misses" % amount
		"stun":
			return "Stun %d: skips the next turn" % amount
		"mark":
			return "Mark %d: bonus damage only to mark-hunting attacks" % amount
		"thorns":
			return "Thorns %d: %d damage back to each attacker" % [amount, amount]
		"riposte":
			return "Riposte %d: %d counter damage" % [amount, amount]
		"guard":
			return "Guard %d: intercepts hits aimed at the guarded ally" % amount
		"snip":
			return "Snip: cuts the thread behind; RE-TIE (a turn) before move, heal or guard can cross"
		"tear":
			return "Tear: strips one seeded random non-torso part"
		"fray":
			if amount > 0:
				return "Fray +%d: rises toward %d" % [amount, FRAY_MAX]
			return "Fray %d: eases the doll" % amount
		"push":
			return "Push: one rank back when legal and uncut"
		"pull":
			return "Pull: one rank forward when legal and uncut"
		"dodge":
			var turns := _amount(effects.get("duration"))
			if turns <= 0:
				return ""
			return "Dodge +%d for %d turn%s" % [amount, turns, "" if turns == 1 else "s"]
		"heal":
			return "Heal %d: restores %d HP where authored" % [amount, amount]
	return ""


## One readable line explaining the projected threat, or "" when the projection has no
## legal target. Effect clauses are ordered, quote the authored magnitudes, and are
## prefixed "IF HIT" exactly when the action must land its attack roll first.
static func summary(intent: Dictionary) -> String:
	if intent.is_empty():
		return ""
	# A skipped turn or a stunned actor announces no threat at all.
	if bool(intent.get("stun", false)) or bool(intent.get("pass", false)):
		return ""
	var side := str(intent.get("target_side", ""))
	if not SIDE_LABELS.has(side):
		return ""
	var ranks := _affected_ranks(intent)
	if ranks.is_empty():
		return ""
	var several := ranks.size() > 1 or bool(intent.get("multi", false))
	var rank_names: Array[String] = []
	for rank in ranks:
		rank_names.append(str(rank))
	var parts: Array[String] = ["THREAT %s %s %s" % [
		str(SIDE_LABELS[side]), "RANKS" if several else "RANK", ",".join(rank_names)]]
	var target_is_hero := side == "hero"
	var each := " each" if several else ""
	var effects: Dictionary = {}
	var raw_effects: Variant = intent.get("base_effects", {})
	if raw_effects is Dictionary:
		effects = raw_effects
	var damage := _damage_range(intent)
	if target_is_hero:
		var accuracy := _amount(intent.get("base_acc", 0))
		if accuracy > 0 and accuracy <= 100:
			parts.append("%d%% ACC%s" % [accuracy, each])
		if damage.is_empty():
			pass
		elif int(damage[1]) > 0:
			parts.append("IF LANDED %d–%d DMG%s" % [int(damage[0]), int(damage[1]), each])
		else:
			# A zero-direct-damage debuff is never sold as a damaging strike.
			parts.append("NO DIRECT DMG")
	else:
		# Self and allied actions take no enemy hit roll and hit nothing by force.
		parts.append("SELF/ALLY ACTION (no hit roll)")
		if not damage.is_empty() and int(damage[1]) <= 0:
			parts.append("NO DIRECT DMG")
	var notes: Array[String] = []
	for key in EFFECT_ORDER:
		if not effects.has(key):
			continue
		var note := _status_note(str(key), effects)
		if not note.is_empty():
			notes.append(note)
	var mark_bonus := _amount(intent.get("base_mark_damage", 0))
	if mark_bonus > 0:
		notes.append("+%d bonus vs Marked (mark-hunting only)" % mark_bonus)
	if not notes.is_empty():
		parts.append(("IF HIT: " if target_is_hero else "") + "; ".join(notes))
	elif effects.is_empty() and intent.has("base_effects"):
		parts.append("NO AUTHORED STATUS")
	return " · ".join(parts)

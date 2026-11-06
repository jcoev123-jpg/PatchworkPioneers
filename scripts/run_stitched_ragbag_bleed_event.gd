class_name RunStitchedRagbagBleedEvent
extends RefCounted
## Pure, scene-free projection helper for the Ragbag Walk curio Bleed trap
## (Design v4 STITCHED section 9b, Design v4 section 3).
##
## Turns an authentic, unconsumed biting_bundle trap descriptor from a Walk
## into a detached Bleed carry intent for the next battle:
##   {"kind": "bleed", "target": <doll_id>, "amount": 2}
##
## Pure projection only: does not mutate snapshots, roster, currency or statuses,
## does not roll or advance RNG, and maintains zero service state. Live battle
## wiring and once-only claim are owned by later run-session tasks.

const CURIO_ID := "biting_bundle"
const CURIO_KIND := "ragbag"
const CURIO_NAME := "Ragbag"
const TRAP_KIND := "curio_trap"
const STATUS_BLEED := "bleed"
const DEFAULT_BLEED_AMOUNT := 2
const MIN_RANK := 1
const MAX_RANK := 4
const CURIOS_PATH := "res://data/walk/curios.json"


## Projects an authentic unconsumed Walk pending trap entry into a detached carry receipt.
##
## Arguments:
##   pending_entry: Detached Dictionary from walk.snapshot().pending
##   curio_context: Placed curio instance dictionary and/or authored curio record
##   roster: Array or Dictionary of active dolls (ranks 1-4)
##   curio_record: Optional authored record from curios.json if curio_context is instance only
##
## Returns:
##   On success:
##     {"ok": true, "error": "", "carry": {"kind": "bleed", "target": doll_id, "amount": 2}, ...}
##   On failure:
##     {"ok": false, "error": <reason>, "carry": {}, "receipt": {}, "intent": {}}
static func project(pending_entry: Variant, curio_context: Variant, roster: Variant,
		curio_record: Variant = null) -> Dictionary:
	# 1. Validate pending entry
	if typeof(pending_entry) != TYPE_DICTIONARY:
		return _fail("pending entry must be a Dictionary")
	var pending: Dictionary = pending_entry

	if str(pending.get("kind", "")) != TRAP_KIND:
		return _fail("pending entry kind must be '%s', got '%s'" % [TRAP_KIND, str(pending.get("kind", ""))])

	if typeof(pending.get("consumed")) != TYPE_BOOL or pending.get("consumed") != false:
		return _fail("pending trap must be unconsumed (consumed == false)")

	var source: String = str(pending.get("source", "")).strip_edges()
	if source.is_empty():
		return _fail("pending trap missing valid source instance identifier")

	var target: String = str(pending.get("target", "")).strip_edges()
	if target.is_empty():
		return _fail("pending trap missing valid target recipient identifier")

	var effects_val: Variant = pending.get("effects")
	if typeof(effects_val) != TYPE_DICTIONARY:
		return _fail("pending trap effects must be a Dictionary")
	var effects: Dictionary = effects_val

	if str(effects.get("status", "")) != STATUS_BLEED:
		return _fail("pending trap status must be '%s', got '%s'" % [STATUS_BLEED, str(effects.get("status", ""))])

	var amount_val: Variant = effects.get("amount")
	if typeof(amount_val) != TYPE_INT and typeof(amount_val) != TYPE_FLOAT:
		return _fail("pending trap amount must be an integer, got %s" % type_string(typeof(amount_val)))
	if typeof(amount_val) == TYPE_FLOAT and float(amount_val) != floor(float(amount_val)):
		return _fail("pending trap amount must be a whole integer, got %s" % str(amount_val))
	var amount: int = int(amount_val)
	if amount <= 0:
		return _fail("pending trap amount must be strictly positive, got %d" % amount)
	if amount != DEFAULT_BLEED_AMOUNT:
		return _fail("authored Ragbag bleed amount must be %d, got %d" % [DEFAULT_BLEED_AMOUNT, amount])

	# 2. Validate curio context / record
	if typeof(curio_context) != TYPE_DICTIONARY:
		return _fail("curio context must be a Dictionary")
	var curio: Dictionary = curio_context

	var curio_id: String = str(curio.get("id", "")).strip_edges()
	if curio_id.is_empty() and curio_record is Dictionary:
		curio_id = str((curio_record as Dictionary).get("id", "")).strip_edges()
	if curio_id != CURIO_ID:
		return _fail("curio id must be '%s', got '%s'" % [CURIO_ID, curio_id])

	if curio.has("kind") and str(curio.get("kind", "")) != CURIO_KIND:
		return _fail("curio kind must be '%s', got '%s'" % [CURIO_KIND, str(curio.get("kind", ""))])

	if curio_record is Dictionary and (curio_record as Dictionary).has("kind"):
		if str((curio_record as Dictionary).get("kind", "")) != CURIO_KIND:
			return _fail("curio record kind must be '%s', got '%s'" % [CURIO_KIND, str((curio_record as Dictionary).get("kind", ""))])

	# Validate instance match
	if curio.has("instance"):
		var curio_inst: String = str(curio.get("instance", "")).strip_edges()
		if curio_inst != source:
			return _fail("source mismatch: pending source '%s' != curio instance '%s'" % [source, curio_inst])
	elif curio_record is Dictionary and (curio_record as Dictionary).has("instance"):
		var rec_inst: String = str((curio_record as Dictionary).get("instance", "")).strip_edges()
		if rec_inst != source:
			return _fail("source mismatch: pending source '%s' != record instance '%s'" % [source, rec_inst])

	# If authored rules are present, verify bleed value
	var rules: Variant = curio.get("rules")
	if typeof(rules) != TYPE_DICTIONARY and curio_record is Dictionary:
		rules = (curio_record as Dictionary).get("rules")
	if typeof(rules) == TYPE_DICTIONARY and (rules as Dictionary).has("bleed"):
		var rule_bleed: Variant = (rules as Dictionary).get("bleed")
		if (typeof(rule_bleed) != TYPE_INT and typeof(rule_bleed) != TYPE_FLOAT) or int(rule_bleed) != amount:
			return _fail("curio rule bleed amount (%s) does not match pending amount (%d)" % [str(rule_bleed), amount])

	# 3. Validate recipient in active roster
	var recipient_doll: Dictionary = {}
	var found_recipient := false

	if typeof(roster) == TYPE_ARRAY:
		for item: Variant in (roster as Array):
			if typeof(item) == TYPE_DICTIONARY and str((item as Dictionary).get("id", "")) == target:
				recipient_doll = (item as Dictionary).duplicate(true)
				found_recipient = true
				break
	elif typeof(roster) == TYPE_DICTIONARY:
		var roster_dict: Dictionary = roster
		if roster_dict.has(target) and typeof(roster_dict[target]) == TYPE_DICTIONARY:
			recipient_doll = (roster_dict[target] as Dictionary).duplicate(true)
			found_recipient = true
		else:
			for k: Variant in roster_dict:
				var item: Variant = roster_dict[k]
				if typeof(item) == TYPE_DICTIONARY and str((item as Dictionary).get("id", "")) == target:
					recipient_doll = (item as Dictionary).duplicate(true)
					found_recipient = true
					break
	else:
		return _fail("roster must be an Array or Dictionary")

	if not found_recipient:
		return _fail("target doll '%s' not found in active roster" % target)

	# Exclude lost recipients
	if bool(recipient_doll.get("lost", false)):
		return _fail("target doll '%s' is lost" % target)

	# Validate recipient rank (1..4)
	if recipient_doll.has("rank"):
		var rank_val: Variant = recipient_doll.get("rank")
		if typeof(rank_val) != TYPE_INT or int(rank_val) < MIN_RANK or int(rank_val) > MAX_RANK:
			return _fail("target doll '%s' rank must be %d..%d, got %s" % [target, MIN_RANK, MAX_RANK, str(rank_val)])

	# Validate HP if present (hp == 0 is Hanging by a Thread, admitted for non-lost dolls; hp < 0 remains invalid)
	if recipient_doll.has("hp"):
		var hp_val: Variant = recipient_doll.get("hp")
		if (typeof(hp_val) == TYPE_INT or typeof(hp_val) == TYPE_FLOAT) and hp_val < 0:
			return _fail("target doll '%s' has negative HP (%d)" % [target, int(hp_val)])

	# 4. Construct exact detached carry intent
	var carry_intent := {
		"kind": STATUS_BLEED,
		"target": target,
		"amount": DEFAULT_BLEED_AMOUNT
	}

	return {
		"ok": true,
		"error": "",
		"carry": carry_intent.duplicate(true),
		"receipt": carry_intent.duplicate(true),
		"intent": carry_intent.duplicate(true),
	}


## Convenience projection that directly extracts the carry Dictionary,
## or returns an empty Dictionary on failure.
static func project_carry(pending_entry: Variant, curio_context: Variant, roster: Variant,
		curio_record: Variant = null) -> Dictionary:
	var result := project(pending_entry, curio_context, roster, curio_record)
	if not bool(result.get("ok", false)):
		return {}
	return (result.get("carry", {}) as Dictionary).duplicate(true)


## Convenience projection directly from a Walk snapshot.
## Finds the unconsumed biting_bundle curio_trap in snapshot.pending.
static func project_from_snapshot(snapshot: Variant, curio_ref: Variant = "") -> Dictionary:
	if typeof(snapshot) != TYPE_DICTIONARY:
		return _fail("snapshot must be a Dictionary")
	var snap: Dictionary = snapshot

	var dolls_val: Variant = snap.get("dolls")
	if typeof(dolls_val) != TYPE_ARRAY and typeof(dolls_val) != TYPE_DICTIONARY:
		return _fail("snapshot missing dolls roster")

	var curios_val: Variant = snap.get("curios")
	if typeof(curios_val) != TYPE_ARRAY:
		return _fail("snapshot missing curios list")

	var target_curio: Dictionary = {}
	var ref_str: String = str(curio_ref).strip_edges()
	for c: Variant in (curios_val as Array):
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var cd: Dictionary = c
		if not ref_str.is_empty():
			if str(cd.get("instance", "")) == ref_str or str(cd.get("id", "")) == ref_str:
				target_curio = cd
				break
		else:
			if str(cd.get("id", "")) == CURIO_ID:
				target_curio = cd
				break

	if target_curio.is_empty():
		return _fail("biting_bundle curio not found in snapshot curios")

	var curio_instance: String = str(target_curio.get("instance", ""))
	var pending_val: Variant = snap.get("pending")
	if typeof(pending_val) != TYPE_ARRAY:
		return _fail("snapshot missing pending effects list")

	var trap_entry: Dictionary = {}
	for p: Variant in (pending_val as Array):
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var pd: Dictionary = p
		if str(pd.get("kind", "")) == TRAP_KIND and str(pd.get("source", "")) == curio_instance:
			if not bool(pd.get("consumed", false)):
				trap_entry = pd
				break

	if trap_entry.is_empty():
		return _fail("no unconsumed biting_bundle curio_trap found in snapshot pending list")

	return project(trap_entry, target_curio, dolls_val)


## Loads canonical curios.json record for biting_bundle.
static func load_canonical_record(path: String = CURIOS_PATH) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	var json: Variant = JSON.parse_string(text)
	if typeof(json) != TYPE_DICTIONARY or not (json as Dictionary).has("curios"):
		return {}
	var list: Variant = (json as Dictionary).get("curios")
	if typeof(list) != TYPE_ARRAY:
		return {}
	for record: Variant in (list as Array):
		if typeof(record) == TYPE_DICTIONARY and str((record as Dictionary).get("id", "")) == CURIO_ID:
			return (record as Dictionary).duplicate(true)
	return {}


static func _fail(message: String) -> Dictionary:
	return {
		"ok": false,
		"error": message,
		"carry": {},
		"receipt": {},
		"intent": {},
	}

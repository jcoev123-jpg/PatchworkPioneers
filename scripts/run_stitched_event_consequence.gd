class_name RunStitchedEventConsequence
extends RefCounted
## Scene-free Design v4 S6 groundwork: candle-and-fray Event bargains.
##
## Wraps the existing RunEventChoice envelope (id, title, description and two
## or three distinct {id, text} choices) with the deliberately opt-in
## `stitched_effect` outcome field:
##     {"candle": int, "fray": int, "target": "party"|"hero", "hero_id": "..."}
## `target: "party"` touches every active hero once; `target: "hero"` touches
## only the named active hero. A Leave is the same field with zero deltas.
##
## The caller supplies a detached snapshot
##     {"candle": int, "party": [{"id": String, "fray": int}, ...]}
## with candle 0..100 and one to four distinct canonical heroes at fray
## 0..200. This service only projects and reports intents: candle is clamped
## 0..100, while fray deltas stay raw and signed. The authoritative S1b
## Stitched rules (resolve check at 100, seam tears at 200, trait choice,
## 0..200 clamping) are the only owner of fray mutation and are deliberately
## not referenced here; a receipt is handed back for the S6 wiring to apply.
##
## No RNG is seeded or drawn, no caller snapshot is edited, and no legacy
## gold/scraps/vitality outcome is settled: the default cards-mode Event path
## and RunEventChoice's own settlement methods are untouched.

const CANDLE_MIN := 0
const CANDLE_MAX := 100
const FRAY_MIN := 0
const FRAY_MAX := 200
const MIN_PARTY_SIZE := 1
const MAX_PARTY_SIZE := 4
const TARGET_PARTY := "party"
const TARGET_HERO := "hero"
const MAX_SAFE_FLOAT_INT := 9007199254740992.0

## The eight authored Design v4 hero identities: the starter trio plus the
## five entries of data/heroes/v3_party_roster.json.
const CANONICAL_HERO_IDS := [
	"warden",
	"seamstress",
	"tinker",
	"lantern_monk",
	"rag_duelist",
	"scarecrow",
	"yarn_ranger",
	"button_golem",
]

var _choice: RunEventChoice = null
var _event: Dictionary = {}
var _valid: bool = false


func _init(event_record: Variant = null) -> void:
	# The shared envelope validator owns id/title/description and the two or
	# three distinct {id, text} choices. Stitched outcomes stay opt-in, so a
	# choice without `stitched_effect` is still a schema-valid envelope and is
	# refused per choice at preview/commit time.
	_choice = RunEventChoice.new(event_record)
	if not _choice.is_valid():
		return
	_event = _choice.get_event()
	_valid = true


## True only while this offering is schema-valid and still unclaimed.
func is_valid() -> bool:
	return _valid and not _choice.is_claimed()


## True once one choice has been committed on this instance.
func is_claimed() -> bool:
	return _choice.is_claimed()


## A detached deep copy of the authored event; mutating it never reaches this
## instance or the caller's original record.
func get_event() -> Dictionary:
	return _event.duplicate(true)


## Read-only, ordered preflight for one detached Stitched snapshot.
## Returns {"ok": bool, "event_id": String, "candle": int, "choices": [entry]}
## where each entry keeps its authored slot:
##   {"choice_id", "target", "hero_id", "candle_delta", "fray_delta",
##    "available", "candle", "fray"}
## A malformed outcome or an absent named hero yields available=false with
## null deltas (malformed) or parsed deltas (absent hero), the unchanged base
## candle and an empty fray map. Zero fray deltas produce no intent, so Leave
## yields an empty fray map. Deterministic, no RNG, no mutation of the input.
func preview(snapshot: Variant) -> Dictionary:
	var denied := {"ok": false, "event_id": "", "candle": 0, "choices": []}
	if not _valid or _choice.is_claimed():
		return denied
	var parsed_state: Dictionary = _parse_snapshot(snapshot)
	if not parsed_state.get("ok", false):
		return denied
	var base_state: Dictionary = parsed_state["snapshot"]
	var entries: Array = []
	for choice in _event.get("choices", []):
		entries.append(_preview_entry(choice, base_state))
	return {
		"ok": true,
		"event_id": _event.get("id", ""),
		"candle": int(base_state["candle"]),
		"choices": entries,
	}


## Attempts the single allowed claim for this visit with a detached snapshot.
## Returns {"ok": bool, "event_id": String, "choice_id": String,
## "target": String, "hero_id": String, "candle": int, "fray": Dictionary}
## where a success carries exactly the projected candle and the signed
## per-hero fray intents from preview(), and a rejection carries an empty
## receipt (the unchanged base candle for a valid snapshot, else 0) without
## consuming the claim or touching the caller's snapshot.
func choose(choice_id: Variant, snapshot: Variant) -> Dictionary:
	var parsed_state: Dictionary = _parse_snapshot(snapshot)
	if not parsed_state.get("ok", false):
		return _rejection(CANDLE_MIN)
	var base_state: Dictionary = parsed_state["snapshot"]
	var base_candle: int = int(base_state["candle"])
	if not _valid or _choice.is_claimed():
		return _rejection(base_candle)
	if not _is_nonblank_string(choice_id):
		return _rejection(base_candle)
	var target_id: String = choice_id
	var matched: Dictionary = {}
	for choice in _event.get("choices", []):
		if choice is Dictionary and (choice as Dictionary).get("id") == target_id:
			matched = choice
			break
	if matched.is_empty():
		return _rejection(base_candle)
	var parsed_effect: Dictionary = _parse_stitched_effect(matched)
	if not parsed_effect.get("ok", false):
		return _rejection(base_candle)
	# An absent named hero is unavailable, so it cannot latch the visit.
	if _target_ids(base_state, parsed_effect).is_empty():
		return _rejection(base_candle)
	var claim: Dictionary = _choice.choose(target_id)
	if not claim.get("ok", false):
		return _rejection(base_candle)
	return {
		"ok": true,
		"event_id": _event.get("id", ""),
		"choice_id": target_id,
		"target": parsed_effect["target"],
		"hero_id": parsed_effect["hero_id"],
		"candle": _project_candle(base_candle, int(parsed_effect["candle"])),
		"fray": _fray_intents(base_state, parsed_effect),
	}


## Candle arithmetic shared by preview and commit: clamp to 0..100 without
## ever overflowing on an extreme authored delta.
func _project_candle(base_candle: int, delta: int) -> int:
	if delta > 0:
		if delta > CANDLE_MAX - base_candle:
			return CANDLE_MAX
		return base_candle + delta
	if delta < 0:
		if delta < -base_candle:
			return CANDLE_MIN
		return base_candle + delta
	return base_candle


func _preview_entry(choice: Variant, base_state: Dictionary) -> Dictionary:
	var entry := {
		"choice_id": "",
		"target": "",
		"hero_id": "",
		"candle_delta": null,
		"fray_delta": null,
		"available": false,
		"candle": int(base_state["candle"]),
		"fray": {},
	}
	if not choice is Dictionary:
		return entry
	entry["choice_id"] = (choice as Dictionary).get("id", "")
	var parsed_effect: Dictionary = _parse_stitched_effect(choice)
	if not parsed_effect.get("ok", false):
		return entry
	entry["target"] = parsed_effect["target"]
	entry["hero_id"] = parsed_effect["hero_id"]
	entry["candle_delta"] = parsed_effect["candle"]
	entry["fray_delta"] = parsed_effect["fray"]
	if _target_ids(base_state, parsed_effect).is_empty():
		# The named hero is not in this party: readable deltas, no projection.
		return entry
	entry["available"] = true
	entry["candle"] = _project_candle(int(base_state["candle"]), int(parsed_effect["candle"]))
	entry["fray"] = _fray_intents(base_state, parsed_effect)
	return entry


## Raw signed intents for the S1b owner: one entry per affected active hero,
## never clamped. A zero delta carries no intent, so it is omitted.
func _fray_intents(base_state: Dictionary, parsed_effect: Dictionary) -> Dictionary:
	var intents: Dictionary = {}
	var delta: int = int(parsed_effect["fray"])
	if delta == 0:
		return intents
	for hero_id in _target_ids(base_state, parsed_effect):
		intents[hero_id] = delta
	return intents


func _target_ids(base_state: Dictionary, parsed_effect: Dictionary) -> Array:
	var ids: Array = []
	var party: Array = base_state["party"]
	if parsed_effect["target"] == TARGET_PARTY:
		for hero in party:
			ids.append(hero["id"])
		return ids
	for hero in party:
		if hero["id"] == parsed_effect["hero_id"]:
			ids.append(hero["id"])
			break
	return ids


## Strict snapshot parse: exactly {"candle", "party"}; candle 0..100; one to
## four distinct canonical heroes, each exactly {"id", "fray"} with fray
## 0..200. Returns a rebuilt detached copy, never the caller's dictionaries.
func _parse_snapshot(snapshot: Variant) -> Dictionary:
	if typeof(snapshot) != TYPE_DICTIONARY:
		return {"ok": false}
	var record: Dictionary = snapshot
	if record.size() != 2 or not record.has("candle") or not record.has("party"):
		return {"ok": false}
	var candle_read: Dictionary = _read_signed_int(record.get("candle"))
	if not candle_read.get("ok", false):
		return {"ok": false}
	var candle: int = int(candle_read["value"])
	if candle < CANDLE_MIN or candle > CANDLE_MAX:
		return {"ok": false}
	if typeof(record.get("party")) != TYPE_ARRAY:
		return {"ok": false}
	var raw_party: Array = record.get("party")
	if raw_party.size() < MIN_PARTY_SIZE or raw_party.size() > MAX_PARTY_SIZE:
		return {"ok": false}
	var party: Array = []
	var seen: Dictionary = {}
	for entry in raw_party:
		if typeof(entry) != TYPE_DICTIONARY:
			return {"ok": false}
		var hero: Dictionary = entry
		if hero.size() != 2 or not hero.has("id") or not hero.has("fray"):
			return {"ok": false}
		var raw_id: Variant = hero.get("id")
		if not _is_nonblank_string(raw_id) or not CANONICAL_HERO_IDS.has(raw_id):
			return {"ok": false}
		var hero_id: String = raw_id
		if seen.has(hero_id):
			return {"ok": false}
		seen[hero_id] = true
		var fray_read: Dictionary = _read_signed_int(hero.get("fray"))
		if not fray_read.get("ok", false):
			return {"ok": false}
		var fray: int = int(fray_read["value"])
		if fray < FRAY_MIN or fray > FRAY_MAX:
			return {"ok": false}
		party.append({"id": hero_id, "fray": fray})
	return {"ok": true, "snapshot": {"candle": candle, "party": party}}


## Strict opt-in outcome parse: a choice of exactly {id, text, stitched_effect}
## whose effect is exactly {candle, fray, target} for "party" or
## {candle, fray, target, hero_id} for "hero", with signed integer candle and
## fray and a canonical hero_id. Anything else is malformed and cannot settle.
func _parse_stitched_effect(choice: Variant) -> Dictionary:
	if typeof(choice) != TYPE_DICTIONARY:
		return {"ok": false}
	var record: Dictionary = choice
	if record.size() != 3 or not record.has("id") or not record.has("text") or not record.has("stitched_effect"):
		return {"ok": false}
	if typeof(record.get("stitched_effect")) != TYPE_DICTIONARY:
		return {"ok": false}
	var effect: Dictionary = record.get("stitched_effect")
	if typeof(effect.get("target")) != TYPE_STRING:
		return {"ok": false}
	var target: String = effect.get("target")
	if target != TARGET_PARTY and target != TARGET_HERO:
		return {"ok": false}
	var hero_id := ""
	if target == TARGET_PARTY:
		if effect.size() != 3:
			return {"ok": false}
	else:
		if effect.size() != 4 or not effect.has("hero_id"):
			return {"ok": false}
		var raw_hero: Variant = effect.get("hero_id")
		if not _is_nonblank_string(raw_hero) or not CANONICAL_HERO_IDS.has(raw_hero):
			return {"ok": false}
		hero_id = raw_hero
	if not effect.has("candle") or not effect.has("fray"):
		return {"ok": false}
	var candle_read: Dictionary = _read_signed_int(effect.get("candle"))
	var fray_read: Dictionary = _read_signed_int(effect.get("fray"))
	if not candle_read.get("ok", false) or not fray_read.get("ok", false):
		return {"ok": false}
	return {
		"ok": true,
		"candle": int(candle_read["value"]),
		"fray": int(fray_read["value"]),
		"target": target,
		"hero_id": hero_id,
	}


## A signed integer exactly as authored: a native int, or an integral finite
## number (JSON files parse numbers as floats). Fractions and non-numbers are
## malformed; nothing is rounded or clamped here.
func _read_signed_int(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_INT:
		return {"ok": true, "value": int(value)}
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if not is_finite(number) or absf(number) > MAX_SAFE_FLOAT_INT or floor(number) != number:
			return {"ok": false}
		return {"ok": true, "value": int(number)}
	return {"ok": false}


func _rejection(candle: int) -> Dictionary:
	return {
		"ok": false,
		"event_id": "",
		"choice_id": "",
		"target": "",
		"hero_id": "",
		"candle": candle,
		"fray": {},
	}


func _is_nonblank_string(value: Variant) -> bool:
	if not value is String:
		return false
	var text: String = value
	return not text.strip_edges().is_empty()

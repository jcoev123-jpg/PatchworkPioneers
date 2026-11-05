class_name RunStitchedEventConsequence
extends RefCounted
## Scene-free Design v4 S6 groundwork: candle, fray, party-scraps, party-gold, spare-part and hero-HP Event bargains.
##
## Wraps the existing RunEventChoice envelope (id, title, description and two
## or three distinct {id, text} choices) with the deliberately opt-in
## `stitched_effect` outcome field:
##     {"candle": int, "fray": int, "target": "party"|"hero", "hero_id": "...",
##      "required_hero": "...", "scraps": int, "gold": int, "hp": int,
##      "part": {"id": String, "tier": 1..3}, "require_full_candle": true,
##      "min_fray": 1..200, "required_candle_band": "bright"|...}
## `target: "party"` touches every active hero once; `target: "hero"` touches
## only the named active hero. `required_hero` is an optional canonical-hero
## admission gate on `stitched_effect` for both `target: "party"` and
## `target: "hero"`: a valid gated choice whose `required_hero` is absent from
## the active party is omitted from `preview().choices` and rejected by
## `choose()` without latching, while `target` / `hero_id` still determine the
## affected fray and HP recipients. `min_fray` is an optional native integer
## 1..200 admission gate on `stitched_effect`. For `target: "party"` without
## `required_hero`, the choice is available iff at least one active party member
## has fray >= min_fray. When `required_hero` is present on a party target, only
## that named hero can satisfy `min_fray` (companions cannot substitute).
## For `target: "hero"`, only the named `hero_id` is checked.
## `required_candle_band` is an optional native String admission gate on
## `stitched_effect` equal to one of the five lowercase band names defined by
## StitchedS1BEffects ("snuffed", "dark", "gloom", "dim", "bright"). When present,
## the choice is available in preview() and claimable in choose() iff the
## opening snapshot candle matches that exact band.
## `scraps`, `gold`, `part`, `hp` and
## `require_full_candle` are optional on `stitched_effect`; when omitted, the
## legacy 8-key preview entry and 7-key receipt shape are preserved. When
## present, `require_full_candle` must be native boolean `true` on a strictly
## negative native integer `candle` delta (`-N`), requiring `snapshot.candle >= N`
## for the choice to be available in `preview()` or claimable in `choose()`.
## When present, `scraps` and `gold` are
## signed integral deltas applied to the shared party scraps and gold purses
## (never per-hero), exposing `scraps_delta`/`scraps` and `gold_delta`/`gold` on
## that choice's preview entry and successful receipt. When present, `part` is an
## exact `{"id": String, "tier": int}` award with native integer tier 1..3 whose
## `id` resolves in a caller-supplied catalog validated with `StitchedParts.build_catalog`,
## exposing `part` and projected `satchel_count` (`+1`) on that choice's preview
## entry and receipt. When present, `hp` is a signed integral delta exposing
## `hp_delta` and raw per-hero `hp` intents (`{}` when `hp == 0`) on that
## choice's preview entry and successful receipt.
##
## The caller supplies a detached snapshot
##     {"candle": int, "party": [{"id": String, "fray": int[, "lost": bool]}, ...],
##      "scraps": int, "gold": int, "satchel_count": int}
## with candle 0..100, one to four distinct canonical heroes at fray 0..200
## (with optional native bool lost; absence means false),
## an optional native int `scraps >= 0`, an optional native int `gold >= 0`,
## and an optional native int `satchel_count` in 0..6. Scrap-bearing and
## gold-bearing choices require valid snapshot `scraps` / `gold` balances that
## stay within `0..MAX_INT` after the delta; part-bearing choices require a
## validated parts catalog containing `part.id` and a snapshot `satchel_count < 6`.
## Missing, insufficient or full capacity makes only that choice unavailable
## while legal alternatives on the same Event remain available.
##
## This service only projects and reports intents: candle is clamped 0..100,
## scraps and gold are projected without negative balances or 64-bit overflow,
## spare satchel count increments by 1 up to 6, and fray/HP deltas stay raw and signed.
## The authoritative S1b/S6 Stitched rules (resolve check at 100, seam tears at
## 200, trait choice, 0..200 clamping, HP/Hanging settlement) are the only owner
## of fray and HP mutation and are deliberately not referenced here; a receipt is
## handed back for the S6 wiring to apply.
##
## No RNG is seeded or drawn, no caller snapshot or catalog is edited, and no
## legacy gold/scraps/vitality outcome is settled: the default cards-mode Event
## path and RunEventChoice's own settlement methods are untouched.

const CANDLE_MIN := 0
const CANDLE_MAX := 100
const FRAY_MIN := 0
const FRAY_MAX := 200
const MIN_FRAY_MIN := 1
const MIN_FRAY_MAX := 200
const MIN_PARTY_SIZE := 1
const MAX_PARTY_SIZE := 4
const SATCHEL_MIN := 0
const SATCHEL_MAX := 6
const PART_TIER_MIN := StitchedParts.MIN_TIER
const PART_TIER_MAX := StitchedParts.MAX_TIER
const TARGET_PARTY := "party"
const TARGET_HERO := "hero"
const MAX_INT := 9223372036854775807
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

const CANDLE_BAND_NAMES := [
	"snuffed",
	"dark",
	"gloom",
	"dim",
	"bright",
]

var _choice: RunEventChoice = null
var _event: Dictionary = {}
var _catalog: Dictionary = {"ok": false, "by_id": {}}
var _valid: bool = false


func _init(event_record: Variant = null, catalog: Variant = null) -> void:
	# The shared envelope validator owns id/title/description and the two or
	# three distinct {id, text} choices. Stitched outcomes stay opt-in, so a
	# choice without `stitched_effect` is still a schema-valid envelope and is
	# refused per choice at preview/commit time.
	_choice = RunEventChoice.new(event_record)
	if not _choice.is_valid():
		return
	_event = _choice.get_event()
	if catalog != null:
		_catalog = _parse_catalog(catalog)
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
## Opt-in scrap-bearing choices also include `"scraps_delta"` and `"scraps"`,
## opt-in gold-bearing choices also include `"gold_delta"` and `"gold"`,
## opt-in part-bearing choices with a catalog-valid part also include
## `"part"` (`{id, tier}`) and `"satchel_count"`, and opt-in HP-bearing choices
## also include `"hp_delta"` and `"hp"`.
## A malformed outcome or an unavailable choice yields available=false with
## null deltas (malformed) or parsed deltas (absent hero / underfunded paid wick /
## missing, insufficient or overflowing scraps or gold / missing or full satchel_count),
## the unchanged base candle (plus base scraps / gold / satchel_count when present)
## and empty fray/hp maps. Zero fray or hp deltas produce no intent, so Leave yields
## empty intent maps. Deterministic, no RNG, no mutation of the input.
func preview(snapshot: Variant, catalog: Variant = null) -> Dictionary:
	var denied := {"ok": false, "event_id": "", "candle": 0, "choices": []}
	if not _valid or _choice.is_claimed():
		return denied
	var parsed_state: Dictionary = _parse_snapshot(snapshot)
	if not parsed_state.get("ok", false):
		return denied
	var base_state: Dictionary = parsed_state["snapshot"]
	var catalog_state: Dictionary = _resolve_catalog(catalog)
	var entries: Array = []
	for choice in _event.get("choices", []):
		if _is_hidden_by_required_hero(choice, base_state, catalog_state):
			continue
		entries.append(_preview_entry(choice, base_state, catalog_state))
	return {
		"ok": true,
		"event_id": _event.get("id", ""),
		"candle": int(base_state["candle"]),
		"choices": entries,
	}


## Attempts the single allowed claim for this visit with a detached snapshot.
## Returns {"ok": bool, "event_id": String, "choice_id": String,
## "target": String, "hero_id": String, "candle": int, "fray": Dictionary}
## (plus `"scraps_delta": int, "scraps": int` when a scrap-bearing choice
## succeeds, `"gold_delta": int, "gold": int` when a gold-bearing choice
## succeeds, `"part": {"id": String, "tier": int}, "satchel_count": int`
## when a part-bearing choice succeeds, and `"hp_delta": int, "hp": Dictionary`
## when an HP-bearing choice succeeds), where a success carries the exact
## projected values from preview() and a rejection carries the established 7-key
## refusal (the unchanged base candle for a valid snapshot, else 0) without
## consuming the claim or touching the caller's snapshot or catalog.
func choose(choice_id: Variant, snapshot: Variant, catalog: Variant = null) -> Dictionary:
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
	var catalog_state: Dictionary = _resolve_catalog(catalog)
	var parsed_effect: Dictionary = _parse_stitched_effect(matched, catalog_state)
	if not parsed_effect.get("ok", false):
		return _rejection(base_candle)
	if parsed_effect.get("has_required_hero", false) and not _party_has_hero(base_state, String(parsed_effect["required_hero"])):
		return _rejection(base_candle)
	# An absent named hero is unavailable, so it cannot latch the visit.
	if not _has_eligible_recipients(base_state, parsed_effect):
		return _rejection(base_candle)
	if not _meets_candle_band(base_candle, parsed_effect):
		return _rejection(base_candle)
	if not _meets_min_fray(base_state, parsed_effect):
		return _rejection(base_candle)
	if not _can_afford_candle(base_candle, parsed_effect):
		return _rejection(base_candle)
	var has_scraps: bool = parsed_effect.get("has_scraps", false)
	var projected_scraps := 0
	if has_scraps:
		var scraps_projection: Dictionary = _project_scraps(base_state, int(parsed_effect["scraps"]))
		if not scraps_projection.get("ok", false):
			return _rejection(base_candle)
		projected_scraps = int(scraps_projection["scraps"])
	var has_part: bool = parsed_effect.get("has_part", false)
	var projected_satchel_count := 0
	if has_part:
		var satchel_projection: Dictionary = _project_satchel_count(base_state)
		if not satchel_projection.get("ok", false):
			return _rejection(base_candle)
		projected_satchel_count = int(satchel_projection["satchel_count"])
	var has_gold: bool = parsed_effect.get("has_gold", false)
	var projected_gold := 0
	if has_gold:
		var gold_projection: Dictionary = _project_gold(base_state, int(parsed_effect["gold"]))
		if not gold_projection.get("ok", false):
			return _rejection(base_candle)
		projected_gold = int(gold_projection["gold"])
	var has_hp: bool = parsed_effect.get("has_hp", false)
	var claim: Dictionary = _choice.choose(target_id)
	if not claim.get("ok", false):
		return _rejection(base_candle)
	var receipt := {
		"ok": true,
		"event_id": _event.get("id", ""),
		"choice_id": target_id,
		"target": parsed_effect["target"],
		"hero_id": parsed_effect["hero_id"],
		"candle": _project_candle(base_candle, int(parsed_effect["candle"])),
		"fray": _fray_intents(base_state, parsed_effect),
	}
	if has_scraps:
		receipt["scraps_delta"] = int(parsed_effect["scraps"])
		receipt["scraps"] = projected_scraps
	if has_part:
		receipt["part"] = (parsed_effect["part"] as Dictionary).duplicate(true)
		receipt["satchel_count"] = projected_satchel_count
	if has_gold:
		receipt["gold_delta"] = int(parsed_effect["gold"])
		receipt["gold"] = projected_gold
	if has_hp:
		receipt["hp_delta"] = int(parsed_effect["hp"])
		receipt["hp"] = _hp_intents(base_state, parsed_effect)
	return receipt


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


## Shared candle-band admission gate for preview and commit when
## `required_candle_band` is present on `stitched_effect`.
## Compares the band name for the opening snapshot candle using
## StitchedS1BEffects.candle_band(base_candle).
func _meets_candle_band(base_candle: int, parsed_effect: Dictionary) -> bool:
	if not parsed_effect.get("has_required_candle_band", false):
		return true
	var band: Dictionary = StitchedS1BEffects.candle_band(base_candle)
	return String(band.get("name", "")) == String(parsed_effect.get("required_candle_band", ""))


## Shared full-wick affordability gate for preview and commit when
## `require_full_candle: true` is present on `stitched_effect`.
## Compares in signed arithmetic without negating `delta`.
func _can_afford_candle(base_candle: int, parsed_effect: Dictionary) -> bool:
	if not parsed_effect.get("require_full_candle", false):
		return true
	var delta: int = int(parsed_effect["candle"])
	return delta < 0 and delta >= -base_candle


## Shared FRAY admission gate for preview and commit when
## `min_fray` is present on `stitched_effect`.
## For target: "party" without required_hero, qualifies iff at least one active
## party member has fray >= min_fray. When required_hero is present on a party
## target, only that named hero can satisfy the threshold.
## For target: "hero", tests only hero_id.
func _meets_min_fray(base_state: Dictionary, parsed_effect: Dictionary) -> bool:
	if not parsed_effect.get("has_min_fray", false):
		return true
	var threshold: int = int(parsed_effect["min_fray"])
	var party: Array = base_state["party"]
	if parsed_effect["target"] == TARGET_HERO:
		var hero_id: String = String(parsed_effect["hero_id"])
		for hero in party:
			if hero["id"] == hero_id and not bool(hero.get("lost", false)):
				return int(hero["fray"]) >= threshold
		return false
	if parsed_effect.get("has_required_hero", false):
		var required_hero: String = String(parsed_effect["required_hero"])
		for hero in party:
			if hero["id"] == required_hero and not bool(hero.get("lost", false)):
				return int(hero["fray"]) >= threshold
		return false
	for hero in party:
		if not bool(hero.get("lost", false)) and int(hero["fray"]) >= threshold:
			return true
	return false


## Shared party-scraps arithmetic for preview and commit: requires a valid
## snapshot scraps balance, refuses debits below 0, and refuses positive deltas
## that would exceed signed 64-bit MAX_INT.
func _project_scraps(base_state: Dictionary, delta: int) -> Dictionary:
	if not base_state.has("scraps"):
		return {"ok": false}
	var base_scraps: int = int(base_state["scraps"])
	if delta >= 0:
		if delta > MAX_INT - base_scraps:
			return {"ok": false}
	elif base_scraps + delta < 0:
		return {"ok": false}
	return {"ok": true, "scraps": base_scraps + delta}


## Shared party-gold arithmetic for preview and commit: requires a valid
## snapshot gold balance, refuses debits below 0, and refuses positive deltas
## that would exceed signed 64-bit MAX_INT.
func _project_gold(base_state: Dictionary, delta: int) -> Dictionary:
	if not base_state.has("gold"):
		return {"ok": false}
	var base_gold: int = int(base_state["gold"])
	if delta >= 0:
		if delta > MAX_INT - base_gold:
			return {"ok": false}
	elif base_gold + delta < 0:
		return {"ok": false}
	return {"ok": true, "gold": base_gold + delta}


## Shared spare-satchel capacity check for preview and commit: requires a valid
## snapshot satchel_count (0..6) with room for one more spare part (< 6).
func _project_satchel_count(base_state: Dictionary) -> Dictionary:
	if not base_state.has("satchel_count"):
		return {"ok": false}
	var count: int = int(base_state["satchel_count"])
	if count < SATCHEL_MIN or count >= SATCHEL_MAX:
		return {"ok": false}
	return {"ok": true, "satchel_count": count + 1}


func _preview_entry(choice: Variant, base_state: Dictionary, catalog_state: Dictionary) -> Dictionary:
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
	var parsed_effect: Dictionary = _parse_stitched_effect(choice, catalog_state)
	if not parsed_effect.get("ok", false):
		return entry
	var has_scraps: bool = parsed_effect.get("has_scraps", false)
	var has_part: bool = parsed_effect.get("has_part", false)
	var has_gold: bool = parsed_effect.get("has_gold", false)
	var has_hp: bool = parsed_effect.get("has_hp", false)
	entry["target"] = parsed_effect["target"]
	entry["hero_id"] = parsed_effect["hero_id"]
	entry["candle_delta"] = parsed_effect["candle"]
	entry["fray_delta"] = parsed_effect["fray"]
	if has_scraps:
		entry["scraps_delta"] = parsed_effect["scraps"]
		entry["scraps"] = base_state.get("scraps")
	if has_part:
		entry["part"] = (parsed_effect["part"] as Dictionary).duplicate(true)
		entry["satchel_count"] = base_state.get("satchel_count")
	if has_gold:
		entry["gold_delta"] = parsed_effect["gold"]
		entry["gold"] = base_state.get("gold")
	if has_hp:
		entry["hp_delta"] = parsed_effect["hp"]
		entry["hp"] = {}
	if not _has_eligible_recipients(base_state, parsed_effect):
		# The named hero is not in this party: readable deltas, no projection.
		return entry
	if not _meets_candle_band(int(base_state["candle"]), parsed_effect):
		return entry
	if not _meets_min_fray(base_state, parsed_effect):
		return entry
	if not _can_afford_candle(int(base_state["candle"]), parsed_effect):
		return entry
	var projected_scraps := 0
	if has_scraps:
		var scraps_projection: Dictionary = _project_scraps(base_state, int(parsed_effect["scraps"]))
		if not scraps_projection.get("ok", false):
			return entry
		projected_scraps = int(scraps_projection["scraps"])
	var projected_satchel_count := 0
	if has_part:
		var satchel_projection: Dictionary = _project_satchel_count(base_state)
		if not satchel_projection.get("ok", false):
			return entry
		projected_satchel_count = int(satchel_projection["satchel_count"])
	var projected_gold := 0
	if has_gold:
		var gold_projection: Dictionary = _project_gold(base_state, int(parsed_effect["gold"]))
		if not gold_projection.get("ok", false):
			return entry
		projected_gold = int(gold_projection["gold"])
	entry["available"] = true
	entry["candle"] = _project_candle(int(base_state["candle"]), int(parsed_effect["candle"]))
	entry["fray"] = _fray_intents(base_state, parsed_effect)
	if has_scraps:
		entry["scraps"] = projected_scraps
	if has_part:
		entry["satchel_count"] = projected_satchel_count
	if has_gold:
		entry["gold"] = projected_gold
	if has_hp:
		entry["hp"] = _hp_intents(base_state, parsed_effect)
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


## Raw signed HP intents for the S6 owner: one entry per affected active hero,
## never clamped. A zero delta carries no intent, so it is omitted.
func _hp_intents(base_state: Dictionary, parsed_effect: Dictionary) -> Dictionary:
	var intents: Dictionary = {}
	var delta: int = int(parsed_effect["hp"])
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
			if not bool(hero.get("lost", false)):
				ids.append(hero["id"])
		return ids
	for hero in party:
		if hero["id"] == parsed_effect["hero_id"]:
			if not bool(hero.get("lost", false)):
				ids.append(hero["id"])
			break
	return ids


func _party_has_hero(base_state: Dictionary, hero_id: String) -> bool:
	var party: Array = base_state["party"]
	for hero in party:
		if hero["id"] == hero_id and not bool(hero.get("lost", false)):
			return true
	return false


func _has_eligible_recipients(base_state: Dictionary, parsed_effect: Dictionary) -> bool:
	if parsed_effect["target"] == TARGET_HERO:
		return not _target_ids(base_state, parsed_effect).is_empty()
	var has_targeted_benefits: bool = (
		int(parsed_effect["fray"]) != 0
		or (parsed_effect.get("has_hp", false) and int(parsed_effect["hp"]) != 0)
	)
	if has_targeted_benefits:
		return not _target_ids(base_state, parsed_effect).is_empty()
	return true


func _is_hidden_by_required_hero(choice: Variant, base_state: Dictionary, catalog_state: Dictionary) -> bool:
	var parsed_effect: Dictionary = _parse_stitched_effect(choice, catalog_state)
	if not parsed_effect.get("ok", false):
		return false
	if not parsed_effect.get("has_required_hero", false):
		return false
	return not _party_has_hero(base_state, String(parsed_effect["required_hero"]))


## Strict snapshot parse: {"candle", "party"} plus optional "scraps", "gold"
## and/or "satchel_count"; candle 0..100; optional native int scraps >= 0;
## optional native int gold >= 0; optional native int satchel_count 0..6;
## one to four distinct canonical heroes, each either exactly {"id", "fray"}
## or exactly {"id", "fray", "lost": bool} with fray 0..200. Absence of lost
## means false. Returns a rebuilt detached copy, never the caller's dictionaries.
func _parse_snapshot(snapshot: Variant) -> Dictionary:
	if typeof(snapshot) != TYPE_DICTIONARY:
		return {"ok": false}
	var record: Dictionary = snapshot
	if not record.has("candle") or not record.has("party"):
		return {"ok": false}
	var has_scraps: bool = record.has("scraps")
	var has_satchel_count: bool = record.has("satchel_count")
	var has_gold: bool = record.has("gold")
	var expected_size: int = (
		2
		+ (1 if has_scraps else 0)
		+ (1 if has_satchel_count else 0)
		+ (1 if has_gold else 0)
	)
	if record.size() != expected_size:
		return {"ok": false}
	var scraps_int := 0
	if has_scraps:
		var raw_scraps: Variant = record.get("scraps")
		if typeof(raw_scraps) != TYPE_INT:
			return {"ok": false}
		scraps_int = int(raw_scraps)
		if scraps_int < 0:
			return {"ok": false}
	var satchel_count_int := 0
	if has_satchel_count:
		var raw_satchel_count: Variant = record.get("satchel_count")
		if typeof(raw_satchel_count) != TYPE_INT:
			return {"ok": false}
		satchel_count_int = int(raw_satchel_count)
		if satchel_count_int < SATCHEL_MIN or satchel_count_int > SATCHEL_MAX:
			return {"ok": false}
	var gold_int := 0
	if has_gold:
		var raw_gold: Variant = record.get("gold")
		if typeof(raw_gold) != TYPE_INT:
			return {"ok": false}
		gold_int = int(raw_gold)
		if gold_int < 0:
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
		var has_lost: bool = hero.has("lost")
		var expected_hero_size: int = 3 if has_lost else 2
		if hero.size() != expected_hero_size or not hero.has("id") or not hero.has("fray"):
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
		var is_lost: bool = false
		if has_lost:
			var raw_lost: Variant = hero.get("lost")
			if typeof(raw_lost) != TYPE_BOOL:
				return {"ok": false}
			is_lost = bool(raw_lost)
		party.append({"id": hero_id, "fray": fray, "lost": is_lost})
	var parsed_snapshot := {"candle": candle, "party": party}
	if has_scraps:
		parsed_snapshot["scraps"] = scraps_int
	if has_satchel_count:
		parsed_snapshot["satchel_count"] = satchel_count_int
	if has_gold:
		parsed_snapshot["gold"] = gold_int
	return {"ok": true, "snapshot": parsed_snapshot}


## Strict opt-in outcome parse: a choice of exactly {id, text, stitched_effect}
## whose effect is
## {candle, fray, target[, required_hero][, scraps][, gold][, part][, hp][, require_full_candle]}
## for "party" or
## {candle, fray, target, hero_id[, required_hero][, scraps][, gold][, part][, hp][, require_full_candle]}
## for "hero", with signed integer candle, fray and optional scraps/gold/hp,
## canonical hero_id / optional required_hero, optional part
## {"id": String, "tier": native int 1..3} whose id resolves in the validated
## parts catalog, and optional require_full_candle (native bool true on a
## strictly negative native integer candle delta). Anything else is malformed
## and cannot settle.
func _parse_stitched_effect(choice: Variant, catalog_state: Dictionary) -> Dictionary:
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
	var has_scraps: bool = effect.has("scraps")
	var has_part: bool = effect.has("part")
	var has_gold: bool = effect.has("gold")
	var has_required_hero: bool = effect.has("required_hero")
	var has_hp: bool = effect.has("hp")
	var has_require_full_candle: bool = effect.has("require_full_candle")
	var has_min_fray: bool = effect.has("min_fray")
	var has_required_candle_band: bool = effect.has("required_candle_band")
	var optional_keys: int = (
		(1 if has_scraps else 0)
		+ (1 if has_part else 0)
		+ (1 if has_gold else 0)
		+ (1 if has_required_hero else 0)
		+ (1 if has_hp else 0)
		+ (1 if has_require_full_candle else 0)
		+ (1 if has_min_fray else 0)
		+ (1 if has_required_candle_band else 0)
	)
	var hero_id := ""
	if target == TARGET_PARTY:
		var expected_party_keys: int = 3 + optional_keys
		if effect.size() != expected_party_keys:
			return {"ok": false}
	else:
		var expected_hero_keys: int = 4 + optional_keys
		if effect.size() != expected_hero_keys or not effect.has("hero_id"):
			return {"ok": false}
		var raw_hero: Variant = effect.get("hero_id")
		if typeof(raw_hero) != TYPE_STRING or not _is_nonblank_string(raw_hero) or not CANONICAL_HERO_IDS.has(raw_hero):
			return {"ok": false}
		hero_id = raw_hero
	var required_hero := ""
	if has_required_hero:
		var raw_required_hero: Variant = effect.get("required_hero")
		if typeof(raw_required_hero) != TYPE_STRING or not _is_nonblank_string(raw_required_hero) or not CANONICAL_HERO_IDS.has(raw_required_hero):
			return {"ok": false}
		required_hero = raw_required_hero
	if not effect.has("candle") or not effect.has("fray"):
		return {"ok": false}
	var candle_read: Dictionary = _read_signed_int(effect.get("candle"))
	var fray_read: Dictionary = _read_signed_int(effect.get("fray"))
	if not candle_read.get("ok", false) or not fray_read.get("ok", false):
		return {"ok": false}
	var candle_delta: int = int(candle_read["value"])
	if has_require_full_candle:
		var raw_require_full_candle: Variant = effect.get("require_full_candle")
		if typeof(raw_require_full_candle) != TYPE_BOOL or not bool(raw_require_full_candle):
			return {"ok": false}
		if typeof(effect.get("candle")) != TYPE_INT or candle_delta >= 0:
			return {"ok": false}
	var required_candle_band := ""
	if has_required_candle_band:
		var raw_band: Variant = effect.get("required_candle_band")
		if typeof(raw_band) != TYPE_STRING:
			return {"ok": false}
		var band_name: String = raw_band
		if not CANDLE_BAND_NAMES.has(band_name):
			return {"ok": false}
		required_candle_band = band_name
	var parsed := {
		"ok": true,
		"candle": candle_delta,
		"fray": int(fray_read["value"]),
		"target": target,
		"hero_id": hero_id,
		"has_scraps": has_scraps,
		"has_part": has_part,
		"has_gold": has_gold,
		"has_required_hero": has_required_hero,
		"required_hero": required_hero,
		"has_hp": has_hp,
		"require_full_candle": has_require_full_candle,
		"has_min_fray": has_min_fray,
		"has_required_candle_band": has_required_candle_band,
		"required_candle_band": required_candle_band,
	}
	if has_scraps:
		var scraps_read: Dictionary = _read_signed_int(effect.get("scraps"))
		if not scraps_read.get("ok", false):
			return {"ok": false}
		parsed["scraps"] = int(scraps_read["value"])
	if has_part:
		var parsed_part: Dictionary = _parse_part_award(effect.get("part"), catalog_state)
		if not parsed_part.get("ok", false):
			return {"ok": false}
		parsed["part"] = parsed_part["part"]
	if has_gold:
		var gold_read: Dictionary = _read_signed_int(effect.get("gold"))
		if not gold_read.get("ok", false):
			return {"ok": false}
		parsed["gold"] = int(gold_read["value"])
	if has_hp:
		var hp_read: Dictionary = _read_signed_int(effect.get("hp"))
		if not hp_read.get("ok", false):
			return {"ok": false}
		parsed["hp"] = int(hp_read["value"])
	if has_min_fray:
		var raw_min_fray: Variant = effect.get("min_fray")
		if typeof(raw_min_fray) != TYPE_INT:
			return {"ok": false}
		var min_fray_val: int = int(raw_min_fray)
		if min_fray_val < MIN_FRAY_MIN or min_fray_val > MIN_FRAY_MAX:
			return {"ok": false}
		parsed["min_fray"] = min_fray_val
	return parsed


func _parse_part_award(raw_part: Variant, catalog_state: Dictionary) -> Dictionary:
	if typeof(raw_part) != TYPE_DICTIONARY:
		return {"ok": false}
	var part_record: Dictionary = raw_part
	if part_record.size() != 2 or not part_record.has("id") or not part_record.has("tier"):
		return {"ok": false}
	var raw_id: Variant = part_record.get("id")
	if not _is_nonblank_string(raw_id):
		return {"ok": false}
	var part_id: String = raw_id
	if part_id != part_id.strip_edges():
		return {"ok": false}
	var raw_tier: Variant = part_record.get("tier")
	if typeof(raw_tier) != TYPE_INT:
		return {"ok": false}
	var tier: int = int(raw_tier)
	if tier < PART_TIER_MIN or tier > PART_TIER_MAX:
		return {"ok": false}
	if not catalog_state.get("ok", false):
		return {"ok": false}
	var by_id: Dictionary = catalog_state.get("by_id", {})
	if not by_id.has(part_id):
		return {"ok": false}
	return {"ok": true, "part": {"id": part_id, "tier": tier}}


func _resolve_catalog(catalog: Variant) -> Dictionary:
	if catalog != null:
		return _parse_catalog(catalog)
	return _catalog


## Validates a caller-supplied parts catalog via StitchedParts.build_catalog
## without mutating the caller's dictionary or array.
func _parse_catalog(catalog: Variant) -> Dictionary:
	if typeof(catalog) == TYPE_ARRAY:
		var built_from_array: Dictionary = StitchedParts.build_catalog((catalog as Array).duplicate(true))
		if not bool(built_from_array.get("ok", false)):
			return {"ok": false, "by_id": {}}
		return {"ok": true, "by_id": built_from_array["by_id"]}
	if typeof(catalog) != TYPE_DICTIONARY:
		return {"ok": false, "by_id": {}}
	var record: Dictionary = catalog
	if record.is_empty():
		return {"ok": false, "by_id": {}}
	if record.has("ok"):
		if typeof(record.get("ok")) != TYPE_BOOL or not bool(record.get("ok")):
			return {"ok": false, "by_id": {}}
	if record.has("parts"):
		for key in record.keys():
			if not key in ["ok", "error", "parts", "by_id", "version", "note"]:
				return {"ok": false, "by_id": {}}
		var raw_parts: Variant = record.get("parts")
		if typeof(raw_parts) != TYPE_ARRAY:
			return {"ok": false, "by_id": {}}
		var built: Dictionary = StitchedParts.build_catalog((raw_parts as Array).duplicate(true))
		if not bool(built.get("ok", false)):
			return {"ok": false, "by_id": {}}
		var built_by_id: Dictionary = built["by_id"]
		if record.has("by_id"):
			if typeof(record.get("by_id")) != TYPE_DICTIONARY:
				return {"ok": false, "by_id": {}}
			var raw_by_id: Dictionary = record.get("by_id")
			if raw_by_id.size() != built_by_id.size():
				return {"ok": false, "by_id": {}}
			for part_id in built_by_id.keys():
				if not raw_by_id.has(part_id) or typeof(raw_by_id[part_id]) != TYPE_DICTIONARY:
					return {"ok": false, "by_id": {}}
				var check_entry: Dictionary = StitchedParts.validate_part(
					(raw_by_id[part_id] as Dictionary).duplicate(true)
				)
				if not bool(check_entry.get("ok", false)) or check_entry.get("part") != built_by_id[part_id]:
					return {"ok": false, "by_id": {}}
		return {"ok": true, "by_id": built_by_id}
	var entries: Array = []
	for key in record.keys():
		if typeof(key) != TYPE_STRING or typeof(record[key]) != TYPE_DICTIONARY:
			return {"ok": false, "by_id": {}}
		var entry_copy: Dictionary = (record[key] as Dictionary).duplicate(true)
		if entry_copy.get("id") != key:
			return {"ok": false, "by_id": {}}
		entries.append(entry_copy)
	var built_from_map: Dictionary = StitchedParts.build_catalog(entries)
	if not bool(built_from_map.get("ok", false)):
		return {"ok": false, "by_id": {}}
	return {"ok": true, "by_id": built_from_map["by_id"]}


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

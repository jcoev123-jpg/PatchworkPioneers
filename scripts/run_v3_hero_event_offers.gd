class_name RunV3HeroEventOffers
extends RefCounted
## Scene-free admission only; these events are not yet wired into live play.
## A service is an immutable party/catalog snapshot. Each entry creates a new
## visit; RunEventChoice owns that visit's wallet receipt and one-claim latch.

const CATALOG_PATH := "res://data/events/v3_hero_choice_events.json"
const HERO_IDS := ["warden", "seamstress", "tinker", "lantern_monk",
	"rag_duelist", "scarecrow", "yarn_ranger", "button_golem"]

var _eligible: Dictionary = {}
var _valid := false


## catalog_data can reorder/subset the authored catalog for deterministic fixtures;
## it cannot introduce or alter records. Invalid input rejects the whole catalog.
func _init(party_ids: Variant = null, catalog_data: Variant = null) -> void:
	if not party_ids is Array or party_ids.size() != 3:
		return
	var party := {}
	for hero in party_ids:
		if not hero is String or not HERO_IDS.has(hero) or party.has(hero):
			return
		party[hero] = true
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		return
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return
	var authored: Variant = parser.data
	if not authored is Dictionary or not authored.get("events") is Array:
		return
	var canonical := {}
	for record in authored["events"]:
		if not _valid_record(record) or canonical.has(record["id"]):
			return
		canonical[record["id"]] = record
	var source: Variant = authored if catalog_data == null else catalog_data
	if not source is Dictionary or not source.get("events") is Array:
		return
	if source["events"].is_empty():
		return
	var seen := {}
	var eligible := {}
	for record in source["events"]:
		if not _valid_record(record):
			return
		var event_id: String = record["id"]
		if seen.has(event_id) or not canonical.has(event_id) or record != canonical[event_id]:
			return
		seen[event_id] = true
		if party.has(record["required_hero"]):
			eligible[event_id] = record.duplicate(true)
	_eligible = eligible
	_valid = true


func is_valid() -> bool:
	return _valid


func get_offers() -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	for event_id in _eligible:
		offers.append(_eligible[event_id].duplicate(true))
	return offers


## Records (including altered returned offers), unknown and stale IDs cannot
## authorize entry. Null means admission failed; no visit or claim was made.
func enter(event_id: Variant) -> RunEventChoice:
	if not _valid or not event_id is String or not _eligible.has(event_id):
		return null
	return RunEventChoice.new(_eligible[event_id])


func _valid_record(record: Variant) -> bool:
	if not record is Dictionary:
		return false
	var selector := RunEventChoice.new(record)
	if not selector.is_valid():
		return false
	var hero: Variant = record.get("required_hero")
	if not hero is String or not HERO_IDS.has(hero):
		return false
	var hero_choices: Variant = record.get("hero_choice_ids")
	if not hero_choices is Array:
		return false
	var remaining := {}
	var has_leave := false
	for choice in record["choices"]:
		if choice["id"] == "leave":
			has_leave = true
		else:
			remaining[choice["id"]] = true
	if not has_leave or hero_choices.size() != remaining.size():
		return false
	for choice_id in hero_choices:
		if not choice_id is String or not remaining.has(choice_id):
			return false
		remaining.erase(choice_id)
	# Use the wallet authority's parser without claiming or requiring affordability.
	var preview := selector.preview_wallet_choices({"gold": 0, "scraps": 0})
	for choice in preview["choices"]:
		if choice["gold_delta"] == null or choice["scraps_delta"] == null:
			return false
	return remaining.is_empty()

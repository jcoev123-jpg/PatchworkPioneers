class_name StitchedPartyAdmission
extends RefCounted
## Scene-free, card-free S6 party receipt. No equipment is invented or loaded here.
## Returned dictionaries and arrays are fresh snapshots; callers must treat them as values.

const LEGACY_PATH := "res://data/heroes/starter_party.json"
const V3_PATH := "res://data/heroes/v3_party_roster.json"
const HERO_IDS := [
	"warden", "seamstress", "tinker", "lantern_monk",
	"rag_duelist", "scarecrow", "yarn_ranger", "button_golem",
]
const LEGACY_RANKS := {"warden": 1, "seamstress": 2, "tinker": 3}
const V3_IDS := ["lantern_monk", "rag_duelist", "scarecrow", "yarn_ranger", "button_golem"]
const RANK_COUNT := 4


## Optional roster/legacy sources are for validating negative authored-data fixtures.
## They must validate as a complete copy of the shipped roster, not redefine a hero.
static func admit(picks: Variant, sources: Variant = null) -> Dictionary:
	if not picks is Array or picks.size() != RANK_COUNT:
		return _failed()
	var seen := {}
	for id in picks:
		if not id is String or not id in HERO_IDS or seen.has(id):
			return _failed()
		seen[id] = true

	var canonical := _records(_read_json(LEGACY_PATH), _read_json(V3_PATH))
	if canonical.is_empty():
		return _failed()
	var records := canonical
	if sources != null:
		if not sources is Dictionary:
			return _failed()
		for key in sources:
			if not key is String or not key in ["legacy", "roster"]:
				return _failed()
		records = _records(
			sources.get("legacy", _read_json(LEGACY_PATH)),
			sources.get("roster", _read_json(V3_PATH))
		)
		if records.is_empty() or records != canonical:
			return _failed()

	var seated := {}
	var displaced: Array = []
	for id in picks:
		var preferred: int = records[id]["preferred"]
		if not seated.has(preferred):
			seated[preferred] = records[id]["hero"].duplicate(true)
		else:
			displaced.append(id)
	var displaced_index := 0
	for rank in range(1, RANK_COUNT + 1):
		if not seated.has(rank):
			if displaced_index >= displaced.size():
				return _failed()
			seated[rank] = records[displaced[displaced_index]]["hero"].duplicate(true)
			displaced_index += 1
	if displaced_index != displaced.size() or seated.size() != RANK_COUNT:
		return _failed()

	var heroes: Array = []
	var ordered_ids: Array = []
	for rank in range(1, RANK_COUNT + 1):
		var hero: Dictionary = seated[rank].duplicate(true)
		hero["rank"] = rank
		heroes.append(hero)
		ordered_ids.append(hero["id"])
	return {"ok": true, "heroes": heroes, "hero_ids": ordered_ids}


static func _failed() -> Dictionary:
	return {"ok": false, "heroes": [], "hero_ids": []}


## Check every authored entry, not just the selected four. Legacy ranks are
## invariant; extra V3 heroes take their authored default positions.
static func _records(legacy: Variant, roster: Variant) -> Dictionary:
	if not legacy is Array or not roster is Array:
		return {}
	var records := {}
	for raw in legacy:
		if not raw is Dictionary or not _valid_identity(raw):
			return {}
		var id: String = raw["id"]
		if not LEGACY_RANKS.has(id) or records.has(id):
			return {}
		if not raw.has("art_path") or not raw["art_path"] is String:
			return {}
		records[id] = {
			"preferred": LEGACY_RANKS[id],
			"hero": _identity(raw),
		}
	for raw in roster:
		if not raw is Dictionary or not _valid_identity(raw):
			return {}
		var id: String = raw["id"]
		if not id in V3_IDS or records.has(id):
			return {}
		var position: Variant = _whole(raw.get("default_position"))
		if position == null or position < 1 or position > RANK_COUNT:
			return {}
		if not raw.get("art_path") is String or not raw.get("starter_cards") is String \
			or str(raw["starter_cards"]).strip_edges().is_empty() or not raw.get("passive") is Dictionary:
			return {}
		records[id] = {
			"preferred": int(position),
			"hero": _identity(raw),
		}
	for id in HERO_IDS:
		if not records.has(id):
			return {}
	return records


static func _valid_identity(raw: Dictionary) -> bool:
	if not raw.get("id") is String or not raw.get("name") is String:
		return false
	if str(raw["id"]).strip_edges().is_empty() or str(raw["name"]).strip_edges().is_empty():
		return false
	var hp: Variant = _whole(raw.get("max_hp"))
	return hp != null and hp > 0


static func _identity(raw: Dictionary) -> Dictionary:
	return {
		"id": raw["id"],
		"name": raw["name"],
		"max_hp": int(_whole(raw["max_hp"])),
	}


static func _whole(value: Variant) -> Variant:
	if value is int:
		return value
	if value is float and is_finite(value) and floor(value) == value \
		and absf(value) < 9223372036854775808.0:
		return int(value)
	return null


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return parser.data

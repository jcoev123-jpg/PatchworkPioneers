class_name RunV3PartyAdmission
extends RefCounted
## Scene-free admission of any three of the eight authored V3 heroes. Not yet wired
## into live play: the party picker only requests IDs, and a later task owns mounting.
## A receipt is a detached snapshot built from the shipped hero records and each
## owner's starter catalog: three CombatParty definitions in default-position order
## (stable pick order on ties) plus exactly four authentic base starter occurrences
## per hero. No RNG, scene or catalog state is touched; any defect rejects the whole
## request with an empty receipt.

const V3_ROSTER_PATH := "res://data/heroes/v3_party_roster.json"
const LEGACY_PARTY_PATH := "res://data/heroes/starter_party.json"
const HERO_IDS := ["warden", "seamstress", "tinker", "lantern_monk",
	"rag_duelist", "scarecrow", "yarn_ranger", "button_golem"]
const LEGACY_IDS := ["warden", "seamstress", "tinker"]
const STARTERS_PER_HERO := 4
## Each V3 hero's starter catalog; the authored record must name this exact path.
const V3_CATALOGS := {
	"lantern_monk": "res://data/cards/lantern_monk_starter_cards.gd",
	"rag_duelist": "res://data/cards/rag_duelist_starter_cards.gd",
	"scarecrow": "res://data/cards/scarecrow_starter_cards.gd",
	"yarn_ranger": "res://data/cards/yarn_ranger_starter_cards.gd",
	"button_golem": "res://data/cards/button_golem_starter_cards.gd",
}
const V3_FIELDS := ["id", "name", "max_hp", "default_position", "starter_cards", "art_path", "passive"]
const LEGACY_FIELDS := ["id", "name", "max_hp", "art_path"]
const PASSIVE_FIELDS := ["id", "text", "trigger", "effects"]
const FIXTURE_KEYS := ["roster", "legacy", "catalogs"]


## hero_ids is the picker's request. fixture may supply "roster"/"legacy" record
## arrays and "catalogs" ({hero_id: catalog object}) to prove rejection paths; every
## supplied record or card must still equal its shipped canonical counterpart.
static func admit(hero_ids: Variant, fixture: Variant = null) -> Dictionary:
	var picks := _picks(hero_ids)
	if picks.is_empty():
		return _rejected()
	if fixture != null:
		if not fixture is Dictionary:
			return _rejected()
		for key in fixture:
			if not key in FIXTURE_KEYS:
				return _rejected()
	var sources: Dictionary = {} if fixture == null else fixture
	var canonical := _canonical_records()
	if canonical.is_empty():
		return _rejected()
	var records := canonical
	if sources.has("roster") or sources.has("legacy"):
		records = _fixture_records(sources, canonical)
		if records.is_empty():
			return _rejected()
	var catalogs: Variant = sources.get("catalogs", {})
	if not catalogs is Dictionary:
		return _rejected()
	var chosen: Array[Dictionary] = []
	for index in range(picks.size()):
		var id: String = picks[index]
		if not records.has(id):
			return _rejected()
		chosen.append({"id": id, "pick": index, "record": records[id]})
	chosen.sort_custom(func(a, b): return a.record.position < b.record.position \
		or (a.record.position == b.record.position and a.pick < b.pick))
	var order: Array[String] = []
	var party: Array[Dictionary] = []
	var deck: Array[String] = []
	for entry in chosen:
		var starters := _starters(entry.id, catalogs.get(entry.id))
		if starters.is_empty():
			return _rejected()
		order.append(entry.id)
		party.append(entry.record.definition.duplicate(true))
		deck.append_array(starters)
	if not CombatParty.new(party).is_valid():
		return _rejected()
	return {"ok": true, "hero_ids": order, "party": party, "deck": deck}


static func _rejected() -> Dictionary:
	return {"ok": false, "hero_ids": [], "party": [], "deck": []}


static func _picks(hero_ids: Variant) -> Array[String]:
	var picks: Array[String] = []
	if not hero_ids is Array or hero_ids.size() != CombatParty.PARTY_SIZE:
		return picks
	for id in hero_ids:
		if not id is String or not id in HERO_IDS or id in picks:
			return [] as Array[String]
		picks.append(id)
	return picks


## {hero_id: {"position": int, "definition": Dictionary}} for all eight heroes, or {}.
static func _canonical_records() -> Dictionary:
	var v3: Variant = _read_json(V3_ROSTER_PATH)
	var legacy: Variant = _read_json(LEGACY_PARTY_PATH)
	return _validated_records(v3, legacy)


static func _fixture_records(sources: Dictionary, canonical: Dictionary) -> Dictionary:
	var v3: Variant = sources.get("roster", _read_json(V3_ROSTER_PATH))
	var legacy: Variant = sources.get("legacy", _read_json(LEGACY_PARTY_PATH))
	var records := _validated_records(v3, legacy)
	for id in records:
		if records[id] != canonical.get(id):
			return {}
	return records


static func _validated_records(v3: Variant, legacy: Variant) -> Dictionary:
	if not v3 is Array or not legacy is Array:
		return {}
	var records := {}
	# Legacy starter_party.json fixes positions 1-3 by array order, as CombatParty does.
	if legacy.size() != LEGACY_IDS.size():
		return {}
	for index in range(legacy.size()):
		var definition := _definition(legacy[index], LEGACY_FIELDS)
		if definition.is_empty() or definition.id != LEGACY_IDS[index]:
			return {}
		records[definition.id] = {"position": index + 1, "definition": definition}
	for raw in v3:
		var definition := _definition(raw, V3_FIELDS)
		if definition.is_empty() or not V3_CATALOGS.has(definition.id) or records.has(definition.id) \
			or definition.starter_cards != V3_CATALOGS[definition.id] \
			or not _valid_passive(definition.passive):
			return {}
		var position: Variant = _whole(definition.default_position)
		if position == null or position < 1 or position > CombatParty.PARTY_SIZE:
			return {}
		definition.default_position = position
		records[definition.id] = {"position": position, "definition": definition}
	for id in HERO_IDS:
		if not records.has(id):
			return {}
	return records


## Exact field set, nonempty String id/name, positive whole max_hp converted to int.
static func _definition(raw: Variant, fields: Array) -> Dictionary:
	if not raw is Dictionary or raw.size() != fields.size():
		return {}
	for field in fields:
		if not raw.has(field):
			return {}
	if not raw.id is String or raw.id.is_empty() or not raw.name is String or raw.name.is_empty() \
		or not raw.art_path is String:
		return {}
	var max_hp: Variant = _whole(raw.max_hp)
	if max_hp == null or max_hp <= 0:
		return {}
	var definition: Dictionary = raw.duplicate(true)
	definition.max_hp = max_hp
	return definition


## JSON numbers decode as floats; accept only finite whole values in int range.
static func _whole(value: Variant) -> Variant:
	if value is int:
		return value
	if not value is float or not is_finite(value) or floor(value) != value \
		or absf(value) >= float(CombatParty.MAX_INT):
		return null
	return int(value)


static func _valid_passive(passive: Variant) -> bool:
	if not passive is Dictionary or passive.size() != PASSIVE_FIELDS.size():
		return false
	for field in PASSIVE_FIELDS:
		if not passive.has(field):
			return false
	return passive.id is String and not passive.id.is_empty() and passive.text is String \
		and not passive.text.is_empty() and passive.trigger is String and not passive.trigger.is_empty() \
		and passive.effects is Dictionary and not passive.effects.is_empty()


## Exactly four base starter occurrences owned by hero_id, each identical to the
## shipped catalog's record. A fixture catalog may only reproduce the shipped one.
static func _starters(hero_id: String, override: Variant) -> Array[String]:
	var shipped: Object = _shipped_catalog(hero_id)
	if shipped == null:
		return []
	var catalog: Variant = shipped if override == null else override
	if not catalog is Object or not catalog.has_method("get_starting_deck") \
		or not catalog.has_method("get_definition"):
		return []
	var source: Variant = catalog.get_starting_deck()
	var shipped_deck: Array = shipped.get_starting_deck()
	if not source is Array:
		return []
	var starters: Array[String] = []
	var counts := {}
	for card in source:
		if not card is String:
			return []
		var definition: Variant = catalog.get_definition(card)
		if hero_id in LEGACY_IDS and definition is Dictionary and definition.get("owner") != hero_id:
			continue
		if not definition is Dictionary or definition.is_empty() or definition != shipped.get_definition(card) \
			or definition.get("owner") != hero_id or definition.get("id") != card \
			or definition.has("upgrade_of") or card.ends_with("_plus"):
			return []
		var copies: Variant = definition.get("starting_copies")
		if not copies is int or copies <= 0:
			return []
		counts[card] = counts.get(card, 0) + 1
		if counts[card] > copies:
			return []
		starters.append(card)
	for card in counts:
		if counts[card] != shipped.get_definition(card).starting_copies:
			return []
	var expected: Array[String] = []
	for card in shipped_deck:
		if shipped.get_definition(card).get("owner") == hero_id:
			expected.append(card)
	if starters.size() != STARTERS_PER_HERO or starters != expected:
		return []
	return starters


static func _shipped_catalog(hero_id: String) -> Object:
	if hero_id == "seamstress":
		return V3SeamstressStarterCards.new()
	if hero_id in LEGACY_IDS:
		return StarterCards.new()
	var script: Variant = load(V3_CATALOGS[hero_id])
	if not script is GDScript:
		return null
	return script.new()


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return parser.data

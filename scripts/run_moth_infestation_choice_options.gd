class_name RunMothInfestationChoiceOptions
extends RefCounted
## Pure, detached Moth Infestation menu projection. Only valid, unclaimed
## RunMothInfestationOutcome ledgers should call this builder.
## No claim, wallet edit, card edit or RNG usage.

const EVENT_PATH := "res://data/events/moth_infestation.json"
const EVENT_ID := "moth_infestation"


static func build(deck: Array[String], descriptors: Dictionary, scraps: int,
		max_scraps: int, sacrifice_gain: int, fumigate_cost: int) -> Dictionary:
	var unavailable := {"ok": false, "event_id": "", "choices": [], "sacrifice_cards": []}
	var file := FileAccess.open(EVENT_PATH, FileAccess.READ)
	if file == null:
		return unavailable
	var event: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(event) != TYPE_DICTIONARY or event.get("id") != EVENT_ID:
		return unavailable
	var authored: Variant = event.get("choices")
	if typeof(authored) != TYPE_ARRAY:
		return unavailable

	# Enumerate original indices, never collapse repeated IDs into one target.
	var sacrifice_cards: Array[Dictionary] = []
	for index in range(deck.size()):
		var id: String = deck[index]
		if descriptors.has(id):
			continue
		var definition: Dictionary = RunRestStitchCards.resolve_card_definition(id)
		if definition.is_empty():
			continue
		sacrifice_cards.append({
			"index": index,
			"card_id": id,
			"owner": str(definition["owner"]),
			"display_name": str(definition["display_name"]),
		})

	var choices: Array[Dictionary] = []
	for record in authored:
		if typeof(record) != TYPE_DICTIONARY:
			return unavailable
		var outcome: Variant = record.get("outcome")
		if typeof(outcome) != TYPE_DICTIONARY:
			return unavailable
		var raw_scraps: Variant = outcome.get("scraps")
		var raw_gold: Variant = outcome.get("gold")
		# JSON.parse_string represents authored whole numbers as float.
		if typeof(raw_scraps) != TYPE_INT and typeof(raw_scraps) != TYPE_FLOAT:
			return unavailable
		if typeof(raw_gold) != TYPE_INT and typeof(raw_gold) != TYPE_FLOAT:
			return unavailable
		if raw_gold != 0 or raw_scraps != int(raw_scraps):
			return unavailable
		if typeof(record.get("id")) != TYPE_STRING or typeof(record.get("text")) != TYPE_STRING:
			return unavailable
		var id: String = record["id"]
		var delta: int = int(raw_scraps)
		var available := false
		match id:
			"sacrifice_card":
				available = delta == sacrifice_gain and not sacrifice_cards.is_empty() \
					and scraps <= max_scraps - sacrifice_gain
			"fumigate":
				available = delta == -fumigate_cost and scraps >= fumigate_cost
			"escape":
				available = delta == 0
		choices.append({
			"id": id,
			"text": record["text"],
			"scraps_delta": delta,
			"available": available,
		})
	return {
		"ok": true,
		"event_id": EVENT_ID,
		"choices": choices,
		"sacrifice_cards": sacrifice_cards,
	}

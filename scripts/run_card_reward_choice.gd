class_name RunCardRewardChoice
extends RefCounted
## One-time post-fight three-card reward choice service.
## Each instance represents a single offering; once claimed (chosen or skipped)
## it rejects all further actions. No scene dependencies; no RNG consumption.

var _offered_cards: Array = []
var _party_ids: Array[String] = []
var _claimed: bool = false


func _init(offered_cards: Array = [], party_ids: Array[String] = []) -> void:
	# Deep-copy inputs to prevent caller mutation.
	_offered_cards = []
	for item in offered_cards:
		if item is Dictionary:
			_offered_cards.append({
				"id": item.get("id", ""),
				"owner": item.get("owner", "")
			})
		else:
			_offered_cards.append({})
	_party_ids = party_ids.duplicate()


## Returns true when this instance represents a valid three-card offering.
func is_valid() -> bool:
	if _claimed:
		return false
	# Must have exactly three offers.
	if _offered_cards.size() != 3:
		return false
	# Party must have exactly three distinct hero IDs.
	if _party_ids.size() != 3:
		return false
	var party_set := {}
	for pid in _party_ids:
		if not pid is String or pid.is_empty():
			return false
		party_set[pid] = true
	if party_set.size() != 3:
		return false
	# Each offer must have non-empty String id and owner.
	var offered_ids := {}
	for offer in _offered_cards:
		var card_id_raw = offer.get("id", "")
		var owner_raw = offer.get("owner", "")
		if not card_id_raw is String or card_id_raw.is_empty():
			return false
		if not owner_raw is String or owner_raw.is_empty():
			return false
		var card_id: String = card_id_raw
		var owner: String = owner_raw
		if not card_id is String or card_id.is_empty():
			return false
		if not owner is String or owner.is_empty():
			return false
		if not party_set.has(owner):
			return false
		if offered_ids.has(card_id):
			return false
		offered_ids[card_id] = true
	if offered_ids.size() != 3:
		return false
	return true


## Returns the claim status.
func is_claimed() -> bool:
	return _claimed


## Attempts a claim on this offering.
## selected_id is the chosen card ID, or an empty string to skip.
func claim(deck_ids: Array[String] = [], selected_id: String = "") -> Dictionary:
	# Deep-copy input deck regardless of outcome.
	var result_deck: Array[String] = []
	for d in deck_ids:
		result_deck.append(String(d) if d is String else "")

	if _claimed:
		return {"ok": false, "skipped": false, "selected_id": "", "deck": result_deck.duplicate()}

	# Validate the offering first.
	if not is_valid():
		return {"ok": false, "skipped": false, "selected_id": "", "deck": result_deck.duplicate()}

	# Check selected_id validity.
	if selected_id != "":
		if not selected_id is String or selected_id.is_empty():
			return {"ok": false, "skipped": false, "selected_id": "", "deck": result_deck.duplicate()}
		# Must exist among the three distinct offers.
		var found := false
		for offer in _offered_cards:
			if offer.get("id", "") == selected_id:
				found = true
				break
		if not found:
			return {"ok": false, "skipped": false, "selected_id": "", "deck": result_deck.duplicate()}

	# Consume the claim.
	_claimed = true

	if selected_id == "":
		# Skip: return unchanged deck copy.
		return {
			"ok": true,
			"skipped": true,
			"selected_id": "",
			"deck": result_deck.duplicate()
		}

	# Choose: append selected card to a fresh copy of the deck.
	var chosen_deck := result_deck.duplicate()
	chosen_deck.append(selected_id)
	return {
		"ok": true,
		"skipped": false,
		"selected_id": selected_id,
		"deck": chosen_deck
	}

## Select authored rewards using the caller's seeded run RNG and eligible pool.
## Failure produces an invalid, unclaimable choice without touching the deck.
static func from_seeded_pool(rng: Variant, party_ids: Variant, candidate_ids: Variant) -> RunCardRewardChoice:
	var generated: Dictionary = RunCardRewardOffers.generate(rng, party_ids, candidate_ids)
	if not generated.get("ok", false):
		return RunCardRewardChoice.new()
	var copied_party: Array[String] = []
	for party_id in party_ids:
		copied_party.append(party_id)
	return RunCardRewardChoice.new(generated["offers"], copied_party)


## A fresh deep copy of the offered IDs/owners, never internal mutable state.
func get_offers() -> Array:
	return _offered_cards.duplicate(true)

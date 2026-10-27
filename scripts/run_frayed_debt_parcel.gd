class_name RunFrayedDebtParcel
extends RefCounted
## Independent P11 choice transaction; not mounted on the run route yet.
## context uses the Rest ledger keys plus authoritative selected party_ids and
## visited. The owner must pass its CURRENT exact source snapshot at choice and
## atomically commit the detached receipt. No caller containers are mutated.
## Preparation alone publishes two draws to the run RNG; choices use no RNG.

const EVENT_PATH := "res://data/events/mpw_frayed_debt.json"
const SAFE_EXIT := "safe_exit"
const MAX_INT := 9223372036854775807

var _valid := false
var _consumed := false
var _source: Dictionary = {}
var _current: Dictionary = {}
var _offers: Array[Dictionary] = []


func is_valid() -> bool:
	return _valid


func is_consumed() -> bool:
	return _consumed


func get_source_snapshot() -> Dictionary:
	return _source.duplicate(true)


func get_offers() -> Array[Dictionary]:
	return _offers.duplicate(true)


## A failed preparation may be retried. Successful preparation caches offers and
## cannot be rerolled on this service. An optional catalog must authenticate in
## full, including records that will not enter the selected party's offer pool.
func prepare(context: Variant, run_rng: Variant, candidates: Variant = null) -> Dictionary:
	if _valid or not run_rng is RandomNumberGenerator or not context is Dictionary:
		return _result(false)
	var event := load_authored_event()
	if event.is_empty() or not _valid_event(event):
		return _result(false)
	var party: Variant = context.get("party_ids")
	if not RunV3PartyAdmission.admit(party).get("ok", false):
		return _result(false)
	if typeof(context.get("visited")) != TYPE_BOOL or context.visited:
		return _result(false)
	var ledger := RunRestStitchCards.new(context.get("deck"), context.get("descriptors"),
		context.get("remaining_scraps"), context.get("next_stitch_id"))
	if not ledger.is_valid():
		return _result(false)
	var snapshot := ledger.get_snapshot()
	for id in snapshot.deck:
		if snapshot.descriptors.has(id):
			for owner in snapshot.descriptors[id].owners:
				if not party.has(owner):
					return _result(false)
		elif not party.has(RunRestStitchCards.resolve_card_definition(id).get("owner")):
			return _result(false)
	var authored := RunPoolCardRewardOffers.get_authored_base_candidates()
	var canonical := {}
	for record in authored:
		canonical[record.id] = record
	var catalog: Variant = authored if candidates == null else candidates
	if not catalog is Array:
		return _result(false)
	var seen := {}
	var eligible: Array[String] = []
	for record in catalog:
		if not record is Dictionary or typeof(record.get("id")) != TYPE_STRING:
			return _result(false)
		var id: String = record.id
		if seen.has(id) or not canonical.has(id) or not _same_snapshot(record, canonical[id]):
			return _result(false)
		seen[id] = true
		var definition := RunPoolCardRewardOffers.resolve_reward_definition(id)
		if definition.is_empty() or definition.get("id") != id \
				or definition.get("owner") != record.owner or definition.get("rarity") != record.rarity \
				or definition.get("reward_eligible") == false or definition.get("is_upgrade") == true \
				or definition.has("upgrade_of") or id.ends_with("_plus"):
			return _result(false)
		if record.rarity == event.rarity and party.has(record.owner):
			eligible.append(id)
	if eligible.size() < int(event.offer_count):
		return _result(false)
	eligible.sort()
	var trial := RandomNumberGenerator.new()
	trial.seed = run_rng.seed
	trial.state = run_rng.state
	var offers: Array[Dictionary] = []
	for index in range(int(event.offer_count)):
		var pick := trial.randi_range(0, eligible.size() - 1)
		offers.append(RunPoolCardRewardOffers.resolve_reward_definition(eligible[pick]))
		eligible.remove_at(pick)
	snapshot["party_ids"] = party.duplicate()
	snapshot["visited"] = false
	_source = snapshot.duplicate(true)
	_current = snapshot.duplicate(true)
	_offers = offers.duplicate(true)
	_valid = true
	run_rng.state = trial.state
	return _result(true)


## choice is an offered base card ID or SAFE_EXIT, never a client definition.
func choose(choice: Variant, expected_snapshot: Variant) -> Dictionary:
	if not _valid or _consumed or typeof(choice) != TYPE_STRING \
			or not _same_snapshot(expected_snapshot, _source):
		return _result(false)
	var next := _source.duplicate(true)
	if choice == SAFE_EXIT:
		if next.remaining_scraps > MAX_INT - 1:
			return _result(false)
		next.remaining_scraps += 1
	else:
		var offered := false
		for definition in _offers:
			if definition.id == choice:
				offered = true
		if not offered:
			return _result(false)
		next.deck.append(choice)
		next.deck.append(MpwFrayedDebt.CARD_ID)
	next.visited = true
	# The receipt authenticates the whole proposed transaction, including offers.
	next.receipt = JSON.stringify([_source.receipt, choice, next, _offers]).sha256_text()
	_current = next
	_consumed = true
	return _result(true)


func _result(ok: bool) -> Dictionary:
	var result := _current.duplicate(true)
	result["ok"] = ok
	result["consumed"] = _consumed
	result["offers"] = get_offers()
	result["source_snapshot"] = get_source_snapshot()
	return result


static func _same_snapshot(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not _same_snapshot(a[key], b[key]):
				return false
		return true
	if a is Array:
		if a.size() != b.size():
			return false
		for i in range(a.size()):
			if not _same_snapshot(a[i], b[i]):
				return false
		return true
	return a == b


static func load_authored_event() -> Dictionary:
	var file := FileAccess.open(EVENT_PATH, FileAccess.READ)
	if file == null:
		return {}
	var record: Variant = JSON.parse_string(file.get_as_text())
	return record if record is Dictionary else {}


static func _valid_event(record: Dictionary) -> bool:
	if record.get("id") != "frayed_debt_parcel" or record.get("curse_id") != MpwFrayedDebt.CARD_ID \
			or record.get("rarity") != "uncommon" or record.get("once_per_run") != true:
		return false
	for key in ["offer_count", "exit_scraps", "visit_weight"]:
		var value: Variant = record.get(key)
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
			return false
		if value != (2 if key == "offer_count" else 1):
			return false
	for key in ["title", "description", "illustration_path"]:
		if typeof(record.get(key)) != TYPE_STRING or record[key].is_empty():
			return false
	var choices: Variant = record.get("choices")
	if not choices is Array or choices.size() != 3:
		return false
	for i in range(3):
		if not choices[i] is Dictionary or choices[i].get("id") != ["offer_0", "offer_1", SAFE_EXIT][i] \
				or typeof(choices[i].get("text")) != TYPE_STRING or choices[i].text.is_empty():
			return false
	return true

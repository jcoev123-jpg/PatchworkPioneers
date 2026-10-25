class_name RunHeroPathLoadout
extends RefCounted
## Scene-free, one-claim proposal for the current three-hero Path starting loadout.
## Does not install cards, passives, or consume the caller's run RNG.

const HERO_ORDER: Array[String] = ["warden", "seamstress", "tinker"]
const PATH_IDS := {
	"warden": ["bulwark", "vanguard"],
	"seamstress": ["bloodline", "unpicker"],
	"tinker": ["sharpshot", "clockwork"],
}
const BASE_SIZE := 12

var _claimed := false
var _receipt: Dictionary = {}


func is_claimed() -> bool:
	return _claimed


func get_receipt() -> Dictionary:
	return _receipt.duplicate(true)


## selections must contain exactly one authored String Path ID for each hero.
## Returns {ok, deck: Array[String], paths: Dictionary} on success. Each path
## contains the selected path_id, display_name, replacement passive and card;
## Tinker's authored passive_id is also included. Rejection returns {ok: false}.
## The optional RNG is accepted for run callers but never read or advanced.
func choose(selections: Variant, _rng: RandomNumberGenerator = null) -> Dictionary:
	if _claimed or not _valid_selections(selections):
		return {"ok": false}
	var selected: Dictionary = selections
	var base_source: Variant = RunWardenPathChoice.load_authored_starter_deck()
	if not base_source is Array or (base_source as Array).size() != BASE_SIZE:
		return {"ok": false}
	var base: Array[String] = []
	for id in base_source:
		if not id is String:
			return {"ok": false}
		base.append(id)

	# Each chooser sees the same twelve-card base, never another hero's
	# thirteen-card proposal. Fresh instances keep a failed attempt unclaimed.
	var warden := RunWardenPathChoice.new(null, base)
	var seamstress := RunSeamstressPathChoice.new(null, base)
	var tinker := RunTinkerPathChoice.new()
	if not warden.is_valid() or not seamstress.is_valid():
		return {"ok": false}
	var tinker_offer: Dictionary = tinker.get_definition(selected["tinker"])
	if tinker_offer.is_empty():
		return {"ok": false}

	var warden_choice: Dictionary = warden.choose(selected["warden"])
	var seamstress_choice: Dictionary = seamstress.choose(selected["seamstress"], base)
	var tinker_choice: Dictionary = tinker.choose(selected["tinker"], base)
	if not warden_choice.get("ok", false) or not seamstress_choice.get("ok", false) \
			or not tinker_choice.get("ok", false):
		return {"ok": false}
	if not _same_base_plus_card(warden_choice.get("starter_deck"), base,
			warden_choice.get("card", {}).get("id")) \
			or not _same_base_plus_card(seamstress_choice.get("deck"), base,
			seamstress_choice.get("card", {}).get("id")) \
			or not _same_base_plus_card(tinker_choice.get("deck"), base,
			tinker_choice.get("card_id")):
		return {"ok": false}
	if tinker_choice.get("passive_id") != tinker_offer.get("passive_id") \
			or tinker_choice.get("card_id") != tinker_offer.get("card", {}).get("id"):
		return {"ok": false}

	var deck: Array[String] = base.duplicate()
	deck.append(warden_choice["card"]["id"])
	deck.append(seamstress_choice["card"]["id"])
	deck.append(tinker_choice["card_id"])
	var paths := {
		"warden": _record(warden_choice),
		"seamstress": _record(seamstress_choice),
		"tinker": {
			"path_id": tinker_choice["path_id"],
			"display_name": tinker_offer["display_name"],
			"passive_id": tinker_choice["passive_id"],
			"passive": (tinker_offer["passive"] as Dictionary).duplicate(true),
			"card": (tinker_offer["card"] as Dictionary).duplicate(true),
		},
	}
	_receipt = {"ok": true, "deck": deck, "paths": paths}
	_claimed = true
	return get_receipt()


func _valid_selections(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var entries: Dictionary = value
	if entries.size() != HERO_ORDER.size():
		return false
	for hero in HERO_ORDER:
		if not entries.has(hero) or not entries[hero] is String:
			return false
		if not PATH_IDS[hero].has(entries[hero]):
			return false
	return true


func _same_base_plus_card(value: Variant, base: Array[String], card_id: Variant) -> bool:
	if not value is Array or not card_id is String:
		return false
	var ids: Array = value
	if ids.size() != base.size() + 1:
		return false
	for index in base.size():
		if ids[index] != base[index]:
			return false
	return ids[base.size()] == card_id


func _record(choice: Dictionary) -> Dictionary:
	return {
		"path_id": choice["path_id"],
		"display_name": choice["display_name"],
		"passive": (choice["passive"] as Dictionary).duplicate(true),
		"card": (choice["card"] as Dictionary).duplicate(true),
	}


## Authenticate a detached three-hero claim by recreating the complete authored
## selection. Never accept a card ID, passive, owner or deck supplied on its own.
static func authenticate_receipt(candidate: Variant) -> Dictionary:
	if typeof(candidate) != TYPE_DICTIONARY:
		return {"ok": false}
	var receipt: Dictionary = candidate
	var proposed_paths: Variant = receipt.get("paths")
	if typeof(proposed_paths) != TYPE_DICTIONARY:
		return {"ok": false}
	var paths: Dictionary = proposed_paths
	if paths.size() != HERO_ORDER.size():
		return {"ok": false}
	var selections: Dictionary = {}
	for hero in HERO_ORDER:
		if typeof(paths.get(hero)) != TYPE_DICTIONARY:
			return {"ok": false}
		selections[hero] = paths[hero].get("path_id")
	if not RunHeroPathLoadout.new()._valid_selections(selections):
		return {"ok": false}
	var fresh := RunHeroPathLoadout.new()
	var canonical := fresh.choose(selections)
	if not canonical.get("ok", false) or not _exactly_equal(receipt, canonical):
		return {"ok": false}
	var card_ids: Array[String] = []
	for hero in HERO_ORDER:
		card_ids.append(canonical["paths"][hero]["card"]["id"])
	return {"ok": true, "card_ids": card_ids, "receipt": canonical.duplicate(true)}


static func _exactly_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Array:
		var left: Array = a
		var right: Array = b
		if left.size() != right.size():
			return false
		for index in left.size():
			if not _exactly_equal(left[index], right[index]):
				return false
		return true
	if a is Dictionary:
		var left: Dictionary = a
		var right: Dictionary = b
		if left.size() != right.size():
			return false
		for key in left:
			if not right.has(key) or not _exactly_equal(left[key], right[key]):
				return false
		return true
	return a == b

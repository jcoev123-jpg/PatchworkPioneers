class_name StitchedRunSave
extends RefCounted
## Safe Variant bytes preserve 64-bit RNG state. Objects are never deserialized.
## Replay into a detached candidate makes every rejection atomic for the caller.

const MAX_COMMANDS := 20000
const MAX_BYTES := 16000000
const STAGED_SUFFIX := ".tmp"


static func capture(session: StitchedRunSession) -> Dictionary:
	if session == null or not session.is_consistent() or session.journal.size() > MAX_COMMANDS:
		return {}
	var document := {"version": StitchedRunSession.VERSION, "seed": session.seed_value,
		"picks": session.picks.duplicate(), "initial": session._initial.duplicate(true),
		"journal": session.journal.duplicate(true), "state": session.snapshot()}
	document["digest"] = _digest(document)
	return document


static func _digest(document: Dictionary) -> String:
	var payload := [document.version, document.seed, document.picks, document.initial, document.journal, document.state]
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(var_to_bytes(payload))
	return digest.finish().hex_encode()


static func restore(document: Variant) -> StitchedRunSession:
	if not document is Dictionary or document.size() != 7:
		return null
	if not document.get("version") is int or document.version != StitchedRunSession.VERSION or not document.get("seed") is int \
		or not document.get("picks") is Array or not document.get("initial") is Dictionary \
		or not document.get("journal") is Array or not document.get("state") is Dictionary \
		or document.journal.size() > MAX_COMMANDS or not document.get("digest") is String:
		return null
	if _digest(document) != document.digest:
		return null
	var legacy_s14: bool = not document.state.has("s14")
	if not legacy_s14 and (not document.state.s14 is Dictionary or not document.state.s14.get("enabled") is bool):
		return null
	var candidate := StitchedRunSession.start(document.seed, document.picks, document.initial,
		false if legacy_s14 else bool(document.state.s14.enabled))
	if candidate == null:
		return null
	# Pre-S8f saves have no Walk block and never walked.
	var legacy_walk: bool = not document.state.has("walk")
	if not legacy_walk:
		var walk_state: Variant = document.state.walk
		if not walk_state is Dictionary or not walk_state.get("enabled") is bool:
			return null
		if walk_state.enabled and not candidate.enable_walks():
			return null
	# Pre-S12 saves carry no gifts: they keep the four basic hands and are never offered more.
	var legacy_gifts: bool = not document.state.has("gifts")
	if legacy_gifts:
		candidate.gift_pool = []
		candidate._seal()
	else:
		var gift_state: Variant = document.state.gifts
		if not gift_state is Dictionary or not gift_state.get("pool") is Array \
				or not candidate.set_gift_pool(gift_state.pool):
			return null
	var legacy_pockets: bool = not document.state.has("pockets")
	var legacy_fear: bool = not document.state.has("kid_fear")
	# Pre-S9a saves have no battle "hand" block and so no hand actions to replay.
	var legacy_hand: bool = document.state.get("battle") is Dictionary and not document.state.battle.is_empty() \
		and not document.state.battle.has("hand")
	for command in document.journal:
		# Pre-pocket saves can replay their old actions, never a new purchase
		# hidden by omitting its ownership ledger from the saved state.
		if legacy_pockets and command is Dictionary and command.get("action") == "visit" \
				and command.get("id") in ["buy_pins", "buy_thimble_tonic", "buy_fresh_stuffing", "buy_dye",
				"buy_starch", "buy_spare_spool"]:
			return null
		if legacy_hand and command is Dictionary and command.get("method") == "use_hand_action":
			return null
		if not _replay(candidate, command):
			return null
	var replayed := candidate.snapshot()
	if legacy_walk:
		replayed.erase("walk")
	if legacy_s14:
		replayed.erase("s14")
		# Pre-S14 saves contain neither death-hit counters nor head-ward fields;
		# compare only their authored historical schema, then return the safely
		# replayed candidate in the current schema.
		for hero in replayed.get("heroes", []):
			hero.erase("death_hits")
			hero.erase("head_ward")
		if replayed.get("battle") is Dictionary:
			replayed.battle.erase("s14")
			for unit in replayed.battle.get("units", []):
				if unit.get("side") == "hero":
					unit.erase("death_hits")
					unit.erase("head_ward")
	if legacy_pockets:
		replayed.erase("pockets")
	if legacy_fear:
		replayed.erase("kid_fear")
	if legacy_hand and replayed.get("battle") is Dictionary:
		replayed.battle.erase("hand")
	if legacy_gifts:
		replayed.erase("gifts")
		if replayed.get("battle") is Dictionary and replayed.battle.get("hand") is Dictionary:
			for key in ["gifts", "spent", "covered", "nightlight"]:
				replayed.battle.hand.erase(key)
	if candidate.journal != document.journal or replayed != document.state:
		return null
	return candidate


static func _replay(session: StitchedRunSession, command: Variant) -> bool:
	if not command is Dictionary:
		return false
	match command.get("action"):
		"enter":
			return command.size() == 2 and command.get("node_id") is String and session.enter(command.node_id, session.snapshot())
		"visit":
			if command.size() != 3 and command.size() != 4:
				return false
			if command.size() == 4 and (not command.has("ability_patch") or not command.ability_patch is Dictionary):
				return false
			if command.get("id") == "replace":
				var args: Variant = command.get("arguments")
				if not args is Array or args.size() != 2 or not args[0] is String or not args[1] is String:
					return false
			if not command.get("id") is String or not command.get("arguments") is Array \
					or not session.choose_visit(command.id, command.arguments, session.snapshot()):
				return false
			if command.has("ability_patch"):
				return not session.ability_inventory.is_empty() \
					and session.ability_inventory.back() == command.ability_patch
			return true
		"settle":
			if command.size() != 1 and command.size() != 2:
				return false
			if command.size() == 2 and (not command.has("ability_patch") or not command.ability_patch is Dictionary):
				return false
			if not session.settle_battle(session.battle):
				return false
			return not command.has("ability_patch") or (not session.receipts.is_empty() \
				and session.receipts.back().reward.get("ability_patch", {}) == command.ability_patch)
		"socket":
			return command.size() == 5 and command.get("uid") is int and command.get("hero") is String \
				and command.get("ability") is String and command.get("replace") is int \
				and session.socket_ability(command.uid, command.hero, command.ability, command.replace, session.snapshot())
		"door":
			return command.size() == 3 and command.get("id") is String and command.get("hero") is String \
				and session.choose_door(command.id, command.hero, session.snapshot())
		"gift":
			return command.size() == 3 and command.get("id") is String and command.get("swap") is String \
				and session.choose_gift(command.id, command.swap, session.snapshot())
		"walk":
			return command.size() == 2 and command.get("command") is Dictionary \
				and session.walk_act(command.command, session.snapshot()).get("ok") == true
		"battle":
			if command.size() != 3 or session.phase != "battle" or session.battle == null:
				return false
			var method: Variant = command.get("method")
			var args: Variant = command.get("arguments")
			if not args is Array:
				return false
			match method:
				"use_part", "use_ability", "use_foe_ability":
					if args.size() != 2 or not args[0] is String or not args[1] is int:
						return false
				"move":
					if args.size() != 1 or not args[0] is int:
						return false
				"use_hand_action":
					if args.size() != 3 or not args[0] is String or not args[1] is String or not args[2] is int:
						return false
				"pass_turn", "re_tie", "retreat":
					if not args.is_empty():
						return false
				_:
					return false
			var result: Dictionary = session.battle.callv(method, args)
			return result.get("ok") == true
	return false


static func write_file(path: String, session: StitchedRunSession) -> bool:
	var document := capture(session)
	if document.is_empty():
		return false
	var buffer := var_to_bytes(document)
	if buffer.size() > MAX_BYTES:
		return false
	var staged := path + STAGED_SUFFIX
	var file := FileAccess.open(staged, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(buffer)
	file.close()
	if not _staged_run_matches(staged, buffer, document):
		DirAccess.remove_absolute(staged)
		return false
	# The staged bytes hold the complete latest run. The rename itself replaces
	# the old target, which is never removed first, so a failed replace leaves
	# the previously accepted save intact.
	if DirAccess.rename_absolute(staged, path) != OK:
		DirAccess.remove_absolute(staged)
		return false
	# Fresh readback of the published file proves the player's next Continue
	# sees exactly the just-captured run, never stale or partial bytes.
	var published := FileAccess.open(path, FileAccess.READ)
	if published == null:
		return false
	var final_bytes := published.get_buffer(published.get_length())
	published.close()
	return final_bytes == buffer


## A staged file only counts when its fresh readback holds the complete bytes
## and replays through the validator into the exact just-captured run.
static func _staged_run_matches(staged: String, buffer: PackedByteArray, document: Dictionary) -> bool:
	var file := FileAccess.open(staged, FileAccess.READ)
	if file == null:
		return false
	var readback := file.get_buffer(file.get_length())
	file.close()
	if readback != buffer:
		return false
	var replayed := restore(bytes_to_var(readback))
	return replayed != null and replayed.seed_value == document.seed \
		and replayed.journal == document.journal and replayed.snapshot() == document.state


static func read_file(path: String) -> StitchedRunSession:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return null
	return restore(bytes_to_var(file.get_buffer(file.get_length())))

class_name StitchedRunSave
extends RefCounted
## Safe Variant bytes preserve 64-bit RNG state. Objects are never deserialized.
## Replay into a detached candidate makes every rejection atomic for the caller.

const MAX_COMMANDS := 20000
const MAX_BYTES := 16000000


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
	var candidate := StitchedRunSession.start(document.seed, document.picks, document.initial)
	if candidate == null:
		return null
	var legacy_pockets: bool = not document.state.has("pockets")
	for command in document.journal:
		# Pre-pocket saves can replay their old actions, never a new purchase
		# hidden by omitting its ownership ledger from the saved state.
		if legacy_pockets and command is Dictionary and command.get("action") == "visit" and command.get("id") == "buy_pins":
			return null
		if not _replay(candidate, command):
			return null
	var replayed := candidate.snapshot()
	if legacy_pockets:
		replayed.erase("pockets")
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
			return command.size() == 3 and command.get("id") is String and command.get("arguments") is Array \
				and session.choose_visit(command.id, command.arguments, session.snapshot())
		"settle":
			return command.size() == 1 and session.settle_battle(session.battle)
		"battle":
			if command.size() != 3 or session.phase != "battle" or session.battle == null:
				return false
			var method: Variant = command.get("method")
			var args: Variant = command.get("arguments")
			if not args is Array:
				return false
			match method:
				"use_part", "use_foe_ability":
					if args.size() != 2 or not args[0] is String or not args[1] is int:
						return false
				"move":
					if args.size() != 1 or not args[0] is int:
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
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(buffer)
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path) == OK


static func read_file(path: String) -> StitchedRunSession:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return null
	return restore(bytes_to_var(file.get_buffer(file.get_length())))

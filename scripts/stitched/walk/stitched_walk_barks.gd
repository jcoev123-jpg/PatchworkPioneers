class_name StitchedWalkBarks
extends RefCounted
## S10 idle chatter: when the player leaves the walk alone, a trailing doll speaks.
## Presentation only. The line reads the walk's hidden state (the extra doll, the tug,
## the machine, the candle, hurt seams, Wren's fear) so a waiting player gets a hint
## without any new readout. Picks are seeded from the walk, never from the rules' RNG.

const DATA_PATH := "res://data/walk/barks.json"
const HURT_SHARE := 0.4
const OWN_LINE_CHANCE := 0.3

var data: Dictionary = {}


func _init() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			data = parsed


func valid() -> bool:
	return data.get("contexts") is Dictionary and not data.contexts.get("idle", []).is_empty()


## What the dolls would worry about right now, most pressing first.
static func context(state: Dictionary, walk: StitchedWalkRules, band: String, fear: int) -> String:
	if walk.tug_unresolved():
		return "tug"
	var shadow: Dictionary = state.get("shadow", {})
	if bool(shadow.get("present", false)) and not bool(shadow.get("removed", false)) \
			and int(state.step) >= int(shadow.get("step", 0)):
		return "shadow"
	if walk.mannequins_visible():
		return "mannequins"
	if int(state.get("whirr", 0)) >= 50:
		return "whirr"
	if band in ["dark", "snuffed"]:
		return "dark"
	if not hurt_doll(state).is_empty():
		return "hurt"
	if fear >= StitchedKidFear.SHAKE_THRESHOLD:
		return "wren"
	for curio in state.get("curios", []):
		if curio.step == state.step and not curio.get("resolved", false):
			return "curio"
	return "idle"


## The living doll worst off, when one is below the hurt share of its stitches.
static func hurt_doll(state: Dictionary) -> Dictionary:
	var worst := {}
	for doll in state.get("dolls", []):
		if doll.lost or float(doll.hp) >= float(doll.max_hp) * HURT_SHARE:
			continue
		if worst.is_empty() or float(doll.hp) / doll.max_hp < float(worst.hp) / worst.max_hp:
			worst = doll
	return worst


## One line: {speaker, name, line, context}. `count` is how many lines this walk has heard.
func pick(state: Dictionary, walk: StitchedWalkRules, band: String, fear: int, count: int, last_line: String = "") -> Dictionary:
	var kind := context(state, walk, band, fear)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([str(state.get("corridor", {}).get("id", "")), int(state.get("step", 0)), count])
	var speaker := hurt_doll(state) if kind == "hurt" else {}
	if speaker.is_empty():
		var voices: Array = []
		for doll in state.get("dolls", []):
			if not doll.lost and doll.id != state.get("viewpoint"):
				voices.append(doll)
		if voices.is_empty():
			for doll in state.get("dolls", []):
				if not doll.lost:
					voices.append(doll)
		if voices.is_empty():
			return {}
		speaker = voices[rng.randi_range(0, voices.size() - 1)]
	var lines: Array = data.get("contexts", {}).get(kind, [])
	var own: Array = data.get("dolls", {}).get(str(speaker.id), [])
	if kind == "idle" and not own.is_empty() and rng.randf() < OWN_LINE_CHANCE:
		lines = own
	if lines.is_empty():
		lines = data.get("contexts", {}).get("idle", [])
	if lines.is_empty():
		return {}
	var index := rng.randi_range(0, lines.size() - 1)
	if lines.size() > 1 and str(lines[index]) == last_line:
		index = (index + 1) % lines.size()
	return {"speaker": str(speaker.id), "name": str(speaker.name), "line": str(lines[index]), "context": kind}

## Shared test step (cycle 332): title Start now mounts the pick-three screen before any run exists.
## Tests that used to reach the map straight from Start choose a party here through the real
## picker tiles and Continue. Does nothing when Start mounted no picker (an ignored Start).
extends RefCounted


static func choose(app: Node, ids: Array = ["warden", "seamstress", "tinker"]) -> void:
	var picker = app.get("party_picker")
	if not is_instance_valid(picker) or not picker.is_visible_in_tree():
		return
	for id in ids:
		picker._tiles[id].pressed.emit()
	picker.continue_button.pressed.emit()

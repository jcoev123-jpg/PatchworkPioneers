class_name StitchedS15FieldNotes
extends RefCounted
## Read-only S15 Field Guide teaching. Detached sources are never changed, and
## invalid or contradictory S15 data never produces a partial lesson.

## These are *contract checks*, not gameplay tuning. Mechanics are read from
## StitchedRules and StitchedDeeperSeams, the only authorities for the values.
static func examples(source: Variant = null) -> Array[String]:
	var seams: Variant = source if source != null else StitchedDeeperSeams.table()
	if not _valid_contract(seams):
		return []
	return [
		"SEAM RESISTS  |  A landed ability can still have its stun, bleed, rot, pull/push or debuff resisted by a foe. Its damage is separate.",
		"PATCH THREAD  |  Cotton cannot pierce resistance; wool helps, silk helps more and gold's sewn effect gets through resistance. Piercing does not guarantee an attack hits.",
		"ROT  |  Mildew gnaws through stuffing protection and makes healing less helpful until it clears. Foes grow tougher farther down the corridor.",
	]


static func _valid_contract(source: Variant) -> bool:
	# Fail closed if the active rules ever drift away from this authored lesson.
	if StitchedRules.RESIST_KEYS != ["stun", "bleed", "rot", "move", "debuff"] \
			or StitchedRules.RESIST_MAX != 90 or StitchedRules.ROT_TICK != 2:
		return false
	var pierce: Dictionary = StitchedRules.PATCH_PIERCE
	if pierce.size() != 4 or pierce.get("cotton") != 0 or pierce.get("wool") != 15 \
			or pierce.get("silk") != 30 or pierce.get("gold") != 100:
		return false
	if StitchedRules.rot_heal({"statuses": {"rot": 1}}, 5) != 2 \
			or StitchedRules.rot_heal({"statuses": {}}, 5) != 5:
		return false
	if StitchedDeeperSeams.DEPTH_HP_PERCENT != 5 \
			or StitchedDeeperSeams.DEPTH_DMG_FLOORS != 4 \
			or StitchedDeeperSeams.BOSS_HP_PERCENT != 60 \
			or StitchedDeeperSeams.BOSS_DMG_PERCENT != 70:
		return false
	if not source is Dictionary or source.size() != 2:
		return false
	var resists: Variant = source.get("resists")
	var rot_attacks: Variant = source.get("rot_attacks")
	if not resists is Dictionary or resists.is_empty() \
			or not rot_attacks is Dictionary or rot_attacks.is_empty():
		return false
	for foe_id in resists:
		var row: Variant = resists[foe_id]
		if not foe_id is String or foe_id.is_empty() or not row is Dictionary \
				or row.size() != StitchedRules.RESIST_KEYS.size():
			return false
		for group in StitchedRules.RESIST_KEYS:
			if not row.has(group) or not StitchedParts._integral(row[group]) \
					or int(row[group]) < 0 or int(row[group]) > StitchedRules.RESIST_MAX:
				return false
	# Validate the real mildew carriers, without fixing the total foe catalog size.
	for foe_id in ["moth_swarm", "quilt_termite", "moth_queen"]:
		if not resists.has(foe_id) or not rot_attacks.has(foe_id):
			return false
	for foe_id in rot_attacks:
		var attacks: Variant = rot_attacks[foe_id]
		if not foe_id is String or not resists.has(foe_id) \
				or not attacks is Dictionary or attacks.is_empty():
			return false
		for ability_id in attacks:
			if not ability_id is String or ability_id.is_empty() \
					or not StitchedParts._integral(attacks[ability_id]) \
					or int(attacks[ability_id]) <= 0 \
					or int(attacks[ability_id]) > StitchedDeeperSeams.ROT_MAX:
				return false
	if rot_attacks["moth_swarm"].get("wing_dust") != 2 \
			or rot_attacks["quilt_termite"].get("termite_lint_spit") != 2 \
			or rot_attacks["moth_queen"].get("queen_dust") != 3:
		return false
	return true

class_name RunMapMendChoices
extends RefCounted
## Detached map Mend choices. This adapter neither holds a wallet nor reserves
## an operation: only RunTornCarryover.choose_mend may commit a purchase.

const MEND_COST := RunTornMending.MEND_COST


## Caller supplies actual current owner snapshots; invented rosters and prices
## cannot replace the bound run services. Unaffordable torn heroes remain visible.
static func project(carryover: RunTornCarryover, expected_carryover: Variant,
		expected_wardrobe: Variant, available_scraps: Variant,
		between_nodes: Variant) -> Dictionary:
	var rejected := {"ok": false, "options": []}
	if carryover == null:
		return rejected
	if not carryover.is_valid() or carryover.torn == null:
		return rejected
	if not carryover.torn.is_valid():
		return rejected
	if typeof(between_nodes) != TYPE_BOOL or not between_nodes:
		return rejected
	if typeof(available_scraps) != TYPE_INT or available_scraps < 0:
		return rejected
	if typeof(expected_carryover) != TYPE_DICTIONARY:
		return rejected
	if expected_carryover != carryover.read_state() or expected_carryover.get("ok") != true:
		return rejected

	var torn_state: Dictionary = carryover.torn.read_state()
	var heroes: Variant = expected_carryover.get("heroes")
	if torn_state.get("ok") != true or torn_state.get("defeated") != false:
		return rejected
	if torn_state.get("heroes") != heroes or not RunTornMending._valid_roster(heroes):
		return rejected
	if not carryover._same_identities(heroes) or carryover._observer() == null:
		return rejected

	# Victory is not between nodes until its reward was claimed and the
	# admitted battle was published to the torn ledger.
	if carryover._node != "" and not torn_state.completed_battles.has(carryover._node):
		return rejected

	var wardrobe: RunPatchWardrobe = carryover._wardrobe
	if wardrobe == null:
		if expected_wardrobe != null:
			return rejected
	else:
		if not wardrobe.is_valid() or typeof(expected_wardrobe) != TYPE_DICTIONARY:
			return rejected
		if expected_wardrobe != wardrobe.get_snapshot():
			return rejected
		if expected_wardrobe.get("heroes") != heroes:
			return rejected
		if expected_wardrobe.get("scraps") != available_scraps:
			return rejected
		if expected_wardrobe.get("rest_id") != "":
			return rejected
		if carryover._projected_heroes().is_empty():
			return rejected
		if wardrobe.project_active(torn_state).get("ok") != true:
			return rejected

	var options: Array = []
	for hero in heroes:
		if hero["hp"] != 0:
			continue
		@warning_ignore("integer_division")
		var post_mend_hp: int = maxi(1, hero["max_hp"] / 4)
		options.append({
			"hero_id": hero["id"],
			"position": hero["position"],
			"base_max_hp": hero["max_hp"],
			"cost": MEND_COST,
			"post_mend_hp": post_mend_hp,
			"affordable": available_scraps >= MEND_COST,
		})
	return {"ok": true, "options": options}


## Re-project at the selection boundary. A forged/stale/disabled option never
## calls into the owner; exact fresh node and receipt checks stay with the
## owner's one-shot transaction, which also commits a bound wardrobe purse.
## When unbound, remaining_scraps is a proposal for the external purse owner.
static func choose(carryover: RunTornCarryover, option: Variant,
		node_id: Variant, receipt_id: Variant, expected_carryover: Variant,
		expected_wardrobe: Variant, available_scraps: Variant,
		between_nodes: Variant) -> Dictionary:
	var rejected := {"ok": false, "heroes": [], "remaining_scraps": available_scraps}
	var view := project(carryover, expected_carryover, expected_wardrobe,
		available_scraps, between_nodes)
	if not view.ok or typeof(option) != TYPE_DICTIONARY:
		return rejected
	if option.get("affordable") != true:
		return rejected
	var matched := false
	for current in view.options:
		if option == current and current["affordable"]:
			matched = true
			break
	if not matched:
		return rejected
	return carryover.choose_mend(node_id, receipt_id, option["hero_id"],
		option["position"], available_scraps, expected_carryover,
		expected_wardrobe, between_nodes)

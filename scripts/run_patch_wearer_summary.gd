class_name RunPatchWearerSummary
extends RefCounted
## Scene-free, read-only per-hero patch slot and wearer-effect summary.
## Does not alter wardrobe, torn ledger, or any run service.
##
## The readout trusts two authorities only: the wardrobe owns the sewn
## assignments, the torn ledger owns live health. Every named patch is
## cross-checked against its shipped catalog record, so a known patch can
## never be advertised with a slot, power or amount the catalog does not
## authorise. Unknown patches stay visible but never gain invented text.

const SLOTS := ["HEAD", "ARM", "COAT"]
const HERO_IDS := ["warden", "seamstress", "tinker"]
const STARTING_HP := {"warden": 40, "seamstress": 30, "tinker": 26}
const TEAR_LOSS := 3
const MIN_MAX_HP := 10
const STATUS_KEYS := ["bleed", "weak", "exposed"]

const ATTACK_PATCHES_PATH := "res://data/patches/m04_attack_patches.json"
const COAT_PATCHES_PATH := "res://data/patches/m04_coat_patches.json"
const INITIAL_SLOTS_PATH := "res://data/patches/initial_patch_slots.json"
const M05_HEAD_PATCHES_PATH := "res://data/patches/m05_head_patches.json"
const M05_ARM_PATCHES_PATH := "res://data/patches/m05_arm_support_patches.json"
const M05_ATTACK_PATCHES_PATH := "res://data/patches/m05_attack_patches.json"
const M05_COAT_PATCHES_PATH := "res://data/patches/m05_coat_patches.json"

## The only authored wearer powers this readout may describe. Each known ID is
## checked against its shipped catalog record before any text is published.
const KNOWN_ATTACK_POWERS := {
	"button_eye": {"slot": "HEAD", "effect": "first_attack_exposed", "amount": 1},
	"pincushion_arm": {"slot": "ARM", "effect": "card_attack_bonus", "amount": 1},
}
const KNOWN_COAT_POWERS := {
	"quilted_coat": {"slot": "COAT", "max_hp_bonus": 6},
	"padded_vest": {"slot": "COAT", "max_hp_bonus": 4},
	"double_quilt_coat": {"slot": "COAT", "max_hp_bonus": 8},
	"scrap_lined_vest": {"slot": "COAT", "max_hp_bonus": 3},
	"wool_patch_cloak": {"slot": "COAT", "max_hp_bonus": 5},
	"chain_stitched_coat": {"slot": "COAT", "max_hp_bonus": 7},
	"reinforced_patchcoat": {"slot": "COAT", "max_hp_bonus": 9},
	"thick_felt_mantle": {"slot": "COAT", "max_hp_bonus": 10},
}
## M05 HEAD/ARM wearer modifiers. The effect implementation is owned by the
## combat layer (CombatM05HeadPatchRules, CombatFrayfinderMitt); this readout
## only authenticates the authored records and describes them truthfully.
const KNOWN_M05_HEAD_POWERS := {
	"bloodstitch_bonnet": {"slot": "HEAD", "effect": "card_bleed_bonus", "amount": 1},
	"button_glass_visor": {"slot": "HEAD", "effect": "card_exposed_bonus", "amount": 1},
	"stern_seam_cap": {"slot": "HEAD", "effect": "card_weak_bonus", "amount": 1},
	"reinforced_browband": {"slot": "HEAD", "effect": "card_block_bonus", "amount": 2},
}
const KNOWN_M05_ARM_POWERS := {
	"hemguard_cuff": {"slot": "ARM", "effect": "card_block_bonus", "amount": 2},
	"red_bobbin_cuff": {"slot": "ARM", "effect": "card_bleed_bonus", "amount": 1},
	"loose_thread_glove": {"slot": "ARM", "effect": "card_unravel_bonus", "amount": 1},
}
## Frayfinder is a conditional first-hit attack-damage bonus, never an
## unconditional +2 to every attack and never an Unravel gauge award. Every
## authored condition is part of the identity.
const KNOWN_M05_ATTACK_POWERS := {
	"frayfinder_mitt": {"slot": "ARM",
		"effect": "first_single_target_half_unravel_attack_bonus", "amount": 2,
		"minimum_unravel_numerator": 1, "minimum_unravel_denominator": 2,
		"once_per_player_turn": true, "hit_number": 1, "target_kind": "enemy_single"},
}
## M05 COAT wearer modifier. The condition belongs to CombatBorrowedButton, which
## is not yet bound into live combat, so this readout only authenticates the
## authored record and describes its exact trigger. It never claims a live Block
## award and never turns the coat into a maximum-HP bonus.
const KNOWN_M05_COAT_POWERS := {
	"borrowed_button": {"slot": "COAT", "effect": "other_hero_committed_heal_block",
		"heal_threshold": 1, "block": 3, "uses_per_combat": 1},
}
## Shop catalogs author slot identity alone; CombatShopPatchRules owns their powers.
## Descriptions of the already authored rules, never new effect calculations.
const KNOWN_TEXTS := {
	"button_eye": "first successful attack each combat also applies Exposed 1",
	"pincushion_arm": "+1 damage on that wearer's damaging cards",
	"quilted_coat": "+6 maximum HP",
	"padded_vest": "+4 maximum HP",
	"double_quilt_coat": "+8 maximum HP",
	"scrap_lined_vest": "+3 maximum HP",
	"wool_patch_cloak": "+5 maximum HP",
	"chain_stitched_coat": "+7 maximum HP",
	"reinforced_patchcoat": "+9 maximum HP",
	"thick_felt_mantle": "+10 maximum HP",
	"bloodstitch_bonnet": "+1 Bleed on eligible Bleed cards owned by this living wearer only",
	"button_glass_visor": "+1 Exposed on eligible Exposed cards owned by this living wearer only",
	"stern_seam_cap": "+1 Weak on eligible Weak cards owned by this living wearer only",
	"reinforced_browband": "+2 Block on eligible Block cards owned by this living wearer only",
	"hemguard_cuff": "+2 Block on eligible Block cards owned by this living wearer only",
	"red_bobbin_cuff": "+1 Bleed on eligible Bleed cards owned by this living wearer only",
	"loose_thread_glove": "+1 Unravel on eligible Unravel cards owned by this living wearer only",
	"frayfinder_mitt": "+2 attack damage once per player turn on this living wearer's first confirmed single-target hit against an enemy already at half its current Unravel threshold; no bonus on area or later hits.",
	"borrowed_button": "Once per combat, when another living hero's committed card or stitched half restores at least 1 HP to this living wearer, gain 3 Block.",
}


## Summarize every worn slot of the caller's three heroes.
## `catalogs` may override the shipped catalogs (arrays keyed by catalog name,
## such as "attack", "coat", "initial", "m05_head", "m05_arm", "m05_attack" and
## "m05_coat") so malformed authored records can be exercised without touching
## any on-disk JSON; an omitted or empty override reads the shipped files.
static func summarize(wardrobe: RunPatchWardrobe, torn_state: Variant,
		catalogs: Variant = {}) -> Dictionary:
	if wardrobe == null or not wardrobe.is_valid():
		return _rejected()
	if not _valid_heroes(torn_state):
		return _rejected()

	var authority: Dictionary = _authority(catalogs)
	if authority.is_empty():
		return _rejected()
	var catalog_slots: Dictionary = authority["slots"]

	var snapshot: Dictionary = wardrobe.get_snapshot()
	if snapshot.get("valid") != true:
		return _rejected()
	var definitions_value: Variant = snapshot.get("definitions")
	var owned_value: Variant = snapshot.get("owned")
	var worn_value: Variant = snapshot.get("worn")
	if typeof(definitions_value) != TYPE_DICTIONARY or typeof(owned_value) != TYPE_ARRAY \
			or typeof(worn_value) != TYPE_DICTIONARY:
		return _rejected()
	var definitions: Dictionary = definitions_value
	var owned: Array = owned_value
	var worn: Dictionary = worn_value

	# The wardrobe may not contradict an authored catalog slot.
	for id in definitions:
		var declared: Variant = definitions[id]
		if typeof(declared) != TYPE_STRING or not SLOTS.has(declared):
			return _rejected()
		if catalog_slots.has(id) and catalog_slots[id] != declared:
			return _rejected()

	# Project active against the detached torn ledger; it must succeed and
	# describe exactly the pictured wearers.
	var projection: Dictionary = wardrobe.project_active(torn_state)
	if projection.get("ok") != true:
		return _rejected()
	var projection_active: Variant = projection.get("active")
	var projection_worn: Variant = projection.get("worn")
	if typeof(projection_active) != TYPE_DICTIONARY or projection_worn != worn:
		return _rejected()

	var heroes: Array = torn_state["heroes"]
	# Every worn patch is owned, sewn once, in its declared and authored slot.
	var seen_worn: Dictionary = {}
	for hero in heroes:
		var hero_id: String = hero["id"]
		var slots_value: Variant = worn.get(hero_id)
		if typeof(slots_value) != TYPE_DICTIONARY:
			return _rejected()
		var slots_dict: Dictionary = slots_value
		if slots_dict.size() != SLOTS.size():
			return _rejected()
		for slot in SLOTS:
			var patch_id: Variant = slots_dict.get(slot)
			if typeof(patch_id) != TYPE_STRING:
				return _rejected()
			if patch_id == "":
				continue
			if not owned.has(patch_id) or definitions.get(patch_id) != slot:
				return _rejected()
			if catalog_slots.has(patch_id) and catalog_slots[patch_id] != slot:
				return _rejected()
			if seen_worn.has(patch_id):
				return _rejected()
			seen_worn[patch_id] = true

	# The published activation must be the wardrobe's own projection.
	for hero in heroes:
		var hero_id: String = hero["id"]
		var expected_active: Array = []
		var slots_dict: Dictionary = worn.get(hero_id)
		if hero["hp"] > 0:
			for slot in SLOTS:
				var pid: String = slots_dict.get(slot, "")
				if pid != "":
					expected_active.append(pid)
		var actual_active: Variant = projection_active.get(hero_id)
		if typeof(actual_active) != TYPE_ARRAY:
			return _rejected()
		# Arrays of strings; compare sorted contents to avoid ordering issues.
		var expected_sorted: Array = expected_active.duplicate(true)
		expected_sorted.sort()
		var actual_sorted: Array = actual_active.duplicate(true)
		actual_sorted.sort()
		if expected_sorted != actual_sorted:
			return _rejected()

	var result_heroes: Array = []
	for hero in heroes:
		var hero_id: String = hero["id"]
		var position: int = hero["position"]
		var hp: int = hero["hp"]
		var slots_result: Array = []
		for slot in SLOTS:
			var patch_id: String = worn.get(hero_id, {}).get(slot, "")
			var active_for_slot: bool = false
			if patch_id != "" and hero["hp"] > 0:
				var active_array: Array = projection_active.get(hero_id, [])
				active_for_slot = active_array.has(patch_id)
			var rules_text: String = ""
			if patch_id != "":
				rules_text = _resolve_rules_text(patch_id, catalog_slots)
			slots_result.append({
				"slot": slot,
				"patch_id": patch_id,
				"active": active_for_slot,
				"rules_text": rules_text
			})
		result_heroes.append({
			"id": hero_id,
			"position": position,
			"hp": hp,
			"slots": slots_result
		})

	return {"ok": true, "heroes": result_heroes}


## Preview one FREE Elite sew without reserving, moving or destroying anything.
## Reuse the full catalog/activation audit, not caller-supplied effect text.
## Unknown future slot-only definitions can be named, but have no claimed power.
static func preview_sew(wardrobe: RunPatchWardrobe, torn_state: Variant,
		patch_id: Variant, hero_id: Variant, catalogs: Variant = {}) -> Dictionary:
	var rejected := {"ok": false}
	if typeof(patch_id) != TYPE_STRING or not RunPatchWardrobe._id(patch_id) \
			or typeof(hero_id) != TYPE_STRING or not HERO_IDS.has(hero_id):
		return rejected
	var summary: Dictionary = summarize(wardrobe, torn_state, catalogs)
	if summary.get("ok") != true:
		return rejected
	var snapshot: Dictionary = wardrobe.get_snapshot()
	# A choice must use this run's current roster, not a detached old one.
	if snapshot.get("heroes") != torn_state.get("heroes"):
		return rejected
	var owned: Array = snapshot["owned"]
	var definitions: Dictionary = snapshot["definitions"]
	var slot: Variant = definitions.get(patch_id)
	if not owned.has(patch_id) or typeof(slot) != TYPE_STRING or not SLOTS.has(slot):
		return rejected
	for entry in summary["heroes"]:
		for worn in entry["slots"]:
			if worn["patch_id"] == patch_id:
				return rejected
	var target: Dictionary = {}
	for entry in summary["heroes"]:
		if entry["id"] == hero_id:
			target = entry
			break
	if target.is_empty() or target["hp"] <= 0:
		return rejected
	var prior: Dictionary = {}
	for worn in target["slots"]:
		if worn["slot"] == slot:
			prior = worn
			break
	if prior.is_empty():
		return rejected
	var displaced: String = prior["patch_id"]
	if displaced != "" and (not owned.has(displaced) or definitions.get(displaced) != slot
			or snapshot["scraps"] == RunPatchWardrobe.MAX_INT):
		return rejected
	var authority: Dictionary = _authority(catalogs)
	if authority.is_empty():
		return rejected
	var authoritative_slots: Dictionary = authority["slots"]
	# Known items cannot ever be previewed under contradicted definitions.
	if authoritative_slots.has(patch_id) and authoritative_slots[patch_id] != slot:
		return rejected
	return {"ok": true, "patch_id": patch_id, "slot": slot,
		"rules_text": _resolve_rules_text(patch_id, authoritative_slots),
		"wearer": hero_id, "displaced_id": displaced,
		"displaced_rules_text": prior["rules_text"],
		"scrap_delta": 1 if displaced != "" else 0}


## A detached ledger must be a complete, self-consistent
## RunTornMending.read_state() envelope, not only a roster.
static func _valid_heroes(torn_state: Variant) -> bool:
	if typeof(torn_state) != TYPE_DICTIONARY or torn_state.get("ok") != true:
		return false
	var heroes: Variant = torn_state.get("heroes")
	if not _valid_roster(heroes):
		return false
	var counts_value: Variant = torn_state.get("tear_counts")
	if typeof(counts_value) != TYPE_DICTIONARY:
		return false
	var counts: Dictionary = counts_value
	if counts.size() != HERO_IDS.size():
		return false
	for hero_id in HERO_IDS:
		var count: Variant = counts.get(hero_id)
		if typeof(count) != TYPE_INT or count < 0:
			return false
	# Each tear lowers a wearer's maximum HP by three, never below ten.
	for hero in heroes:
		var hero_id: String = hero["id"]
		if hero["max_hp"] != _expected_max_hp(hero_id, counts[hero_id]):
			return false
	for field in ["completed_battles", "completed_mends", "completed_rests"]:
		var entries: Variant = torn_state.get(field)
		if typeof(entries) != TYPE_ARRAY:
			return false
		for entry in entries:
			if typeof(entry) != TYPE_STRING or entry.is_empty():
				return false
	var defeated: Variant = torn_state.get("defeated")
	if typeof(defeated) != TYPE_BOOL:
		return false
	# A defeated run cannot still carry a living hero. Health itself may
	# diverge from an earlier ledger after a lawful tear, mend or Rest.
	for hero in heroes:
		if defeated and hero["hp"] > 0:
			return false
	return true


static func _valid_roster(heroes: Variant) -> bool:
	if typeof(heroes) != TYPE_ARRAY or heroes.size() != HERO_IDS.size():
		return false
	var seen: Dictionary = {}
	for i in range(heroes.size()):
		var hero: Variant = heroes[i]
		if typeof(hero) != TYPE_DICTIONARY:
			return false
		var hero_id: Variant = hero.get("id")
		if typeof(hero_id) != TYPE_STRING or hero_id.is_empty() or hero_id.strip_edges() != hero_id:
			return false
		if seen.has(hero_id) or not HERO_IDS.has(hero_id):
			return false
		seen[hero_id] = true
		var position: Variant = hero.get("position")
		if typeof(position) != TYPE_INT or position != i + 1:
			return false
		for field in ["hp", "max_hp", "block"]:
			var val: Variant = hero.get(field)
			if typeof(val) != TYPE_INT:
				return false
		if hero.get("max_hp") < MIN_MAX_HP:
			return false
		if hero.get("hp") < 0 or hero.get("hp") > hero.get("max_hp") or hero.get("block") < 0:
			return false
		var statuses: Variant = hero.get("statuses", {})
		if typeof(statuses) != TYPE_DICTIONARY:
			return false
		for status in statuses:
			if typeof(status) != TYPE_STRING or not STATUS_KEYS.has(status):
				return false
			if typeof(statuses[status]) != TYPE_INT or statuses[status] < 0:
				return false
	return seen.size() == HERO_IDS.size()


static func _expected_max_hp(hero_id: String, tears: int) -> int:
	var starting: int = STARTING_HP[hero_id]
	# Saturate before multiplication, avoiding overflow from forged counts.
	var turns_to_floor: int = ceili(float(starting - MIN_MAX_HP) / float(TEAR_LOSS))
	if tears >= turns_to_floor:
		return MIN_MAX_HP
	return starting - TEAR_LOSS * tears


## Resolve the authoritative catalog records. Returns {} when any known
## record is missing, malformed or contradictory.
static func _authority(catalogs: Variant) -> Dictionary:
	if catalogs == null or typeof(catalogs) != TYPE_DICTIONARY:
		return {}
	var attack: Variant = _catalog_array(catalogs, "attack", ATTACK_PATCHES_PATH)
	var coat: Variant = _catalog_array(catalogs, "coat", COAT_PATCHES_PATH)
	var initial: Variant = _catalog_array(catalogs, "initial", INITIAL_SLOTS_PATH)
	var m05_head: Variant = _catalog_array(catalogs, "m05_head", M05_HEAD_PATCHES_PATH)
	var m05_arm: Variant = _catalog_array(catalogs, "m05_arm", M05_ARM_PATCHES_PATH)
	var m05_attack: Variant = _catalog_array(catalogs, "m05_attack", M05_ATTACK_PATCHES_PATH)
	var m05_coat: Variant = _catalog_array(catalogs, "m05_coat", M05_COAT_PATCHES_PATH)
	if typeof(attack) != TYPE_ARRAY or typeof(coat) != TYPE_ARRAY \
			or typeof(initial) != TYPE_ARRAY or typeof(m05_head) != TYPE_ARRAY \
			or typeof(m05_arm) != TYPE_ARRAY or typeof(m05_attack) != TYPE_ARRAY \
			or typeof(m05_coat) != TYPE_ARRAY:
		return {}
	var slots: Dictionary = {}
	if not _collect(attack, "attack", slots):
		return {}
	if not _collect(coat, "coat", slots):
		return {}
	if not _collect(initial, "initial", slots):
		return {}
	if not _collect(m05_head, "m05_head", slots):
		return {}
	if not _collect(m05_arm, "m05_arm", slots):
		return {}
	if not _collect(m05_attack, "m05_attack", slots):
		return {}
	if not _collect(m05_coat, "m05_coat", slots):
		return {}
	for id in KNOWN_ATTACK_POWERS:
		if not slots.has(id):
			return {}
	for id in KNOWN_COAT_POWERS:
		if not slots.has(id):
			return {}
	for id in CombatShopPatchRules.EFFECTS:
		if not slots.has(id):
			return {}
	for id in KNOWN_M05_HEAD_POWERS:
		if not slots.has(id):
			return {}
	for id in KNOWN_M05_ARM_POWERS:
		if not slots.has(id):
			return {}
	for id in KNOWN_M05_ATTACK_POWERS:
		if not slots.has(id):
			return {}
	for id in KNOWN_M05_COAT_POWERS:
		if not slots.has(id):
			return {}
	return {"slots": slots}


static func _catalog_array(catalogs: Dictionary, key: String, path: String) -> Variant:
	if catalogs.has(key):
		var provided: Variant = catalogs[key]
		if typeof(provided) != TYPE_ARRAY:
			return null
		return provided
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		return null
	var parsed: Variant = JSON.parse_string(source)
	if typeof(parsed) != TYPE_ARRAY:
		return null
	return parsed


## Validate every known record of one shipped catalog. Unknown records are
## left alone so a later authored patch cannot break this readout.
static func _collect(entries: Array, kind: String, slots: Dictionary) -> bool:
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var id: Variant = entry.get("id")
		if typeof(id) != TYPE_STRING or id.is_empty():
			continue
		if kind == "attack":
			if not KNOWN_ATTACK_POWERS.has(id):
				continue
			if slots.has(id):
				return false
			var expected: Dictionary = KNOWN_ATTACK_POWERS[id]
			if entry.get("slot") != expected["slot"] or entry.get("effect") != expected["effect"]:
				return false
			var amount: Variant = entry.get("amount")
			if not _integral(amount) or int(amount) != int(expected["amount"]):
				return false
			slots[id] = expected["slot"]
		elif kind == "coat":
			if not KNOWN_COAT_POWERS.has(id):
				continue
			if slots.has(id):
				return false
			var expected: Dictionary = KNOWN_COAT_POWERS[id]
			if entry.get("slot") != expected["slot"]:
				return false
			var bonus: Variant = entry.get("max_hp_bonus")
			if not _integral(bonus) or int(bonus) != int(expected["max_hp_bonus"]):
				return false
			slots[id] = expected["slot"]
		elif kind == "m05_head" or kind == "m05_arm":
			var table: Dictionary = KNOWN_M05_HEAD_POWERS
			if kind == "m05_arm":
				table = KNOWN_M05_ARM_POWERS
			if not table.has(id):
				continue
			if slots.has(id):
				return false
			var expected: Dictionary = table[id]
			if entry.get("slot") != expected["slot"] or entry.get("effect") != expected["effect"]:
				return false
			var amount: Variant = entry.get("amount")
			if not _integral(amount) or int(amount) != int(expected["amount"]):
				return false
			slots[id] = expected["slot"]
		elif kind == "m05_attack":
			if not KNOWN_M05_ATTACK_POWERS.has(id):
				continue
			if slots.has(id):
				return false
			var expected: Dictionary = KNOWN_M05_ATTACK_POWERS[id]
			if entry.get("slot") != expected["slot"] or entry.get("effect") != expected["effect"]:
				return false
			var amount: Variant = entry.get("amount")
			if not _integral(amount) or int(amount) != int(expected["amount"]):
				return false
			var numerator: Variant = entry.get("minimum_unravel_numerator")
			var denominator: Variant = entry.get("minimum_unravel_denominator")
			if not _integral(numerator) \
					or int(numerator) != int(expected["minimum_unravel_numerator"]):
				return false
			if not _integral(denominator) \
					or int(denominator) != int(expected["minimum_unravel_denominator"]):
				return false
			if entry.get("once_per_player_turn") != true:
				return false
			var hit_number: Variant = entry.get("hit_number")
			if not _integral(hit_number) or int(hit_number) != int(expected["hit_number"]):
				return false
			if entry.get("target_kind") != expected["target_kind"]:
				return false
			slots[id] = expected["slot"]
		elif kind == "m05_coat":
			if not KNOWN_M05_COAT_POWERS.has(id):
				continue
			if slots.has(id):
				return false
			var expected: Dictionary = KNOWN_M05_COAT_POWERS[id]
			if entry.get("slot") != expected["slot"] or entry.get("effect") != expected["effect"]:
				return false
			# Every authored number is part of the condition: a positive but
			# different threshold, Block or use count is a different power.
			for field in ["heal_threshold", "block", "uses_per_combat"]:
				var value: Variant = entry.get(field)
				if not _integral(value) or value <= 0:
					return false
				if int(value) != int(expected[field]):
					return false
			slots[id] = expected["slot"]
		else:
			if not CombatShopPatchRules.EFFECTS.has(id):
				continue
			if slots.has(id):
				return false
			var shop_slot: String = CombatShopPatchRules.EFFECTS[id]["slot"]
			if entry.get("slot") != shop_slot:
				return false
			# Shop powers belong to CombatShopPatchRules, never metadata fields.
			if entry.has("effect") or entry.has("amount") or entry.has("max_hp_bonus"):
				return false
			slots[id] = shop_slot
	return true


## Only a validated, known record may publish a description.
static func _resolve_rules_text(patch_id: String, catalog_slots: Dictionary) -> String:
	if not catalog_slots.has(patch_id):
		return ""
	if patch_id == CombatShopPatchRules.STITCHED_BADGE_ID:
		return "+%d opening Block for this living wearer (stacks with innate Block)" % CombatShopPatchRules.OPENING_BLOCK_BONUS
	if patch_id == CombatShopPatchRules.SPARE_SPOOL_ID:
		return "+%d healing on positive-heal cards owned by this living wearer only" % CombatShopPatchRules.HEALING_CARD_BONUS
	return KNOWN_TEXTS.get(patch_id, "")


static func _integral(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		return is_finite(value) and floor(value) == value
	return false


static func _rejected() -> Dictionary:
	return {"ok": false, "heroes": []}

class_name StitchedFoeIntent
extends RefCounted
## Read-only projection of the rank-rotated live foe driver's next legal ability.
## It does not advance a turn, roll RNG, or inspect/modify an actor's private state.

static func choose(battle: StitchedRules, foe: Dictionary) -> Dictionary:
	if battle == null or battle.is_over() or foe.is_empty():
		return {}
	# Only the current, authoritative living foe can have an intent. Public
	# actor dictionaries are snapshots; never trust a detached impostor.
	var actor := battle.get_unit(str(foe.get("id", "")))
	if actor.is_empty() or str(actor.get("side", "")) != "foe" or bool(actor.get("dead", false)) \
			or bool(actor.get("lost", false)) or int(actor.get("hp", 0)) <= 0:
		return {}
	var result := {
		"foe_id": str(actor["id"]),
		"foe_name": str(actor.get("name", "")),
		"ability_id": "",
		"ability_name": "",
		"ability_kind": "",
		"target_rank": 0,
		"target_side": "",
		"affected_ranks": [],
		"multi": false,
		"pass": true,
		"stun": false,
	}
	# The rules consume a stunned actor's turn in _enter_turn before the
	# automatic driver can act. Do not announce a guaranteed attack.
	if int(actor.get("statuses", {}).get("stun", 0)) > 0:
		result["stun"] = true
		return result
	var authored: Array = actor.get("abilities", [])
	var offset := (battle.round_number() - 1) % maxi(1, authored.size())
	for step in range(authored.size()):
		var ability: Dictionary = authored[(offset + step) % authored.size()]
		if not StitchedParts.ranks_allowed(int(ability["launch_mask"]), int(actor["rank"])) \
				or not battle._self_move_gate(actor, ability).is_empty():
			continue
		# A pulling strike reels the deepest reachable doll forward, so it scans the
		# back rank first. A single-target attack authored to bite into a Marked doll
		# hunts the closest already-Marked legal rank. The Moth Swarm's Wing Dust instead
		# follows the most-frayed legal doll. Everything else keeps the ordinary
		# nearest-legal-rank order.
		var scan_ranks: Array[int] = [1, 2, 3, 4]
		if _wards_wounded_ally(actor, ability):
			# The Needle Marshal's Iron Discipline is a single ally ward chosen by need,
			# never by the nearest rank. An ineligible line falls through to the next
			# authored action exactly like any other ability with no legal target.
			var ward_rank := _wounded_ally_rank(battle, actor, ability)
			if ward_rank <= 0:
				continue
			scan_ranks = [ward_rank]
		elif str(ability.get("target_side", "")) == "enemy" \
				and int(ability.get("effects", {}).get("pull", 0)) == 1:
			scan_ranks = [4, 3, 2, 1]
		elif _hunts_mark(ability):
			var marked_rank := _nearest_marked_rank(battle, actor, ability)
			if marked_rank > 0:
				scan_ranks = [marked_rank]
		elif _hunts_tangled(actor, ability):
			# The Spool Stalker's Knot Stab follows the nearest doll it already lashed into
			# Tangled, even past a closer untangled doll. With no legal Tangled doll left it
			# keeps the ordinary nearest-legal-rank fallback below.
			var tangled_rank := _nearest_tangled_rank(battle, actor, ability)
			if tangled_rank > 0:
				scan_ranks = [tangled_rank]
		elif _hunts_fray(actor, ability):
			# The Moth Swarm's Wing Dust follows the most-frayed legal doll instead of the
			# nearest rank. The same legality authority is asked rank by rank, so a lost,
			# dead, empty or out-of-reach rank can never be chosen; equal FRAY keeps the
			# lower rank because only a strictly greater reading replaces the best.
			var frayed_rank := _most_frayed_legal_rank(battle, actor, ability)
			if frayed_rank <= 0:
				continue
			scan_ranks = [frayed_rank]
		for rank in scan_ranks:
			var targets: Array = battle._legal_targets(actor, ability, rank)
			if targets.is_empty():
				continue
			var ranks: Array[int] = []
			for target in targets:
				var target_rank := int(target["rank"])
				if not ranks.has(target_rank):
					ranks.append(target_rank)
			ranks.sort()
			result["ability_id"] = str(ability["id"])
			result["ability_name"] = str(ability["name"])
			result["ability_kind"] = str(ability.get("kind", ""))
			result["target_rank"] = rank
			result["target_side"] = str(targets[0]["side"])
			result["affected_ranks"] = ranks
			result["multi"] = bool(ability["multi"])
			# Authored, unmodified numbers only; never a hit/damage forecast.
			# Deep copies prevent callers from editing the live ability catalog.
			var authored_damage: Array = ability.get("dmg", [0, 0])
			var authored_effects: Dictionary = ability.get("effects", {})
			result["base_acc"] = int(ability.get("acc", 0))
			result["base_damage"] = authored_damage.duplicate(true)
			result["base_crit"] = int(ability.get("crit", 0))
			result["base_mark_damage"] = int(ability.get("mark_damage", 0))
			result["base_effects"] = authored_effects.duplicate(true)
			result["pass"] = false
			return result
	return result


## True for a single-target attack on the other side that is authored with a Mark bonus.
## Multi-target actions, ally/self buffs, pulls and ordinary attacks keep their own rules.
static func _hunts_mark(ability: Dictionary) -> bool:
	if str(ability.get("target_side", "")) != "enemy" or bool(ability.get("multi", false)):
		return false
	if int(ability.get("mark_damage", 0)) <= 0:
		return false
	return int(ability.get("effects", {}).get("pull", 0)) != 1


## Closest legal rank whose reached target already carries MARK (0 when none). The same
## read-only legality authority is used, so a lost doll, an empty rank, a scrap heap or an
## illegal rank can never be prioritised. Never mutates the battle or draws RNG.
static func _nearest_marked_rank(
	battle: StitchedRules, actor: Dictionary, ability: Dictionary
) -> int:
	for rank in range(1, 5):
		for target in battle._legal_targets(actor, ability, rank):
			if int(target.get("statuses", {}).get("mark", 0)) > 0:
				return rank
	return 0


## True only for the Spool Stalker's own authored Knot Stab. Every other ability on every
## other foe keeps the ordinary round-rotated first-legal-rank order.
static func _hunts_tangled(actor: Dictionary, ability: Dictionary) -> bool:
	return str(actor.get("id", "")) == "spool_stalker" \
		and str(ability.get("id", "")) == "knot_stab"


## Nearest legal living hero rank (1-3, Knot Stab's authored reach) already carrying current
## Tangled. The passed ability's own launch/target masks are the authority, so a lost, dead,
## empty or out-of-reach rank can never be chosen. Exact tangles keep the lower rank because
## ranks are scanned ascending. Returns 0 when no legal Tangled doll remains, which lets the
## ordinary nearest-legal fallback apply. Read-only: never mutates the battle or draws RNG.
static func _nearest_tangled_rank(
	battle: StitchedRules, actor: Dictionary, ability: Dictionary
) -> int:
	for rank in range(1, 4):
		for target in battle._legal_targets(actor, ability, rank):
			if str(target.get("side", "")) != "hero":
				continue
			if int(target.get("statuses", {}).get("tangled", 0)) > 0:
				return rank
	return 0


## True only for the Moth Swarm's own authored Wing Dust. Every other ability on every
## other foe keeps the ordinary round-rotated first-legal-rank order.
static func _hunts_fray(actor: Dictionary, ability: Dictionary) -> bool:
	return str(actor.get("id", "")) == "moth_swarm" \
		and str(ability.get("id", "")) == "wing_dust"


## Legal living hero rank carrying the greatest current FRAY; exact ties keep the lower
## (closer) rank. The passed ability's own target mask is the authority, so Wing Dust's
## authored [1, 3] can never reach rank 2 or rank 4. Dead, lost, empty and non-hero ranks
## are never candidates. Read-only: it never mutates the battle or draws RNG.
static func _most_frayed_legal_rank(
	battle: StitchedRules, actor: Dictionary, ability: Dictionary
) -> int:
	var best_rank := 0
	var best_fray := 0
	for rank in range(1, 5):
		for target in battle._legal_targets(actor, ability, rank):
			# _legal_targets already withholds lost dolls and empty ranks; the side check
			# keeps a malformed cross-side record from ever becoming a hero target.
			if str(target.get("side", "")) != "hero":
				continue
			var fray := int(target.get("fray", 0))
			if best_rank == 0 or fray > best_fray:
				best_rank = rank
				best_fray = fray
	return best_rank


## True only for the Needle Marshal's own authored Iron Discipline. Every other ability on
## every other foe keeps the ordinary round-rotated first-legal-rank order.
static func _wards_wounded_ally(actor: Dictionary, ability: Dictionary) -> bool:
	return str(actor.get("id", "")) == "needle_marshal" \
		and str(ability.get("id", "")) == "iron_discipline"


## Legal living foe rank with the smallest current HP/max_hp fraction; exact ties keep the
## lower (closer) rank. Fractions compare with integer cross-products so no float rounding
## can decide a ward. Dead, lost, empty and scrap-heap ranks are never ward candidates.
## Read-only: it asks the same legality authority and never mutates the battle or draws RNG.
static func _wounded_ally_rank(
	battle: StitchedRules, actor: Dictionary, ability: Dictionary
) -> int:
	var best_rank := 0
	var best_hp := 0
	var best_max := 1
	for rank in range(1, 5):
		for target in battle._legal_targets(actor, ability, rank):
			if not _is_wardable_ally(target):
				continue
			var hp := int(target["hp"])
			var maximum := int(target["max_hp"])
			# hp / maximum < best_hp / best_max, without floats. Equal ratios keep the
			# earlier, lower rank already recorded.
			if best_rank == 0 or hp * best_max < best_hp * maximum:
				best_rank = rank
				best_hp = hp
				best_max = maximum
	return best_rank


## A ward may only land on the caster's own living line: never a hero, scrap heap or the
## already-fallen.
static func _is_wardable_ally(unit: Dictionary) -> bool:
	return str(unit.get("side", "")) == "foe" \
		and not bool(unit.get("dead", false)) \
		and not bool(unit.get("lost", false)) \
		and int(unit.get("hp", 0)) > 0 \
		and int(unit.get("max_hp", 0)) > 0

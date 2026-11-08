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
	# Emergency: the Moth Queen's already-authored Moth Veil is a defensive answer to a
	# critically wounded escort, and it outranks her ordinary round rotation. Only the
	# authoritative living Queen can reach this branch, and the veil still has to launch
	# legally from her real rank and find a legal living ally through the same read-only
	# authority as every ordinary candidate below.
	if _is_moth_queen(actor):
		var veil := _authored_ability(actor, "moth_veil")
		if not veil.is_empty() and _needs_emergency_veil(battle, actor, veil) \
				and StitchedParts.ranks_allowed(int(veil["launch_mask"]), int(actor["rank"])) \
				and battle._self_move_gate(actor, veil).is_empty():
			for rank in range(1, 5):
				var allies: Array = battle._legal_targets(actor, veil, rank)
				if allies.is_empty():
					continue
				_record_choice(result, veil, allies, rank)
				return result
		# Marked prey: once her own Pin Crown Dive has sewn a Mark, the Queen seizes the legal
		# Marked doll with Devour even when her ordinary round rotation would raise Dust or
		# another veil. This stays strictly after the emergency veil above, respects the
		# authored launch/target/single-target masks and the battle's own legality authority,
		# and falls through unchanged to that exact rotation when no living Marked doll is
		# legally reachable. Read-only: no RNG draw and no mutation.
		var devour := _authored_ability(actor, "queen_devour")
		if not devour.is_empty() \
				and StitchedParts.ranks_allowed(int(devour["launch_mask"]), int(actor["rank"])) \
				and battle._self_move_gate(actor, devour).is_empty():
			var prey_rank := _nearest_live_marked_rank(battle, actor, devour)
			if prey_rank > 0:
				var prey: Array = battle._legal_targets(actor, devour, prey_rank)
				if not prey.is_empty():
					_record_choice(result, devour, prey, prey_rank)
					return result
	# Spool Hexer: the elite's authored Hex Bolt is its answer to a Marked doll, so a living doll
	# carrying an active Mark makes it interrupt its ordinary round rotation (Spool Curse or
	# Thread Tag) and fire that exact bolt. Only the authoritative living Hexer reaches this
	# branch; the bolt's own launch mask, move gate and the battle's read-only legality authority
	# decide what is legal, so its authored reach (ranks 1 and 3) is never widened and ranks 2
	# and 4 can never be chosen. With no reachable living Mark it falls through unchanged to the
	# exact old rotation below. Read-only: no RNG draw and no mutation.
	if _is_spool_hexer(actor):
		var hex_bolt := _authored_ability(actor, "hex_bolt")
		if not hex_bolt.is_empty() \
				and StitchedParts.ranks_allowed(int(hex_bolt["launch_mask"]), int(actor["rank"])) \
				and battle._self_move_gate(actor, hex_bolt).is_empty():
			var marked_rank := _nearest_live_marked_rank(battle, actor, hex_bolt)
			if marked_rank > 0:
				var marked_prey: Array = battle._legal_targets(actor, hex_bolt, marked_rank)
				if not marked_prey.is_empty():
					_record_choice(result, hex_bolt, marked_prey, marked_rank)
					return result
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
		elif _hunts_marked_fray(actor, ability):
			# The Spool Snarekeeper's Snare Lash follows its own spool-pull setup: among the
			# dolls the authored reach can hit, it severs the seam of the most-frayed Marked
			# one. With no legal Mark left the ordinary nearest-legal-rank fallback applies.
			var marked_fray_rank := _most_frayed_marked_legal_rank(battle, actor, ability)
			if marked_fray_rank > 0:
				scan_ranks = [marked_fray_rank]
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
		elif _hunts_open_seam(actor, ability):
			# The Scissor Bailiff's Unpick Verdict unpicks a seam that is already parting:
			# a legal doll with one or two of its three limbs torn, then any legal doll that
			# still owns an untorn limb. With nothing left to unpick it keeps the ordinary
			# closest legal attack so the authored damage can still land. The torso never
			# counts, and the same legality authority is asked rank by rank, so a lost,
			# fallen, absent, out-of-reach or stunned doll can never be chosen here.
			var seam_rank := _open_seam_rank(battle, actor, ability)
			if seam_rank > 0:
				scan_ranks = [seam_rank]
		for rank in scan_ranks:
			var targets: Array = battle._legal_targets(actor, ability, rank)
			if targets.is_empty():
				continue
			_record_choice(result, ability, targets, rank)
			return result
	return result


## Writes the shared normalized projection fields for one chosen ability and its real
## legal targets. Authored, unmodified numbers only; deep copies prevent callers from
## editing the live ability catalog.
static func _record_choice(
	result: Dictionary, ability: Dictionary, targets: Array, rank: int
) -> void:
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
	var authored_damage: Array = ability.get("dmg", [0, 0])
	var authored_effects: Dictionary = ability.get("effects", {})
	result["base_acc"] = int(ability.get("acc", 0))
	result["base_damage"] = authored_damage.duplicate(true)
	result["base_crit"] = int(ability.get("crit", 0))
	result["base_mark_damage"] = int(ability.get("mark_damage", 0))
	result["base_effects"] = authored_effects.duplicate(true)
	result["pass"] = false


## True only for the canonical Moth Queen. Every other foe keeps its existing priorities.
static func _is_moth_queen(actor: Dictionary) -> bool:
	return str(actor.get("id", "")) == "moth_queen"


## True only for the canonical Spool Hexer. Every other foe keeps its existing priorities.
static func _is_spool_hexer(actor: Dictionary) -> bool:
	return str(actor.get("id", "")) == "spool_hexer"


## The Queen's own authored ability with this id, unchanged from the live kit ({} when the
## record does not carry it).
static func _authored_ability(actor: Dictionary, ability_id: String) -> Dictionary:
	for ability in actor.get("abilities", []):
		if str(ability.get("id", "")) == ability_id:
			return ability
	return {}


## Emergency veil trigger: at least one OTHER living, non-LOST foe at positive HP no more
## than half its own maximum and with no active temporary Dodge buff. The passed ability's
## own ally target authority is asked rank by rank, so a dead escort, a LOST unit, a scrap
## heap or a missing rank can never satisfy it. Read-only: no RNG, no mutation.
static func _needs_emergency_veil(
	battle: StitchedRules, actor: Dictionary, ability: Dictionary
) -> bool:
	var queen_id := str(actor.get("id", ""))
	for rank in range(1, 5):
		for target in battle._legal_targets(actor, ability, rank):
			if str(target.get("id", "")) == queen_id:
				continue
			if _is_critically_wounded_escort(target):
				return true
	return false


## A living foe escort at 2*HP <= max HP that is not already sheltered by temporary Dodge.
## Dead, LOST and empty records are excluded before any HP comparison.
static func _is_critically_wounded_escort(unit: Dictionary) -> bool:
	if str(unit.get("side", "")) != "foe":
		return false
	if bool(unit.get("dead", false)) or bool(unit.get("lost", false)):
		return false
	var hp := int(unit.get("hp", 0))
	var maximum := int(unit.get("max_hp", 0))
	if hp <= 0 or maximum <= 0:
		return false
	if 2 * hp > maximum:
		return false
	return not _has_active_dodge_buff(unit)


## A temporary Dodge veil is active only while it still carries amount and turns. The
## permanent `dodge` stat is never consulted: it is not the authored veil.
static func _has_active_dodge_buff(unit: Dictionary) -> bool:
	var buff: Variant = unit.get("dodge_buff", {})
	if not buff is Dictionary or buff.is_empty():
		return false
	return int(buff.get("amount", 0)) > 0 and int(buff.get("turns", 0)) > 0


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


## Lowest legal rank whose reached target is a living, positive-HP, non-LOST hero already
## carrying a current Mark (0 when none). The passed ability's own masks and the battle's
## read-only legality authority decide what can be reached, so a hanging, lost, dead,
## out-of-reach or unmarked doll is never seized. Never mutates the battle or draws RNG.
static func _nearest_live_marked_rank(
	battle: StitchedRules, actor: Dictionary, ability: Dictionary
) -> int:
	for rank in range(1, 5):
		for target in battle._legal_targets(actor, ability, rank):
			if _is_live_marked_hero(target):
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


## True only for the Spool Snarekeeper's own authored Snare Lash. Every other ability on every
## other foe keeps its existing Mark hunt, FRAY hunt or nearest-legal-rank order.
static func _hunts_marked_fray(actor: Dictionary, ability: Dictionary) -> bool:
	return str(actor.get("id", "")) == "spool_snarekeeper" \
		and str(ability.get("id", "")) == "snare_lash"


## Legal living hero rank carrying both current MARK and the greatest current FRAY; exact FRAY
## ties keep the lower (closer) rank. Only ranks 1-3 are scanned because Snare Lash's authored
## reach stops there, and the passed ability's own target mask still has the final say. Dead,
## lost, unmarked, hanging or unreachable dolls are never candidates. Returns 0 when no legal
## Marked doll remains, which lets the ordinary nearest-legal fallback apply. Read-only: never
## mutates the battle or draws RNG.
static func _most_frayed_marked_legal_rank(
	battle: StitchedRules, actor: Dictionary, ability: Dictionary
) -> int:
	var best_rank := 0
	var best_fray := 0
	for rank in range(1, 4):
		for target in battle._legal_targets(actor, ability, rank):
			if not _is_live_marked_hero(target):
				continue
			var fray := int(target.get("fray", 0))
			if best_rank == 0 or fray > best_fray:
				best_rank = rank
				best_fray = fray
	return best_rank


## A snare may only bite a living doll that still carries its Mark: never a fallen, LOST or
## unmarked hero.
static func _is_live_marked_hero(unit: Dictionary) -> bool:
	return str(unit.get("side", "")) == "hero" \
		and not bool(unit.get("dead", false)) \
		and not bool(unit.get("lost", false)) \
		and int(unit.get("hp", 0)) > 0 \
		and int(unit.get("statuses", {}).get("mark", 0)) > 0


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


## True only for the Scissor Bailiff's own authored Unpick Verdict. Every other ability on
## every other foe keeps its existing Mark, FRAY, pull or nearest-legal-rank order.
static func _hunts_open_seam(actor: Dictionary, ability: Dictionary) -> bool:
	return str(actor.get("id", "")) == "scissor_bailiff" \
		and str(ability.get("id", "")) == "bailiff_unpick"


## Lowest legal hero rank whose worn doll is still worth unpicking: preferably a partly torn
## seam (one or two of head/arms/legs torn, so at least one stays intact), otherwise the first
## doll with any untorn non-torso slot. Only the passed ability's own target authority decides
## what is legal, and only ranks 1 and 2 are asked because Unpick Verdict can reach no further.
## A doll that is lost, fallen, absent, empty or outside that reach is never a candidate, and
## the torso never counts as a seam. Returns 0 when neither shape exists, which keeps the
## ordinary nearest-legal attack (the damage-only possibility) or the original pass/fallback.
## Read-only: it never mutates the battle or draws RNG.
static func _open_seam_rank(
	battle: StitchedRules, actor: Dictionary, ability: Dictionary
) -> int:
	var tearable_rank := 0
	for rank in [1, 2]:
		for target in battle._legal_targets(actor, ability, rank):
			if not _is_live_doll(target):
				continue
			var torn := _torn_limb_count(target)
			if torn >= 1 and torn <= 2 and _has_untorn_limb(target):
				return rank
			if tearable_rank == 0 and _has_untorn_limb(target):
				tearable_rank = rank
	return tearable_rank


## A doll the Bailiff may unpick at all: a living, non-LOST hero still holding its own record.
static func _is_live_doll(unit: Dictionary) -> bool:
	return str(unit.get("side", "")) == "hero" \
		and not bool(unit.get("dead", false)) \
		and not bool(unit.get("lost", false)) \
		and int(unit.get("hp", 0)) > 0


## Torn non-torso seams on one doll: 0 to 3, counted only from equipped head/arms/legs parts
## whose own torn flag is set. The torso is never a seam, so it is never read, and an absent
## part contributes nothing rather than pretending to be torn.
static func _torn_limb_count(unit: Dictionary) -> int:
	var worn: Variant = unit.get("parts", {})
	if not worn is Dictionary:
		return 0
	var torn := 0
	for slot in ["head", "arms", "legs"]:
		var part: Variant = worn.get(slot, {})
		if part is Dictionary and bool(part.get("torn", false)):
			torn += 1
	return torn


## True when the doll still owns at least one equipped, untorn non-torso part, so a further
## Unpick could really tear it. Missing slots are never untorn seams; the torso never counts.
static func _has_untorn_limb(unit: Dictionary) -> bool:
	var worn: Variant = unit.get("parts", {})
	if not worn is Dictionary:
		return false
	for slot in ["head", "arms", "legs"]:
		var part: Variant = worn.get(slot, {})
		if part is Dictionary and not part.is_empty() and not bool(part.get("torn", false)):
			return true
	return false


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

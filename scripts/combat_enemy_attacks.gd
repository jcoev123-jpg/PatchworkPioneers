class_name CombatEnemyAttacks
extends RefCounted
## Resolves a complete phase against fixed party positions, without RNG or scene state.

## One-shot Dodge is an integer token on the hero's statuses: 1 is armed, 0 is
## inert. Spending it removes the key, exactly like CombatStatuses does.
const DODGE_STATUS_KEY := "dodge_next_attack"


func execute_attacks(party: CombatParty, attacks: Array,
		enemy_capacity: int = CombatEnemies.MAX_ENEMIES) -> Dictionary:
	if party == null or not party.is_valid() or enemy_capacity not in [
			CombatEnemies.MAX_ENEMIES, CombatEnemies.OPT_IN_MAX_ENEMIES]:
		return {"ok": false, "events": []}
	var sources: Array[int] = []
	for attack in attacks:
		if not attack is Dictionary:
			return {"ok": false, "events": []}
		var source = attack.get("enemy_position")
		var target = attack.get("target_position")
		var amount = attack.get("amount")
		if not source is int or source < 1 or source > enemy_capacity or source in sources:
			return {"ok": false, "events": []}
		if not target is int or target < 1 or target > CombatParty.PARTY_SIZE:
			return {"ok": false, "events": []}
		if not amount is int or amount < 0:
			return {"ok": false, "events": []}
		# A malformed one-shot Dodge token on the targeted hero fails the whole
		# batch before any hit lands, exactly like a malformed attack.
		if _dodge_token(party, target as int) < 0:
			return {"ok": false, "events": []}
		sources.append(source)
	var ordered := attacks.duplicate(true)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["enemy_position"] < b["enemy_position"])
	var events: Array = []
	for attack in ordered:
		var target_position: int = attack["target_position"]
		# A living hero's armed one-shot Dodge makes this legal attempt miss: the
		# token is spent on the authoritative record, and no HP, Block, retarget
		# or retaliation happens. A skipped (downed) target keeps its token.
		if not party.is_downed(target_position) and _spend_dodge(party, target_position):
			events.append({"enemy_position": attack["enemy_position"],
				"target_position": target_position, "applied": false})
			continue
		var applied := party.apply_damage(target_position, attack["amount"])
		events.append({"enemy_position": attack["enemy_position"],
			"target_position": target_position, "applied": applied})
	return {"ok": true, "events": events}


## 1 when the fixed-slot hero really carries an armed one-shot Dodge, 0 when it
## carries none (absent or inert), -1 when the token is malformed. Read-only.
static func _dodge_token(party: CombatParty, position: int) -> int:
	if party == null or not party.is_valid() \
			or position < 1 or position > CombatParty.PARTY_SIZE:
		return -1
	var raw_statuses: Variant = party._heroes[position - 1].get("statuses", {})
	if not raw_statuses is Dictionary:
		return -1
	var raw_token: Variant = (raw_statuses as Dictionary).get(DODGE_STATUS_KEY, 0)
	if not raw_token is int:
		return -1
	var token: int = raw_token as int
	if token != 0 and token != 1:
		return -1
	return token


## Spends exactly one armed token on the authoritative hero record, so the
## consumed Dodge publishes with the rest of the beat.
static func _spend_dodge(party: CombatParty, position: int) -> bool:
	if _dodge_token(party, position) != 1:
		return false
	var statuses: Dictionary = party._heroes[position - 1]["statuses"]
	statuses.erase(DODGE_STATUS_KEY)
	return true

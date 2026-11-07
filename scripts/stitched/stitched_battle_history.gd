class_name StitchedBattleHistory
extends RefCounted
## Receipts are authoritative; these immutable presentation rows are captured at record time.
const LIMIT := 8

static func entry(receipt: Dictionary, actor_name: String, ability_name: String,
		target_names: Dictionary, hand_name: String = "") -> Dictionary:
	if not bool(receipt.get("ok", false)):
		return {}
	var action := str(receipt.get("action", ""))
	var actor_id := str(receipt.get("actor", ""))
	var headline := actor_name + " · " + action.replace("_", " ").capitalize()
	var detail := ""
	var targets: Array[Dictionary] = []
	match action:
		"ability":
			headline = actor_name + " · " + ability_name
			for result in receipt.get("results", []):
				var target_id := str(result.get("target", ""))
				var target_name := str(target_names.get(target_id, target_id.replace("_", " ").capitalize()))
				var hit := bool(result.get("hit", false))
				var damage := int(result.get("damage", 0))
				var verdict := "MISS" if not hit else (
					"HIT · %d damage" % damage if damage > 0 else "HIT · effect only (no damage)")
				detail += "\n→ %s: %s" % [target_name, verdict]
				targets.append({"id": target_id, "name": target_name,
					"hit": hit, "damage": damage})
		"move":
			detail = "Rank %d → rank %d" % [int(receipt.get("from", 0)), int(receipt.get("to", 0))]
			var swapped := str(receipt.get("swapped", ""))
			if not swapped.is_empty():
				detail += " · swapped with " + str(target_names.get(swapped, swapped))
		"re_tie":
			headline = actor_name + " · Re-tie"
			detail = "Thread repaired"
		"pass":
			headline = actor_name + " · Pass turn"
		"retreat":
			headline = actor_name + " · Retreat"
			detail = "Succeeded" if bool(receipt.get("success", false)) else "Failed; turn spent"
			detail += " (roll %d)" % int(receipt.get("roll", 0))
		"hand":
			headline = "Wren · " + hand_name
			if not actor_id.is_empty():
				detail = "→ " + actor_name
			if bool(receipt.get("failed", false)):
				detail += "\nHands shook; action failed (roll %d)" % int(receipt.get("roll", 0))
			elif receipt.has("effect"):
				var effect: Dictionary = receipt.get("effect", {})
				if effect.has("damage") and int(effect["damage"]) > 0:
					detail += "\n%d damage" % int(effect["damage"])
				elif effect.has("status"):
					detail += "\nApplied " + str(effect["status"]).replace("_", " ")
				elif effect.has("from") and effect.has("to"):
					detail += "\nRank %d → rank %d" % [int(effect["from"]), int(effect["to"])]
		"lost_strings":
			headline = actor_name + " · Lost strings"
		"refused":
			headline = actor_name + " · Refused to act"
	var full := headline + ("\n" + detail if not detail.is_empty() else "")
	return {"actor_id": actor_id, "actor_name": actor_name, "action": action,
		"ability_id": str(receipt.get("ability", "")), "ability_name": ability_name,
		"targets": targets, "text": full}

static func newest(entries: Array[Dictionary]) -> Dictionary:
	var omitted := maxi(0, entries.size() - LIMIT)
	var recent: Array[Dictionary] = []
	for index in range(omitted, entries.size()):
		recent.append(entries[index].duplicate(true))
	return {"rows": recent, "omitted": omitted}

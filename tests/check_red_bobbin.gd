extends SceneTree
func _init():
	pass

func _test_red_bobbin_cuff() -> void:
	var party := CombatParty.new([])
	var heads: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/patches/m05_head_patches.json"))
	var arms: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/patches/m05_arm_support_patches.json"))
	if not heads is Array or not arms is Array:
		return
	var defs := []
	var worn := []
	for h in heads:
		if h is Dictionary and h.get("id") == "bloodstitch_bonnet":
			defs.append({"id": h.get("id"), "slot": "HEAD"})
			worn.append(h.get("id"))
	for a in arms:
		if a is Dictionary and a.get("id") == "red_bobbin_cuff":
			defs.append({"id": a.get("id"), "slot": "ARM"})
			worn.append(a.get("id"))
	
	var torn := RunTornMending.new(party.get_heroes())
	var wardrobe := RunPatchWardrobe.new(party.get_heroes(), worn, defs, 4)
	
	var sew_arm := wardrobe.sew("red_bobbin_cuff", "seamstress", "ARM", "sew1", wardrobe.get_snapshot())
	var sew_head := wardrobe.sew("bloodstitch_bonnet", "seamstress", "HEAD", "sew2", wardrobe.get_snapshot())
	
	var attacks := CombatAttackCards.new()
	var head_rules := CombatM05HeadPatchRules.new()
	head_rules.bind_wardrobe(wardrobe, torn)
	attacks.bind_patch_wardrobe(wardrobe, torn)
	attacks.bind_head_patch_rules(head_rules)
	
	var plain_wardrobe := RunPatchWardrobe.new(party.get_heroes(), worn, defs, 4)
	var plain_attacks := CombatAttackCards.new()
	plain_attacks.bind_patch_wardrobe(plain_wardrobe, torn)
	
	var warden_wardrobe := RunPatchWardrobe.new(party.get_heroes(), worn, defs, 4)
	warden_wardrobe.sew("red_bobbin_cuff", "warden", "ARM", "sew3", warden_wardrobe.get_snapshot())
	var warden_attacks := CombatAttackCards.new()
	warden_attacks.bind_patch_wardrobe(warden_wardrobe, torn)

	var arm_wardrobe := RunPatchWardrobe.new(party.get_heroes(), worn, defs, 4)
	arm_wardrobe.sew("red_bobbin_cuff", "seamstress", "ARM", "sew4", arm_wardrobe.get_snapshot())
	var arm_attacks := CombatAttackCards.new()
	arm_attacks.bind_patch_wardrobe(arm_wardrobe, torn)
	
	var overflow_foes_unpatched := CombatEnemies.new([])
	overflow_foes_unpatched._enemies.append({})
	overflow_foes_unpatched._enemies[0]["statuses"] = {"bleed": CombatStatuses.MAX_INT - 3}

	var stale_wardrobe := RunPatchWardrobe.new(party.get_heroes(), worn, defs, 4)
	stale_wardrobe.sew("red_bobbin_cuff", "seamstress", "ARM", "sew5", stale_wardrobe.get_snapshot())
	var stale_attacks := CombatAttackCards.new()
	stale_attacks.bind_patch_wardrobe(stale_wardrobe, torn)
	stale_wardrobe.sew("red_bobbin_cuff", "warden", "ARM", "sew6", stale_wardrobe.get_snapshot())

	var down_party := CombatParty.new([])
	var down_attacks := CombatAttackCards.new()
	down_attacks.bind_patch_wardrobe(arm_wardrobe, torn)

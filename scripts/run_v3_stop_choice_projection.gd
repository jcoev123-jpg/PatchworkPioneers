class_name RunV3StopChoiceProjection
extends RefCounted
## Scene-free read adapter for the already-generated run map's legal choices.
##
## It projects each current legal source node into a detached descriptor that
## adds a v3_kind: legacy Rest previews as Campfire and legacy Shop as Peddler,
## while every other original kind (including the native v3 Campfire,
## SewingCircle, PatchStall and Unpicker) keeps its own name. The genuine RunMap
## record stays authoritative and untouched.
##
## NOT yet wired into live play: the live map chooser and atlas still consume
## the original "type". The projected Peddler descriptor has no live screen yet.
## This is a pure read: it never generates nodes, advances the route, removes
## legacy nodes, spends resources, or draws from any RNG.

const V3_KIND_ALIASES := {
	"Rest": "Campfire",
	"Shop": "Peddler",
}


## Same order as map.get_legal_choices(). Empty for a null, ungenerated or
## completed map. Every entry is a deep copy of that source node plus v3_kind.
static func project_legal_choices(map: RunMap) -> Array:
	var projected: Array = []
	if map == null or not map.is_generated() or map.is_complete():
		return projected
	for node_id in map.get_legal_choices():
		var source := map.get_node(node_id)
		if source.is_empty():
			continue
		var entry: Dictionary = source.duplicate(true)
		entry["v3_kind"] = v3_kind_for(str(source.get("type", "")))
		projected.append(entry)
	return projected


## Opt-in companion to project_legal_choices(): the same detached entries, in the
## same order, where each of the five split stop kinds (Campfire, SewingCircle,
## Peddler, Unpicker, PatchStall) also gains exactly one stitched_stop_help =
## {"lead": String, "detail": String}. Fights, events, elites, treasure and
## bosses never receive it. The help describes services a stop MAY offer; it is
## not a confirmed offer, price or gain. Pure read: no node advance, no stop
## service call, no spending, no offer sampling and no RNG. Not live-wired yet.
static func project_stitched_legal_choices(map: RunMap) -> Array:
	var projected: Array = project_legal_choices(map)
	for entry in projected:
		var help := stitched_stop_help_for(str(entry.get("v3_kind", "")))
		if not help.is_empty():
			entry["stitched_stop_help"] = help
	return projected


## Fresh, detached {"lead", "detail"} for a split v3 kind, or {} for any other.
static func stitched_stop_help_for(v3_kind: String) -> Dictionary:
	match v3_kind:
		"Campfire":
			# The fray meter is retired from live screens (owner 11-10): no FRAY word unless it is on.
			if not StitchedRules.fray_enabled:
				return {
					"lead": "Campfire: rest the dolls and tend the flame.",
					"detail": "May offer Mend (%d%% max HP for each non-lost doll), Tell Tales or Trim Wick (+%d CANDLE, cap %d), plus eligible part swaps from a satchel of up to %d spare parts. Possible services, not guaranteed gains." % [
						RunCampfireVisit.MEND_HEAL_PERCENT,
						RunCampfireVisit.WICK_CANDLE_RESTORE,
						RunCampfireVisit.STITCHED_CANDLE_MAX,
						RunUnpickerVisit.SATCHEL_MAX,
					],
				}
			return {
				"lead": "Campfire: rest the dolls and tend the flame.",
				"detail": "May offer Mend (%d%% max HP for each non-lost doll), Tell Tales (-%d FRAY each) or Trim Wick (+%d CANDLE, cap %d), plus eligible part swaps from a satchel of up to %d spare parts. Possible services, not guaranteed gains." % [
					RunCampfireVisit.MEND_HEAL_PERCENT,
					RunCampfireVisit.TALES_FRAY_REDUCTION,
					RunCampfireVisit.WICK_CANDLE_RESTORE,
					RunCampfireVisit.STITCHED_CANDLE_MAX,
					RunUnpickerVisit.SATCHEL_MAX,
				],
			}
		"SewingCircle":
			return {
				"lead": "Sewing Circle: sew found patches onto fixed abilities.",
				"detail": "Sew a loose effect patch onto a doll\'s signature ability for scraps, or unsew an existing patch. May also offer mending, a tier upgrade, same-slot spare-part swaps (up to %d spares), and a replacement for a LOST doll. Offers and costs are checked on arrival." % RunUnpickerVisit.SATCHEL_MAX,
			}
		"Peddler":
			return {
				"lead": "Peddler: a travelling seller of oddments.",
				"detail": "May sell a priced part or patch, a +%d CANDLE stub, or a bandage that cures Bleed, subject to the real offers and your gold. Nothing is promised until you arrive." % RunPeddlerVisit.CANDLE_STUB_RESTORE,
			}
		"Unpicker":
			if not StitchedRules.fray_enabled:
				return {
					"lead": "Unpicker: loosen stitches and trade spare parts.",
					"detail": "May unpick one eligible doll at a quoted gold price, or take a spare part for quoted scraps. Quotes are given on arrival.",
				}
			return {
				"lead": "Unpicker: loosen stitches and trade spare parts.",
				"detail": "May unpick one eligible doll for -%d FRAY at a quoted gold price, or take a spare part for quoted scraps. Quotes are given on arrival." % RunUnpickerVisit.CALM_AMOUNT,
			}
		"PatchStall":
			return {
				"lead": "Patch Stall: trinkets and patches for sale.",
				"detail": "May sell a priced trinket or patch, subject to the real offers and your gold. Each hero can wear up to 2 patches.",
			}
	return {}


## Legacy aliases only; native and unknown kinds are returned unchanged.
static func v3_kind_for(kind: String) -> String:
	return str(V3_KIND_ALIASES.get(kind, kind))

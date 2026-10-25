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


## Legacy aliases only; native and unknown kinds are returned unchanged.
static func v3_kind_for(kind: String) -> String:
	return str(V3_KIND_ALIASES.get(kind, kind))

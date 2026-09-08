class_name Corpse
extends RefCounted

var id = 0
var kind = "corpse"
var owner = 0
var def_id = ""
var x = 0.0
var y = 0.0
var t = Cfg.CORPSE_LIFETIME
var dead = false
var flying = false
var radius = 8.0

func _init(g, own: int, did: String, px: float, py: float, fly: bool) -> void:
	id = g.next_id(); owner = own; def_id = did; x = px; y = py; flying = fly

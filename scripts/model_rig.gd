extends Node3D

@export var hidden_parts: PackedStringArray
@export var skin: Texture2D
@export var clips := {"idle": "Idle", "walk": "Walking_A", "run": "Running_A", "work": "Interact", "pray": "Spellcasting"}
@export var head_bone := "head"
@export var head_items: Array[NodePath]
@export var hand_bone := "handslot.r"
@export var hand_items: Array[NodePath]

const BLEND := 0.25

var _anim: AnimationPlayer
var _state := ""


func _ready() -> void:
	for part in hidden_parts:
		var n := find_child(part, true, false) as Node3D
		if n:
			n.visible = false
	if skin:
		_apply_skin()
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton:
		_attach(skeleton, head_bone, head_items)
		_attach(skeleton, hand_bone, hand_items)
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		for clip in clips.values():
			if _anim.has_animation(clip):
				_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	act("idle")


func act(state: String) -> void:
	if state == _state or not _anim:
		return
	var clip: String = clips.get(state, clips.get("idle", ""))
	if _anim.has_animation(clip):
		_state = state
		_anim.play(clip, BLEND)


func _apply_skin() -> void:
	for m: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if m.owner == self:
			continue
		for i in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(i) as StandardMaterial3D
			if mat:
				mat = mat.duplicate()
				mat.albedo_texture = skin
				m.set_surface_override_material(i, mat)


func _attach(skeleton: Skeleton3D, bone: String, items: Array[NodePath]) -> void:
	if items.is_empty() or skeleton.find_bone(bone) < 0:
		return
	var slot := BoneAttachment3D.new()
	slot.bone_name = bone
	skeleton.add_child(slot)
	for path in items:
		var item := get_node_or_null(path) as Node3D
		if item:
			item.reparent(slot, false)

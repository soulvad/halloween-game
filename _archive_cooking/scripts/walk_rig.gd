extends Node3D
## Box-man rig that plays the mocap "2 steps" walk reference (MC_walk notebook, G1 retarget).
## Curves are sampled by hand from the notebook's reference plot, 20 points per cycle,
## phase 0 = left heel strike; the right side is the left shifted by half a cycle.
## Angles are G1 pitch (rad, + = limb swings back).

# shortcut: curves digitized from the plot image, not loaded from walk_reference_2steps.npz; load the npz if exact data is needed.
const HIP := [-0.51, -0.49, -0.47, -0.44, -0.36, -0.22, -0.12, -0.04, 0.0, 0.01,
		0.04, 0.065, -0.02, -0.13, -0.25, -0.35, -0.43, -0.48, -0.49, -0.50]
const KNEE := [0.05, 0.15, 0.24, 0.33, 0.33, 0.25, 0.19, 0.15, 0.15, 0.18,
		0.24, 0.36, 0.60, 0.85, 1.01, 1.0, 0.85, 0.6, 0.30, 0.06]
const ANKLE := [-0.14, -0.13, -0.06, -0.05, -0.13, -0.16, -0.21, -0.25, -0.31, -0.37,
		-0.39, -0.33, -0.10, 0.11, 0.03, -0.08, -0.15, -0.19, -0.18, -0.15]
const SHOULDER := [0.59, 0.61, 0.60, 0.56, 0.49, 0.41, 0.33, 0.24, 0.16, 0.08,
		0.06, 0.08, 0.13, 0.21, 0.28, 0.36, 0.44, 0.50, 0.55, 0.57]
const SHOULDER_MEAN := 0.33  ## retarget offset; removed so arms hang down at rest
const TORSO_LEAN := 0.05  ## ~3 deg forward, like PELVIS_PITCH_TARGET_DEG

const THIGH := 0.45
const SHIN := 0.42
const FOOT_H := 0.08
const HIP_W := 0.13
## Reference: 0.907 m per 2 steps for G1 (leg ~0.75 m); scaled to this leg length.
const STRIDE := 0.907 * (THIGH + SHIN + FOOT_H) / 0.75
# shortcut: cadence capped so the 7 m/s player does not blur its legs; feet slide above ~2.4 m/s.
const MAX_CYCLES_PER_SEC := 1.9

var phase := 0.0
var weight := 0.0  ## 0 = standing pose, 1 = full walk
var _j := {}  ## joint name -> Node3D pivot


func _ready() -> void:
	var skin := Color(1, 0.55, 0.1)
	var dark := Color(0.15, 0.15, 0.18)
	var pelvis := _pivot("pelvis", self, Vector3.ZERO)
	_part(pelvis, Vector3(0.34, 0.16, 0.22), Vector3(0, 0.02, 0), dark)
	var torso := _pivot("torso", pelvis, Vector3(0, 0.08, 0))
	_part(torso, Vector3(0.42, 0.5, 0.26), Vector3(0, 0.25, 0), skin)
	_part(torso, Vector3(0.24, 0.24, 0.24), Vector3(0, 0.68, 0), skin)
	_part(torso, Vector3(0.2, 0.07, 0.06), Vector3(0, 0.7, -0.13), Color(0.1, 0.1, 0.1))  # visor
	for s in ["l", "r"]:
		var x := -HIP_W if s == "l" else HIP_W  # Godot: forward = -Z, left = -X
		var hip := _pivot(s + "_hip", pelvis, Vector3(x, 0, 0))
		_part(hip, Vector3(0.15, THIGH, 0.15), Vector3(0, -THIGH / 2, 0), dark)
		var knee := _pivot(s + "_knee", hip, Vector3(0, -THIGH, 0))
		_part(knee, Vector3(0.12, SHIN, 0.12), Vector3(0, -SHIN / 2, 0), dark)
		var ankle := _pivot(s + "_ankle", knee, Vector3(0, -SHIN, 0))
		_part(ankle, Vector3(0.13, FOOT_H, 0.26), Vector3(0, -FOOT_H / 2, -0.06), Color(0.1, 0.1, 0.1))
		var sh := _pivot(s + "_shoulder", torso, Vector3(x * 2, 0.47, 0))
		_part(sh, Vector3(0.1, 0.3, 0.1), Vector3(0, -0.15, 0), skin)
		var elbow := _pivot(s + "_elbow", sh, Vector3(0, -0.3, 0))
		_part(elbow, Vector3(0.09, 0.28, 0.09), Vector3(0, -0.14, 0), skin)
	_pose()


func _process(delta: float) -> void:
	var body := get_parent() as CharacterBody3D
	var speed := Vector2(body.velocity.x, body.velocity.z).length() if body else 0.0
	weight = move_toward(weight, 1.0 if speed > 0.1 else 0.0, 4.0 * delta)
	phase = fposmod(phase + minf(speed / STRIDE, MAX_CYCLES_PER_SEC) * delta, 1.0)
	_pose()


func _pose() -> void:
	var drop := 0.0
	for s in ["l", "r"]:
		var p := fposmod(phase + (0.0 if s == "l" else 0.5), 1.0)
		var hip := sample(HIP, p) * weight
		var knee := sample(KNEE, p) * weight
		# G1 pitch is about +Y(left); here left is -X, so rotation.x = -pitch
		_j[s + "_hip"].rotation.x = -hip
		_j[s + "_knee"].rotation.x = -knee
		_j[s + "_ankle"].rotation.x = -sample(ANKLE, p) * weight
		_j[s + "_shoulder"].rotation.x = -(sample(SHOULDER, p) - SHOULDER_MEAN) * weight
		_j[s + "_elbow"].rotation.x = 0.35 * weight  # elbow bent forward while walking
		drop = maxf(drop, THIGH * cos(hip) + SHIN * cos(hip + knee) + FOOT_H)
	_j.pelvis.position.y = drop  # the longer (stance) leg stands on the floor
	_j.torso.rotation.x = -TORSO_LEAN * weight


## Periodic Catmull-Rom interpolation of a curve sampled evenly over phase [0, 1).
static func sample(curve: Array, p: float) -> float:
	var n := curve.size()
	var f := fposmod(p, 1.0) * n
	var i := int(f)
	var t := f - i
	var a: float = curve[(i - 1 + n) % n]
	var b: float = curve[i]
	var c: float = curve[(i + 1) % n]
	var d: float = curve[(i + 2) % n]
	return 0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (3 * b - a - 3 * c + d) * t * t * t)


func _pivot(n: String, parent: Node3D, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.name = n
	j.position = pos
	parent.add_child(j)
	_j[n] = j
	return j


func _part(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var m := GameState._box(size, color)
	m.position = pos
	parent.add_child(m)

"""Normalize the selected Tripo board to the CloudGate 10x6x0.6m contract."""

import math
import os

import bpy
from mathutils import Vector


PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(
    PROJECT,
    "assets",
    "table",
    "3d",
    "source",
    "cloudgate_battle_board_v02_tripo_source.glb",
)
OUTPUT = os.path.join(
    PROJECT,
    "assets",
    "table",
    "3d",
    "cloudgate_battle_board_v02_candidate.glb",
)
TARGET = Vector((10.0, 6.0, 0.6))
TOLERANCE = 0.02


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for block in list(collection):
            collection.remove(block)


def mesh_objects():
    return [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]


def world_bounds(objects):
    minimum = Vector((math.inf, math.inf, math.inf))
    maximum = Vector((-math.inf, -math.inf, -math.inf))
    triangles = 0
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in objects:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        if mesh is None:
            continue
        mesh.calc_loop_triangles()
        triangles += len(mesh.loop_triangles)
        for vertex in mesh.vertices:
            point = obj.matrix_world @ vertex.co
            minimum.x = min(minimum.x, point.x)
            minimum.y = min(minimum.y, point.y)
            minimum.z = min(minimum.z, point.z)
            maximum.x = max(maximum.x, point.x)
            maximum.y = max(maximum.y, point.y)
            maximum.z = max(maximum.z, point.z)
        evaluated.to_mesh_clear()
    return minimum, maximum, triangles


def select_only(objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]


def apply_to_objects(objects, translation=Vector((0, 0, 0)), scale=Vector((1, 1, 1))):
    for obj in objects:
        obj.location = Vector((
            (obj.location.x + translation.x) * scale.x,
            (obj.location.y + translation.y) * scale.y,
            (obj.location.z + translation.z) * scale.z,
        ))
        obj.scale = Vector((obj.scale.x * scale.x, obj.scale.y * scale.y, obj.scale.z * scale.z))
    select_only(objects)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.context.view_layer.update()


def normalize():
    if not os.path.exists(SOURCE):
        raise FileNotFoundError(SOURCE)

    clear_scene()
    bpy.ops.import_scene.gltf(filepath=SOURCE)
    objects = mesh_objects()
    if not objects:
        raise RuntimeError("No mesh objects found in source GLB")

    source_min, source_max, triangles = world_bounds(objects)
    source_size = source_max - source_min
    print(f"[BOARD_V02] source min={source_min} max={source_max} size={source_size} tris={triangles}")

    # Tripo source has its long footprint axis on Blender Y. Rotate the complete
    # imported hierarchy 90 degrees around Z so the canonical long axis is X.
    for obj in objects:
        obj.rotation_euler.rotate_axis("Z", math.radians(-90.0))
    bpy.context.view_layer.update()

    rotated_min, rotated_max, _ = world_bounds(objects)
    rotated_size = rotated_max - rotated_min
    center = Vector(((rotated_min.x + rotated_max.x) * 0.5, (rotated_min.y + rotated_max.y) * 0.5, 0.0))
    translation = Vector((-center.x, -center.y, -rotated_min.z))
    scale = Vector((
        TARGET.x / max(rotated_size.x, 1e-6),
        TARGET.y / max(rotated_size.y, 1e-6),
        TARGET.z / max(rotated_size.z, 1e-6),
    ))
    apply_to_objects(objects, translation, scale)

    final_min, final_max, final_triangles = world_bounds(objects)
    final_size = final_max - final_min
    print(f"[BOARD_V02] normalized min={final_min} max={final_max} size={final_size} tris={final_triangles}")

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    select_only(objects)
    bpy.ops.export_scene.gltf(
        filepath=OUTPUT,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_image_format="JPEG",
        export_jpeg_quality=92,
    )
    print(f"[BOARD_V02] exported={OUTPUT}")

    # Fresh re-import is the actual export contract check.
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=OUTPUT)
    check_objects = mesh_objects()
    check_min, check_max, check_triangles = world_bounds(check_objects)
    check_size = check_max - check_min
    expected_blender = TARGET
    deltas = Vector((
        abs(check_size.x - expected_blender.x),
        abs(check_size.y - expected_blender.y),
        abs(check_size.z - expected_blender.z),
    ))
    passed = max(deltas) <= TOLERANCE and abs(check_min.z) <= TOLERANCE
    print(f"[BOARD_V02] reimport min={check_min} max={check_max} size={check_size} tris={check_triangles}")
    print(f"[BOARD_V02] validation={'PASS' if passed else 'FAIL'} deltas={deltas}")
    if not passed:
        raise RuntimeError("Normalized GLB failed Blender contract validation")


if __name__ == "__main__":
    normalize()


"""Import the original CloudGate board without rotating or distorting its axes."""

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
    "cloudgate_battle_board_v03_original.glb",
)
OUTPUT = os.path.join(
    PROJECT,
    "assets",
    "table",
    "3d",
    "cloudgate_battle_board_v03.glb",
)
UNIFORM_SCALE = 10.0
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


def import_preserving_axes():
    if not os.path.exists(SOURCE):
        raise FileNotFoundError(SOURCE)

    clear_scene()
    bpy.ops.import_scene.gltf(filepath=SOURCE)
    objects = mesh_objects()
    if not objects:
        raise RuntimeError("No mesh objects found in source GLB")

    source_min, source_max, triangles = world_bounds(objects)
    source_size = source_max - source_min
    print(f"[BOARD_V03] source min={source_min} max={source_max} size={source_size} tris={triangles}")

    # Preserve the original X/Y footprint axes. Only center, place the bottom
    # at Z=0, and apply one identical scale factor to every axis.
    center_xy = Vector((
        (source_min.x + source_max.x) * 0.5,
        (source_min.y + source_max.y) * 0.5,
        source_min.z,
    ))
    for obj in objects:
        obj.location = (obj.location - center_xy) * UNIFORM_SCALE
        obj.scale *= UNIFORM_SCALE
    select_only(objects)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.context.view_layer.update()

    final_min, final_max, final_triangles = world_bounds(objects)
    final_size = final_max - final_min
    expected = source_size * UNIFORM_SCALE
    deltas = Vector((
        abs(final_size.x - expected.x),
        abs(final_size.y - expected.y),
        abs(final_size.z - expected.z),
    ))
    passed = max(deltas) <= TOLERANCE and abs(final_min.z) <= TOLERANCE
    print(f"[BOARD_V03] final min={final_min} max={final_max} size={final_size} tris={final_triangles}")
    print(f"[BOARD_V03] axes_preserved={final_size.y > final_size.x} uniform_scale={UNIFORM_SCALE}")
    print(f"[BOARD_V03] validation={'PASS' if passed else 'FAIL'} deltas={deltas}")
    if not passed:
        raise RuntimeError("Axis-preserving GLB validation failed")

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
    print(f"[BOARD_V03] exported={OUTPUT}")


if __name__ == "__main__":
    import_preserving_axes()

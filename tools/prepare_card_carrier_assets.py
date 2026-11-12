"""
Phase 22E-0R3: Card Carrier Asset Preparation
Key fix: Remove origin_set(). Use direct location offset then apply to bake.
This guarantees min Z = 0 in the exported GLB (min Y = 0 in Godot after export_yup).
"""
import bpy, os
from mathutils import Vector

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC  = os.path.join(PROJECT, "assets", "models", "card_carrier", "source")
OUT  = os.path.join(PROJECT, "assets", "models", "card_carrier", "runtime")
os.makedirs(OUT, exist_ok=True)

# (src, out_name, role, tris, (target_x, target_y), target_z, uniform)
JOBS = [
    ("stone_platform.glb",          "card_carrier_base",   "Base",          5000, (1.08, 1.42), 0.10, True),
    ("ornate_metal_frame.glb",      "card_carrier_frame",  "Frame",         5000, (1.08, 1.42), 0.08, False),
    ("futuristic_portal_frame.glb", "card_carrier_glow",   "GlowChannels",  3000, (0.90, 1.20), 0.04, True),
    ("portal_platform.glb",         "card_carrier_socket", "SocketVisual",  5000, (0.56, 0.56), 0.04, True),
]
TEX_MAX = 2048


def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for block in list(bpy.data.meshes):    bpy.data.meshes.remove(block)
    for block in list(bpy.data.materials): bpy.data.materials.remove(block)
    for block in list(bpy.data.images):    bpy.data.images.remove(block)


def world_bounds(obj):
    """Return (min_vec, max_vec, tris) in Blender world space using matrix_world.
    This is the ONLY bounds function — no origin_set interference."""
    dg = bpy.context.evaluated_depsgraph_get()
    eo = obj.evaluated_get(dg)
    m = eo.to_mesh()
    mn = Vector((1e9, 1e9, 1e9))
    mx = Vector((-1e9, -1e9, -1e9))
    tris = 0
    if m:
        tris = len(m.polygons)
        for v in m.vertices:
            wv = obj.matrix_world @ v.co
            mn.x = min(mn.x, wv.x); mn.y = min(mn.y, wv.y); mn.z = min(mn.z, wv.z)
            mx.x = max(mx.x, wv.x); mx.y = max(mx.y, wv.y); mx.z = max(mx.z, wv.z)
    eo.to_mesh_clear()
    for c in obj.children_recursive:
        if c.type == 'MESH':
            ce = c.evaluated_get(dg); cm = ce.to_mesh()
            if cm:
                tris += len(cm.polygons)
                for v in cm.vertices:
                    wv = c.matrix_world @ v.co
                    mn.x = min(mn.x, wv.x); mn.y = min(mn.y, wv.y); mn.z = min(mn.z, wv.z)
                    mx.x = max(mx.x, wv.x); mx.y = max(mx.y, wv.y); mx.z = max(mx.z, wv.z)
                ce.to_mesh_clear()
    return mn, mx, tris


def decimate(obj, target):
    _, _, cur = world_bounds(obj)
    if cur <= target:
        print(f"  Tris: {cur} OK")
        return
    r = target / max(1, cur)
    print(f"  Decimate: {cur} -> ~{target} (r={r:.3f})")
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new(name="Dec", type='DECIMATE')
    mod.ratio = r; mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier="Dec")
    print(f"  After: {world_bounds(obj)[2]} tris")


def resize_tex(obj):
    seen = set()
    for o in [obj] + list(obj.children_recursive):
        if o.type != 'MESH': continue
        for ms in o.material_slots:
            if not ms.material or ms.material.name in seen: continue
            seen.add(ms.material.name)
            if ms.material.node_tree:
                for n in ms.material.node_tree.nodes:
                    if n.type == 'TEX_IMAGE' and n.image:
                        img = n.image
                        if max(img.size) > TEX_MAX:
                            s = TEX_MAX / max(img.size)
                            img.scale(int(img.size[0]*s), int(img.size[1]*s))
                            print(f"  Tex: {img.size[0]}x{img.size[1]}")


def process(src_name, cfg):
    out_name, role, tris_target, (tx, ty), tz, uniform = cfg
    path = os.path.join(SRC, src_name)
    if not os.path.exists(path):
        print(f"\nSKIP {role}: not found"); return None

    print(f"\n{'='*50}")
    print(f"PROCESS: {role} ({src_name})")
    print(f"  Target: {tris_target} tris, XY=({tx:.2f},{ty:.2f}), Z={tz:.2f}")

    clear_scene()
    bpy.ops.import_scene.gltf(filepath=path)
    root = None
    for obj in bpy.context.scene.objects:
        if obj.parent is None: root = obj; break
    if not root and bpy.context.scene.objects:
        root = bpy.context.scene.objects[0]
    if not root:
        print("  ERROR: no import"); return None

    # ── Initial world bounds ──
    mn, mx, tris = world_bounds(root)
    sx, sy, sz = mx.x-mn.x, mx.y-mn.y, mx.z-mn.z
    print(f"  Source: min={mn} max={mx}")
    print(f"  Source: X={sx:.4f} Y={sy:.4f} Z={sz:.4f}  tris={tris}")

    # ── Step 1: Position mesh in world space ──
    # In Blender Z-up: XY=footprint, Z=height
    # Target: min X = -sizeX/2, max X = +sizeX/2 (centered)
    #         min Y = -sizeY/2, max Y = +sizeY/2 (centered)
    #         min Z = 0 (bottom at ground)
    cx = (mn.x + mx.x) / 2  # current center X
    cy = (mn.y + mx.y) / 2  # current center Y
    # Move object so center is at origin, bottom is at Z=0
    root.location.x -= cx
    root.location.y -= cy
    root.location.z -= mn.z  # bottom to Z=0
    bpy.context.view_layer.update()

    # Verify after move
    mn2, mx2, _ = world_bounds(root)
    print(f"  After position: min={mn2} max={mx2}")
    print(f"  min Z after position: {mn2.z:.6f} (target: 0.0)")

    # ── Step 2: Apply LOCATION only (bake world position into mesh) ──
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    bpy.context.view_layer.update()

    # Verify after apply location
    mn3, mx3, _ = world_bounds(root)
    print(f"  After apply location: min={mn3} max={mx3}")
    print(f"  min Z after apply: {mn3.z:.6f}")
    cur_x, cur_y, cur_z = mx3.x-mn3.x, mx3.y-mn3.y, mx3.z-mn3.z

    # ── Step 3: Scale to target ──
    if uniform:
        sc = min(tx/max(0.001,cur_x), ty/max(0.001,cur_y)) * 0.95
        root.scale = Vector((sc, sc, sc))
        print(f"  Uniform scale: {sc:.4f}")
    else:
        root.scale.x = (tx / max(0.001, cur_x)) * 0.95
        root.scale.y = (ty / max(0.001, cur_y)) * 0.95
        root.scale.z = (tz / max(0.001, cur_z)) * 0.95 if cur_z > 0.001 else 1.0
        print(f"  Non-uniform: sx={root.scale.x:.4f} sy={root.scale.y:.4f} sz={root.scale.z:.4f}")
    bpy.context.view_layer.update()

    # ── Step 4: Apply SCALE (bake scaling into mesh) ──
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.context.view_layer.update()

    mn4, mx4, _ = world_bounds(root)
    fs = mx4 - mn4
    print(f"  After apply scale: min={mn4} max={mx4}")
    print(f"  After apply scale: X={fs.x:.4f} Y={fs.y:.4f} Z={fs.z:.4f}")

    # ── CRITICAL: Re-verify min Z=0 after scale ──
    # Uniform scale may have moved min Z away from 0 if not centered at origin
    if abs(mn4.z) > 0.001:
        print(f"  WARNING: min Z drifted to {mn4.z:.6f}, correcting...")
        root.location.z -= mn4.z
        bpy.context.view_layer.update()
        # Apply correction
        bpy.ops.object.select_all(action='DESELECT')
        root.select_set(True)
        bpy.context.view_layer.objects.active = root
        bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
        bpy.context.view_layer.update()
        mn5, mx5, _ = world_bounds(root)
        print(f"  After Z correction: min Z={mn5.z:.6f}")

    # ── Step 5: Re-center XY after scale (scale may have shifted center if not symmetric) ──
    mn6, mx6, _ = world_bounds(root)
    cx6 = (mn6.x + mx6.x) / 2
    cy6 = (mn6.y + mx6.y) / 2
    if abs(cx6) > 0.001 or abs(cy6) > 0.001:
        print(f"  XY center drifted to ({cx6:.4f},{cy6:.4f}), re-centering...")
        root.location.x -= cx6
        root.location.y -= cy6
        bpy.context.view_layer.update()
        bpy.ops.object.select_all(action='DESELECT')
        root.select_set(True)
        bpy.context.view_layer.objects.active = root
        bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
        bpy.context.view_layer.update()

    # ── Step 6: Decimate ──
    decimate(root, tris_target)

    # ── Step 7: Textures ──
    resize_tex(root)

    # ── FINAL verification ──
    fmn, fmx, ftris = world_bounds(root)
    fs = fmx - fmn
    print(f"  FINAL: {ftris} tris")
    print(f"  FINAL bounds: min={fmn} max={fmx}")
    print(f"  FINAL size: X={fs.x:.4f} Y={fs.y:.4f} Z={fs.z:.4f}")
    print(f"  FINAL min Z: {fmn.z:.6f} (must be 0.0)")

    # Export with export_yup=true for Godot Y-up conversion
    out_path = os.path.join(OUT, out_name + ".glb")
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=out_path, export_format='GLB', use_selection=True,
        export_apply=True, export_yup=True,
        export_image_format='JPEG', export_jpeg_quality=90,
    )
    print(f"  Exported: {out_path}")
    return {'role': role, 'tris': ftris, 'size': fs, 'min_z': fmn.z}


def main():
    print("=" * 60)
    print("Phase 22E-0R3: Card Carrier (Origin Fix)")
    results = []
    total = 0
    for job in JOBS:
        r = process(job[0], job[1:])
        if r:
            results.append(r); total += r['tris']
    print(f"\n{'='*60}\nSUMMARY")
    for r in results:
        print(f"  {r['role']:15s}: {r['tris']:>5d} tris  Z=[{r['size'].x:.3f},{r['size'].y:.3f},{r['size'].z:.3f}]  minZ={r['min_z']:.6f}")
    print(f"  {'TOTAL':15s}: {total:>5d} tris  {'PASS' if total<=20000 else 'FAIL'}")

if __name__ == "__main__":
    main()

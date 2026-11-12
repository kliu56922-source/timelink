extends RefCounted
## Pure caller-owned reservation advice; no game rule, placement or permanent blacklist.
static func choose(rows: Array,reserved: Array) -> Dictionary:
	for row: Dictionary in rows:
		var quote: Dictionary=row.get("quote",{})
		if not quote.get("ok",false):continue
		var structure: Dictionary=quote.get("layout",{}).get("_structure_plan",{}).get("structure",{})
		var cells: Array=structure.get("footprint_cells",[quote.get("cell")])
		var blocked:=false
		for cell: Variant in cells:
			if reserved.has(cell):blocked=true;break
		if not blocked:return quote.duplicate(true)
	return {}

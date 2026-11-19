## Облегчение .glb перед тем, как положить модель в проект: текстуры внутри файла уменьшаются до нужного размера
## и пережимаются в JPEG; сетка, материалы и всё остальное остаются байт в байт.
## Зачем: модель с сайта Tripo весит 9–21 МБ, из них до 16 МБ — одна PNG-текстура 2048–4096; игра всё равно
## импортирует текстуры не крупнее 1024 (process/size_limit), так что в git лишнее только раздувает репозиторий.
##   $G --headless --path godot --script res://scripts/glbslim.gd -- <вход.glb> <выход.glb> [размер=1024] [качество=0.86]
## Печатает «GLBSLIM <файл>: было … КБ → стало … КБ».
extends SceneTree

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		print("GLBSLIM: нужны <вход.glb> <выход.glb> [размер] [качество]")
		quit(1)
		return
	var limit := int(a[2]) if a.size() > 2 else 1024
	var q := float(a[3]) if a.size() > 3 else 0.86
	quit(0 if slim(a[0], a[1], limit, q) else 1)

func slim(src: String, dst: String, limit: int, quality: float) -> bool:
	var raw := FileAccess.get_file_as_bytes(src)
	if raw.size() < 20 or raw.slice(0, 4).get_string_from_ascii() != "glTF":
		print("GLBSLIM ОШИБКА: не .glb — ", src)
		return false
	var jlen := raw.decode_u32(12)
	var json = JSON.parse_string(raw.slice(20, 20 + jlen).get_string_from_utf8())
	if not (json is Dictionary):
		print("GLBSLIM ОШИБКА: не читается описание — ", src)
		return false
	var bin_at := 20 + jlen + 8
	var bin := raw.slice(bin_at, bin_at + raw.decode_u32(20 + jlen))
	var views: Array = json.get("bufferViews", [])
	# какие куски двоичной части — картинки, и чем их заменить
	var swap := {}
	for im in json.get("images", []):
		if not im.has("bufferView"):
			continue
		var vi := int(im["bufferView"])
		var v: Dictionary = views[vi]
		var data := bin.slice(int(v.get("byteOffset", 0)), int(v.get("byteOffset", 0)) + int(v["byteLength"]))
		var img := Image.new()
		var err := img.load_png_from_buffer(data) if String(im.get("mimeType", "")) == "image/png" else img.load_jpg_from_buffer(data)
		if err != OK:
			print("GLBSLIM   картинка «%s» не разобрана — оставлена как есть" % im.get("name", "?"))
			continue
		var was := img.get_size()
		if maxi(was.x, was.y) > limit:
			var k := float(limit) / float(maxi(was.x, was.y))
			img.resize(maxi(1, roundi(was.x * k)), maxi(1, roundi(was.y * k)), Image.INTERPOLATE_LANCZOS)
		if img.detect_alpha() != Image.ALPHA_NONE:
			swap[vi] = img.save_png_to_buffer()            # прозрачность JPEG не хранит
			im["mimeType"] = "image/png"
		else:
			img.convert(Image.FORMAT_RGB8)
			swap[vi] = img.save_jpg_to_buffer(quality)
			im["mimeType"] = "image/jpeg"
		print("GLBSLIM   %s: %dx%d %d КБ → %dx%d %d КБ" % [im.get("name", "?"), was.x, was.y, data.size() / 1024, img.get_width(), img.get_height(), (swap[vi] as PackedByteArray).size() / 1024])
	# двоичная часть заново: куски в прежнем порядке, картинки — новые, выравнивание по 4 байта
	var out := PackedByteArray()
	var order: Array = range(views.size())
	order.sort_custom(func(x, y): return int(views[x].get("byteOffset", 0)) < int(views[y].get("byteOffset", 0)))
	for vi in order:
		var v: Dictionary = views[vi]
		if int(v.get("buffer", 0)) != 0:
			continue
		var data: PackedByteArray = swap[vi] if swap.has(vi) else bin.slice(int(v.get("byteOffset", 0)), int(v.get("byteOffset", 0)) + int(v["byteLength"]))
		while out.size() % 4 != 0:
			out.append(0)
		v["byteOffset"] = out.size()
		v["byteLength"] = data.size()
		out.append_array(data)
	while out.size() % 4 != 0:
		out.append(0)
	(json["buffers"] as Array)[0]["byteLength"] = out.size()
	var jb := JSON.stringify(json).to_utf8_buffer()
	while jb.size() % 4 != 0:
		jb.append(0x20)
	var res := PackedByteArray()
	res.resize(12 + 8)
	res.encode_u32(0, 0x46546C67)
	res.encode_u32(4, 2)
	res.encode_u32(8, 12 + 8 + jb.size() + 8 + out.size())
	res.encode_u32(12, jb.size())
	res.encode_u32(16, 0x4E4F534A)
	res.append_array(jb)
	var bh := PackedByteArray()
	bh.resize(8)
	bh.encode_u32(0, out.size())
	bh.encode_u32(4, 0x004E4942)
	res.append_array(bh)
	res.append_array(out)
	var f := FileAccess.open(dst, FileAccess.WRITE)
	if f == null:
		print("GLBSLIM ОШИБКА: не записать — ", dst)
		return false
	f.store_buffer(res)
	f.close()
	print("GLBSLIM %s: было %d КБ → стало %d КБ" % [dst.get_file(), raw.size() / 1024, res.size() / 1024])
	return true

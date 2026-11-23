## Defensive ID3v2.3/v2.4 reader used by the iPod importer.
## It intentionally reads only the fields the game needs and never trusts tag sizes.
extends RefCounted

const MAX_TAG_SIZE := 64 * 1024 * 1024
const MAX_COVER_SIZE := 16 * 1024 * 1024


static func read(path: String) -> Dictionary:
	var result := {"title": "", "artist": "", "album": "", "cover_bytes": PackedByteArray(), "cover_ext": ""}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 10:
		return result
	var header := file.get_buffer(10)
	if header.size() != 10 or header.slice(0, 3).get_string_from_ascii() != "ID3":
		return result
	var version := int(header[3])
	if version not in [3, 4]:
		return result
	var tag_size := _syncsafe(header, 6)
	if tag_size < 0 or tag_size > MAX_TAG_SIZE or tag_size > file.get_length() - 10:
		return result
	var tag := file.get_buffer(tag_size)
	if (int(header[5]) & 0x80) != 0:
		tag = _remove_unsynchronization(tag)
	var offset := 0
	if (int(header[5]) & 0x40) != 0:
		offset = _extended_header_end(tag, version)
		if offset < 0:
			return result
	while offset + 10 <= tag.size():
		var frame_id := tag.slice(offset, offset + 4).get_string_from_ascii()
		if tag[offset] == 0 or not _valid_frame_id(frame_id):
			break
		var frame_size := _syncsafe(tag, offset + 4) if version == 4 else _uint32_be(tag, offset + 4)
		var flags := (int(tag[offset + 8]) << 8) | int(tag[offset + 9])
		offset += 10
		if frame_size <= 0 or frame_size > tag.size() - offset:
			break
		var payload := tag.slice(offset, offset + frame_size)
		offset += frame_size
		# Compressed and encrypted frames need a full codec and are deliberately skipped.
		if (version == 3 and (flags & 0x00c0) != 0) or (version == 4 and (flags & 0x000c) != 0):
			continue
		if version == 3 and (flags & 0x0020) != 0 and not payload.is_empty():
			payload = payload.slice(1)
		if version == 4:
			if (flags & 0x0040) != 0 and not payload.is_empty():
				payload = payload.slice(1)
			if (flags & 0x0001) != 0 and payload.size() >= 4:
				payload = payload.slice(4)
			if (flags & 0x0002) != 0:
				payload = _remove_unsynchronization(payload)
		if payload.is_empty():
			continue
		match frame_id:
			"TIT2":
				result["title"] = _decode_text_frame(payload)
			"TPE1":
				result["artist"] = _decode_text_frame(payload)
			"TALB":
				result["album"] = _decode_text_frame(payload)
			"APIC":
				if (result["cover_bytes"] as PackedByteArray).is_empty():
					_parse_apic(payload, result)
	return result


static func _parse_apic(data: PackedByteArray, result: Dictionary) -> void:
	if data.size() < 5:
		return
	var encoding := int(data[0])
	var mime_end := _find_zero(data, 1, 1)
	if mime_end < 0 or mime_end + 2 >= data.size():
		return
	var _mime := data.slice(1, mime_end).get_string_from_ascii().to_lower()
	var description_start := mime_end + 2 # NUL followed by picture type.
	var terminator_width := 2 if encoding in [1, 2] else 1
	var description_end := _find_zero(data, description_start, terminator_width)
	if description_end < 0:
		return
	var image_start := description_end + terminator_width
	if image_start >= data.size() or data.size() - image_start > MAX_COVER_SIZE:
		return
	var bytes := data.slice(image_start)
	var ext := ""
	if bytes.size() >= 8 and bytes[0] == 0x89 and bytes[1] == 0x50 and bytes[2] == 0x4e and bytes[3] == 0x47 and bytes[4] == 0x0d and bytes[5] == 0x0a and bytes[6] == 0x1a and bytes[7] == 0x0a:
		ext = "png"
	elif bytes.size() >= 3 and bytes[0] == 0xff and bytes[1] == 0xd8 and bytes[2] == 0xff:
		ext = "jpg"
	# MIME is advisory; accepting it without a valid signature would cache corrupt data.
	if ext != "":
		result["cover_bytes"] = bytes
		result["cover_ext"] = ext


static func _decode_text_frame(data: PackedByteArray) -> String:
	if data.size() < 2:
		return ""
	var encoding := int(data[0])
	var bytes := data.slice(1)
	bytes = _trim_text_terminator(bytes, 2 if encoding in [1, 2] else 1)
	var value := ""
	match encoding:
		0:
			value = _decode_latin_or_cp1251(bytes)
		1:
			value = _decode_utf16(bytes, false)
		2:
			value = _decode_utf16(bytes, true)
		3:
			value = bytes.get_string_from_utf8()
	return value.strip_edges()


static func _trim_text_terminator(bytes: PackedByteArray, width: int) -> PackedByteArray:
	var end := _find_zero(bytes, 0, width)
	return bytes.slice(0, end) if end >= 0 else bytes


static func _decode_utf16(bytes: PackedByteArray, force_big_endian: bool) -> String:
	if bytes.size() < 2:
		return ""
	var big_endian := force_big_endian
	var start := 0
	if bytes[0] == 0xfe and bytes[1] == 0xff:
		big_endian = true
		start = 2
	elif bytes[0] == 0xff and bytes[1] == 0xfe:
		big_endian = false
		start = 2
	var normalized := bytes.slice(start)
	if big_endian:
		for i in range(0, normalized.size() - 1, 2):
			var swap := normalized[i]
			normalized[i] = normalized[i + 1]
			normalized[i + 1] = swap
	return normalized.get_string_from_utf16()


static func _decode_latin_or_cp1251(bytes: PackedByteArray) -> String:
	# Mislabelled Windows-1251 tags are still common in Russian MP3 collections.
	var has_cyrillic_range := false
	for byte in bytes:
		if byte >= 0xc0 or byte in [0xa8, 0xb8]:
			has_cyrillic_range = true
			break
	var text := ""
	for byte in bytes:
		if byte == 0:
			break
		var code := int(byte)
		if has_cyrillic_range:
			if code >= 0xc0:
				code = 0x0410 + code - 0xc0
			elif code == 0xa8:
				code = 0x0401
			elif code == 0xb8:
				code = 0x0451
		text += String.chr(code)
	return text


static func _extended_header_end(data: PackedByteArray, version: int) -> int:
	if data.size() < 4:
		return -1
	var size := _syncsafe(data, 0) if version == 4 else _uint32_be(data, 0)
	var end := size if version == 4 else size + 4
	return end if end >= 4 and end <= data.size() else -1


static func _find_zero(data: PackedByteArray, start: int, width: int) -> int:
	var i := start
	while i + width <= data.size():
		if data[i] == 0 and (width == 1 or data[i + 1] == 0):
			return i
		i += width
	return -1


static func _remove_unsynchronization(data: PackedByteArray) -> PackedByteArray:
	var result := PackedByteArray()
	var i := 0
	while i < data.size():
		result.append(data[i])
		if data[i] == 0xff and i + 1 < data.size() and data[i + 1] == 0x00:
			i += 1
		i += 1
	return result


static func _syncsafe(data: PackedByteArray, offset: int) -> int:
	if offset < 0 or offset + 4 > data.size():
		return -1
	for i in 4:
		if data[offset + i] >= 0x80:
			return -1
	return (int(data[offset]) << 21) | (int(data[offset + 1]) << 14) | (int(data[offset + 2]) << 7) | int(data[offset + 3])


static func _uint32_be(data: PackedByteArray, offset: int) -> int:
	if offset < 0 or offset + 4 > data.size():
		return -1
	return (int(data[offset]) << 24) | (int(data[offset + 1]) << 16) | (int(data[offset + 2]) << 8) | int(data[offset + 3])


static func _valid_frame_id(value: String) -> bool:
	if value.length() != 4:
		return false
	for i in value.length():
		var code := value.unicode_at(i)
		if not (code >= 0x30 and code <= 0x39) and not (code >= 0x41 and code <= 0x5a):
			return false
	return true

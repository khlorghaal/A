## Player IDs use Unicode NFC; presentation and credentials use this same form.
import std/unicode

proc gUtf8Normalize(str: cstring, len: int, mode: cint): cstring
  {.cdecl, importc: "g_utf8_normalize", dynlib: "libglib-2.0.so.0".}
proc gFree(mem: pointer) {.cdecl, importc: "g_free", dynlib: "libglib-2.0.so.0".}

proc playerId*(id: string): string =
  if id.len == 0 or '\0' in id or validateUtf8(id) != -1:
    raise newException(ValueError, "invalid player ID")
  # GLib's G_NORMALIZE_DEFAULT_COMPOSE is canonical composition (NFC).
  let normalized = gUtf8Normalize(id.cstring, id.len, 1)
  if normalized.isNil: raise newException(ValueError, "cannot normalize player ID")
  try: result = $normalized
  finally: gFree(cast[pointer](normalized))

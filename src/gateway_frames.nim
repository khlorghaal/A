## Four-byte big-endian length followed by opaque payload; host owns TLS and auth.
type FrameReader* = object
  limit      : int
  header     : uint32
  headerBytes: int
  remaining  : int
  body       : string
  failed     : bool

proc initFrameReader*(limit: int): FrameReader =
  if limit <= 0 or uint64(limit) > uint64(high(uint32)):
    raise newException(ValueError, "invalid frame limit")
  FrameReader(limit: limit)

proc feed*(r: var FrameReader, chunk: string, deliver: proc(body: string)) =
  ## No reentry. Keep at most limit payload bytes; reject header before allocation.
  if r.limit == 0 or r.failed or deliver.isNil:
    raise newException(ValueError, "invalid frame reader")
  for c in chunk:
    if r.headerBytes < 4:
      r.header = (r.header shl 8) or uint32(ord(c))
      inc r.headerBytes
      if r.headerBytes == 4:
        if uint64(r.header) > uint64(r.limit):
          r.failed = true
          raise newException(ValueError, "frame exceeds limit")
        r.remaining = int(r.header)
        r.body = ""
        if r.remaining == 0:
          r.header = 0
          r.headerBytes = 0
          deliver("")
    else:
      r.body.add c
      dec r.remaining
      if r.remaining == 0:
        let body = r.body
        r.body = ""
        r.header = 0
        r.headerBytes = 0
        deliver(body)

proc finish*(r: FrameReader) =
  if r.failed or r.headerBytes != 0:
    raise newException(ValueError, "incomplete or invalid frame stream")

proc frame*(body: string, limit: int): string =
  if limit <= 0 or body.len > limit or uint64(body.len) > uint64(high(uint32)):
    raise newException(ValueError, "frame exceeds limit")
  result = newString(4)
  for i in 0..3: result[i] = char((uint32(body.len) shr ((3-i)*8)) and 255)
  result.add body

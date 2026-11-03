## Gateway report state. Host supplies authenticated sessions and credibility policy.
import std/[tables, sets, math, json, os, strutils, options]
import gateway_snapshot
from trustdb import writeAtomic
import identity

type
  GatewayReport* = object
    value*   : float32
    revision*: uint64
    deleted* : bool
  Gateway* = object
    paragons   : HashSet[string]
    sessions   : Table[string, uint64]
    reports    : Table[tuple[reporter, subject: string], GatewayReport]
    reportLimit: int

proc initGateway*(maxReports = 65536): Gateway =
  if maxReports <= 0: raise newException(ValueError, "invalid report quota")
  Gateway(reportLimit: maxReports)

proc setParagons*(g: var Gateway, ids: openArray[string]) =
  var replacement: HashSet[string]
  for id in ids: replacement.incl playerId(id)
  g.paragons = move(replacement)
  var removed: seq[string]
  for id in g.sessions.keys:
    if id notin g.paragons: removed.add id
  for id in removed: g.sessions.del(id)
  var stale: seq[tuple[reporter, subject: string]]
  for key in g.reports.keys:
    if key.reporter notin g.paragons: stale.add key
  for key in stale: g.reports.del(key)

proc beginSession*(g: var Gateway, reporter: string, epoch: uint64) =
  ## Host epoch must be fresh and bound to authenticated connection, never body data.
  let id = playerId(reporter)
  if id notin g.paragons: raise newException(ValueError, "reporter not paragon")
  if id in g.sessions and g.sessions[id] == epoch:
    raise newException(ValueError, "session epoch reused")
  g.sessions[id] = epoch
  var keys: seq[tuple[reporter, subject: string]]
  for key in g.reports.keys:
    if key.reporter == id: keys.add key
  for key in keys: g.reports.del(key) # new session starts fresh report snapshot

proc receive*(g: var Gateway, reporter, subject: string,
              epoch, revision: uint64, value: float32, deleted = false): bool =
  let reporter = playerId(reporter)
  let subject = playerId(subject)
  if reporter notin g.paragons or reporter notin g.sessions or
     g.sessions[reporter] != epoch: return false
  if classify(value) in {fcNan, fcInf, fcNegInf} or value < 0 or value > 1:
    raise newException(ValueError, "invalid gateway report")
  let key = (reporter, subject)
  if key in g.reports and revision <= g.reports[key].revision: return false
  let limit = if g.reportLimit == 0: 65536 else: g.reportLimit
  if key notin g.reports and g.reports.len >= limit:
    raise newException(ValueError, "gateway report quota exceeded")
  g.reports[key] = GatewayReport(value: value, revision: revision, deleted: deleted)
  true

proc snapshot*(g: Gateway,
               credibility: proc(id: string): float32): Table[string, float32] =
  ## Caller supplies one immutable previous-score view for entire aggregation step.
  if credibility.isNil: raise newException(ValueError, "missing reporter weights")
  var weights: Table[string, float32]
  var totals: Table[string, tuple[sum: float64, count: int]]
  for key, report in g.reports:
    if key.reporter notin g.paragons or report.deleted: continue
    if key.reporter notin weights:
      let weight = credibility(key.reporter)
      if classify(weight) in {fcNan, fcInf, fcNegInf} or weight < 0 or weight > 1:
        raise newException(ValueError, "invalid reporter weight")
      weights[key.reporter] = weight
    totals.mgetOrPut(key.subject, (0.0, 0)).sum +=
      float64(weights[key.reporter])*float64(report.value)
    inc totals[key.subject].count
  for subject, total in totals:
    result[subject] = float32(total.sum / float64(total.count))

type GatewaySession* = object
  playerId*: string
  epoch*   : uint64

proc dispatch*(g: var Gateway, session: Option[GatewaySession], payload: string,
               credibility: proc(id: string): float32,
               maxBytes = 65536, maxEntries = 4096): string =
  ## Session originates from host auth, never request fields. Schema provisional.
  if session.isNone: raise newException(ValueError, "authentication required")
  let principal = session.get
  if playerId(principal.playerId) != principal.playerId:
    raise newException(ValueError, "invalid authenticated player ID")
  if maxBytes <= 0 or payload.len > maxBytes:
    raise newException(ValueError, "request exceeds limit")
  let request = parseJson(payload)
  if request.kind != JObject or not request.hasKey("version") or
     request["version"].kind != JInt or request["version"].getInt != 1 or
     not request.hasKey("operation") or request["operation"].kind != JString:
    raise newException(ValueError, "invalid gateway request")
  let operation = request["operation"].getStr
  if operation == "snapshot":
    if request.len != 2: raise newException(ValueError, "invalid snapshot request")
    return encodeSnapshot(g.snapshot(credibility), maxBytes, maxEntries)
  if operation notin ["report", "delete"] or principal.playerId notin g.paragons:
    raise newException(ValueError, "report channel unavailable")
  let deleted = operation == "delete"
  if request.len != (if deleted: 4 else: 5) or not request.hasKey("subject") or
     request["subject"].kind != JString or not request.hasKey("revision") or
     request["revision"].kind != JString:
    raise newException(ValueError, "invalid report request")
  let serial = request["revision"].getStr
  if serial.len == 0: raise newException(ValueError, "invalid report revision")
  for c in serial:
    if c notin {'0'..'9'}: raise newException(ValueError, "invalid report revision")
  var value = 0.0
  if not deleted:
    if not request.hasKey("value") or request["value"].kind notin {JInt, JFloat}:
      raise newException(ValueError, "invalid report value")
    value = request["value"].getFloat
    if classify(value) in {fcNan, fcInf, fcNegInf} or value < 0 or value > 1:
      raise newException(ValueError, "invalid report value")
  let accepted = g.receive(
    principal.playerId, request["subject"].getStr,
    principal.epoch, parseBiggestUInt(serial), float32(value), deleted)
  $(%*{"version": 1, "accepted": accepted})

# Storage keeps role/report provenance; authenticated sessions never persist.

proc save*(g: Gateway, directory: string, maxBytes = 16*1024*1024) =
  var roles = newJArray()
  var rows = newJArray()
  for id in g.paragons: roles.add %id
  for key, report in g.reports:
    rows.add %*[key.reporter, key.subject, report.value, $report.revision, report.deleted]
  let payload = $(%*{"version": 2, "paragons": roles, "reports": rows})
  if maxBytes <= 0 or payload.len > maxBytes:
    raise newException(ValueError, "gateway state exceeds limit")
  createDir(directory)
  writeAtomic(directory / "gateway.json", payload)

proc dispatchStored*(g: var Gateway, session: Option[GatewaySession], payload: string,
                     directory: string, credibility: proc(id: string): float32,
                     maxBytes = 65536, maxEntries = 4096): string =
  ## Publish accepted update only after durable save. Snapshot requests remain read-only.
  var staged = g
  result = staged.dispatch(session, payload, credibility, maxBytes, maxEntries)
  let reply = parseJson(result)
  if reply.hasKey("accepted") and reply["accepted"].getBool:
    staged.save(directory)
    g = move(staged)

proc loadGateway*(directory: string, maxBytes = 16*1024*1024,
                  maxReports = 65536): Gateway =
  result = initGateway(maxReports)
  let path = directory / "gateway.json"
  if not fileExists(path): return
  if maxBytes <= 0 or getFileSize(path) > int64(maxBytes):
    raise newException(ValueError, "gateway state exceeds limit")
  let root = parseJson(readFile(path))
  if root.kind != JObject or root.len != 3 or not root.hasKey("version") or
     not root.hasKey("paragons") or not root.hasKey("reports"):
    raise newException(ValueError, "invalid gateway state")
  if root["version"].kind != JInt or root["version"].getInt notin [1, 2] or
     root["paragons"].kind != JArray or root["reports"].kind != JArray:
    raise newException(ValueError, "unsupported gateway state")
  let version = root["version"].getInt
  for role in root["paragons"]:
    if role.kind != JString: raise newException(ValueError, "invalid paragon")
    let raw = role.getStr
    let id = playerId(raw)
    if id != raw or id in result.paragons:
      raise newException(ValueError, "duplicate or noncanonical paragon")
    result.paragons.incl id
  for row in root["reports"]:
    if row.kind != JArray or row.len != (if version == 1: 4 else: 5) or
       row[0].kind != JString or row[1].kind != JString or
       row[2].kind notin {JInt, JFloat} or row[3].kind != JString:
      raise newException(ValueError, "invalid gateway report")
    if version == 2 and row[4].kind != JBool:
      raise newException(ValueError, "invalid report tombstone")
    if result.reports.len >= maxReports:
      raise newException(ValueError, "gateway report quota exceeded")
    let reporter = row[0].getStr
    let subject = row[1].getStr
    let value = row[2].getFloat
    let serial = row[3].getStr
    if playerId(reporter) != reporter or playerId(subject) != subject or
       reporter notin result.paragons or (reporter, subject) in result.reports or
       classify(value) in {fcNan, fcInf, fcNegInf} or value < 0 or value > 1 or
       serial.len == 0:
      raise newException(ValueError, "invalid gateway provenance/value")
    for c in serial:
      if c notin {'0'..'9'}: raise newException(ValueError, "invalid gateway revision")
    result.reports[(reporter, subject)] = GatewayReport(
      value: float32(value), revision: parseBiggestUInt(serial),
      deleted: version == 2 and row[4].getBool)

when defined(ssl):
  import std/[net, asyncdispatch, asyncnet, monotimes, times]
  import gateway_frames
  from std/openssl import SSL_CTX_ctrl

  proc gatewayTls*(certificate, privateKey: string): SslContext =
    ## TLS authenticates gateway; player authentication remains host responsibility.
    if certificate.len == 0 or privateKey.len == 0:
      raise newException(ValueError, "gateway certificate and key required")
    result = newContext(verifyMode = CVerifyNone,
                        certFile = certificate, keyFile = privateKey)
    # OpenSSL ssl.h: SSL_CTRL_SET_MIN_PROTO_VERSION = 123, TLS1_2_VERSION = 0x0303.
    if SSL_CTX_ctrl(result.context, 123, 0x0303, nil) != 1:
      result.destroyContext()
      raise newException(ValueError, "cannot require TLS 1.2 or newer")

  proc serveConnection*(socket: AsyncSocket, context: SslContext,
                        handle: proc(payload: string): string,
                        maxFrame = 65536, timeoutMs = 5000) {.async.} =
    ## Host owns admission/concurrency and auth handler. No callbacks before TLS.
    ## Frame deadline spans partial reads; bounded output per request.
    defer: socket.close()
    if handle.isNil or timeoutMs <= 0:
      raise newException(ValueError, "gateway handler and deadline required")
    var reader = initFrameReader(maxFrame)
    context.wrapConnectedSocket(socket, handshakeAsServer)
    var started = getMonoTime()
    while true:
      let remaining = timeoutMs - int((getMonoTime() - started).inMilliseconds)
      if remaining <= 0: raise newException(ValueError, "gateway frame deadline")
      let incoming = socket.recv(4096)
      if not await withTimeout(incoming, remaining):
        socket.close()
        try: discard await incoming
        except CatchableError: discard
        raise newException(ValueError, "gateway frame deadline")
      let chunk = await incoming
      if chunk.len == 0:
        reader.finish()
        return
      for c in chunk:
        var reply: string
        var complete = false
        reader.feed($c, proc(payload: string) =
          reply = frame(handle(payload), maxFrame)
          complete = true)
        if complete:
          let outgoing = socket.send(reply)
          if not await withTimeout(outgoing, timeoutMs):
            socket.close()
            try: await outgoing
            except CatchableError: discard
            raise newException(ValueError, "gateway write deadline")
          await outgoing
          started = getMonoTime()

when defined(ssl):
  import std/sequtils
  type
    GatewayHandler* = proc(payload: string): string
    GatewayListener* = ref object
      listener: AsyncSocket
      context : SslContext
      clients : seq[AsyncSocket]
      tasks   : seq[Future[void]]

      stopped, started: bool
      limit, maxFrame, timeoutMs: int

  proc close*(g: GatewayListener) =
    if g.stopped: return
    g.stopped = true
    g.listener.close()
    for client in g.clients.mapIt(it): client.close()
    if not g.started:
      g.context.destroyContext()

  proc listenGateway*(address: string, port: Port, certificate, privateKey: string,
                      maxConnections = 64, maxFrame = 65536,
                      timeoutMs = 5000): GatewayListener =
    if maxConnections <= 0 or timeoutMs <= 0:
      raise newException(ValueError, "invalid gateway limits")
    discard initFrameReader(maxFrame)
    let context = gatewayTls(certificate, privateKey)
    let socket = newAsyncSocket(buffered = false)
    try:
      socket.bindAddr(port, address)
      socket.listen()
    except CatchableError:
      socket.close()
      context.destroyContext()
      raise
    GatewayListener(
      listener: socket, context: context, limit: maxConnections,
      maxFrame: maxFrame, timeoutMs: timeoutMs)

  proc port*(g: GatewayListener): Port = g.listener.getLocalAddr()[1]

  proc run*(g: GatewayListener, factory: proc(): GatewayHandler,
            onError: proc(message: string)) {.async.} =
    ## Caller must await run after close; context and child tasks drain here.
    if g.started or g.stopped:
      raise newException(ValueError, "gateway listener already used")
    if factory.isNil or onError.isNil:
      g.close()
      raise newException(ValueError, "gateway handler factory and error sink required")
    g.started = true
    proc service(client: AsyncSocket) {.async.} =
      try:
        await serveConnection(client, g.context, factory(), g.maxFrame, g.timeoutMs)
      except CatchableError as e:
        onError(e.msg)
      finally:
        client.close()
        g.clients.keepItIf(it != client)
    try:
      while not g.stopped:
        var client: AsyncSocket
        try: client = await g.listener.accept()
        except OSError:
          if g.stopped: break
          raise
        if g.clients.len >= g.limit:
          client.close()
          continue
        g.clients.add client
        g.tasks.keepItIf(not it.finished)
        g.tasks.add service(client)
    finally:
      g.close()
      for task in g.tasks:
        try: await task
        except CatchableError as e: onError(e.msg)
      g.context.destroyContext()

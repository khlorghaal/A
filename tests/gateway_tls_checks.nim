import std/[os, osproc, net, asyncdispatch, asyncnet, options, json, tables]
import ../src/gateway_frames
import ../src/gateway_main
import ../src/trustdb
import ../src/gateway_snapshot
import ../src/gateway
from std/openssl import SSL_CTX_ctrl
proc exercise(certificate, key: string) {.async.} =
  let serverContext = gatewayTls(certificate, key)
  defer: serverContext.destroyContext()
  let clientContext = newContext(verifyMode = CVerifyPeer, caFile = certificate)
  defer: clientContext.destroyContext()
  let listener = newAsyncSocket(buffered = false)
  defer: listener.close()
  listener.bindAddr(Port(0), "127.0.0.1")
  listener.listen()
  let port = listener.getLocalAddr()[1]
  let client = newAsyncSocket(buffered = false)
  await client.connect("127.0.0.1", port)
  let accepted = await listener.accept()
  let work = serveConnection(accepted, serverContext, proc(body: string): string = body, timeoutMs = 1000)
  clientContext.wrapConnectedSocket(client, handshakeAsClient, hostname = "localhost")
  await client.send(frame("echo", 1024))
  var decoded: seq[string]
  var reader = initFrameReader(1024)
  while decoded.len == 0:
    let reading = client.recv(1024)
    doAssert await withTimeout(reading, 2000)
    let chunk = await reading
    doAssert chunk.len > 0
    reader.feed(chunk, proc(body: string) = decoded.add body)
  doAssert decoded == @["echo"]
  client.close()
  try:
    doAssert await withTimeout(work, 2000)
    await work
  except SslError: discard # abrupt test-client TLS close
  let silent = newAsyncSocket(buffered = false)
  defer: silent.close()
  await silent.connect("127.0.0.1", port)
  let slow = await listener.accept()
  let deadline = serveConnection(slow, serverContext, proc(body: string): string = body, timeoutMs = 100)
  var rejected = false
  try:
    doAssert await withTimeout(deadline, 2000)
    await deadline
  except ValueError: rejected = true
  doAssert rejected

  let trickle = newAsyncSocket(buffered = false)
  defer: trickle.close()
  await trickle.connect("127.0.0.1", port)
  let partial = await listener.accept()
  var calls = 0
  let partialWork = serveConnection(partial, serverContext, proc(body: string): string =
    inc calls
    body, timeoutMs = 1000)
  clientContext.wrapConnectedSocket(trickle, handshakeAsClient, hostname = "localhost")
  await trickle.send("\x00")
  await sleepAsync(500)
  await trickle.send("\x00")
  await sleepAsync(600)
  var expired = false
  try:
    doAssert await withTimeout(partialWork, 2000)
    await partialWork
  except ValueError: expired = true
  doAssert expired and calls == 0

proc admission(certificate, key: string) {.async.} =
  let listener = listenGateway("127.0.0.1", Port(0), certificate, key,
                               maxConnections = 1, timeoutMs = 2000)
  var factories = 0
  var errors: seq[string]
  let serving = listener.run(proc(): GatewayHandler =
    inc factories
    result = proc(body: string): string = body,
    proc(message: string) = errors.add message)
  let first = newAsyncSocket(buffered = false)
  defer: first.close()
  await first.connect("127.0.0.1", listener.port)
  await sleepAsync(30)
  let second = newAsyncSocket(buffered = false)
  defer: second.close()
  await second.connect("127.0.0.1", listener.port)
  let rejected = second.recv(1)
  doAssert await withTimeout(rejected, 1000)
  doAssert (await rejected).len == 0
  doAssert factories == 1
  listener.close()
  doAssert await withTimeout(serving, 2000)
  await serving
  listener.close() # idempotent shutdown
  let unused = listenGateway("127.0.0.1", Port(0), certificate, key)
  unused.close() # no run: context still released

proc transactionTransport(certificate, key, path: string) {.async.} =
  var state: Gateway
  state.setParagons(["a"])
  state.beginSession("a", 1)
  let weights = proc(id: string): float32 = 0.4
  let listener = listenGateway("127.0.0.1", Port(0), certificate, key)
  var sequence = 0
  var errors: seq[string]
  let serving = listener.run(proc(): GatewayHandler =
    # Test-only auth injection; no identity comes from request body or endpoint.
    let principal = if sequence == 0: GatewaySession(playerId: "a", epoch: 1)
                    else: GatewaySession(playerId: "ordinary", epoch: 2)
    inc sequence
    result = proc(body: string): string =
      state.dispatchStored(some(principal), body, path / "gateway", weights),
    proc(message: string) = errors.add message)
  let context = newContext(verifyMode = CVerifyPeer, caFile = certificate)
  defer: context.destroyContext()
  proc request(payload: string): Future[string] {.async.} =
    let client = newAsyncSocket(buffered = false)
    defer: client.close()
    await client.connect("127.0.0.1", listener.port)
    context.wrapConnectedSocket(client, handshakeAsClient, hostname = "localhost")
    await client.send(frame(payload, 65536))
    var reply: string
    var complete = false
    var reader = initFrameReader(65536)
    while not complete:
      let incoming = client.recv(4096)
      doAssert await withTimeout(incoming, 2000)
      let chunk = await incoming
      doAssert chunk.len > 0
      reader.feed(chunk, proc(body: string) =
        reply = body
        complete = true)
    return reply
  try:
    let report = "{\"version\":1,\"operation\":\"report\",\"subject\":\"ship\",\"revision\":\"1\",\"value\":0.5}"
    doAssert parseJson(await request(report))["accepted"].getBool
    doAssert abs(loadGateway(path / "gateway").snapshot(weights)["ship"] - 0.2) < 0.00001
    let snapshot = await request("{\"version\":1,\"operation\":\"snapshot\"}")
    var peer: TrustDb
    peer.setWitness("local", 0.7)
    peer.syncParagon(decodeSnapshot(snapshot, 65536, 4096), path / "peer")
    let restored = trustdb.load(path / "peer")
    doAssert abs(restored.credibility("ship") - 0.16) < 0.00001
    doAssert "ship" notin restored.witnessed
    doAssert restored.witnessed["local"] == 0.7'f32
  finally:
    listener.close()
    doAssert await withTimeout(serving, 2000)
    await serving

block configuration:
  let path = getTempDir() / ("a-gateway-tls-" & $getCurrentProcessId())
  if dirExists(path): removeDir(path)
  createDir(path)
  defer: removeDir(path)
  let certificate = path / "certificate.pem"
  let key = path / "key.pem"
  let child = startProcess("openssl", args = @["req", "-x509", "-newkey", "rsa:2048",
    "-nodes", "-days", "1", "-subj", "/CN=localhost", "-keyout", key, "-out", certificate],
    options = {poUsePath, poStdErrToStdOut})
  defer:
    if child.running: child.terminate()
    discard child.waitForExit(1000)
    child.close()
  doAssert child.waitForExit(10000) == 0
  let config = parseConfig(@["--check", "--cert", certificate, "--key", key,
                             "--db-dir", path / "db"])
  doAssert config.check and config.port == 7443
  checkConfig(config)
  let owner = acquireLock(config.dbDir / ".owner.lock")
  var denied = false
  try: checkConfig(config)
  except OSError: denied = true
  owner.release()
  doAssert denied
  for options in [@["--port", "0"], @["--max-frame", "-1"], @["--timeout-ms", "0"],
                  @["--max-connections", "0"], @["--port", "nonsense"], @["--port"],
                  @["--unknown", "value"]]:
    var invalid = false
    try:
      discard parseConfig(@["--cert", certificate, "--key", key] & options)
    except ValueError: invalid = true
    doAssert invalid
  let ctx = gatewayTls(certificate, key)
  # OpenSSL ssl.h SSL_CTRL_GET_MIN_PROTO_VERSION = 130.
  doAssert SSL_CTX_ctrl(ctx.context, 130, 0, nil) == 0x0303
  ctx.destroyContext()
  waitFor exercise(certificate, key)
  waitFor admission(certificate, key)
  waitFor transactionTransport(certificate, key, path / "transaction")
  for paths in [("", key), (certificate, ""), (certificate, path / "missing")]:
    var rejected = false
    try:
      let invalid = gatewayTls(paths[0], paths[1])
      invalid.destroyContext()
    except CatchableError: rejected = true
    doAssert rejected
  echo "gateway TLS configuration checks passed"

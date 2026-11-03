import std/[os, osproc, net, asyncdispatch, asyncnet]
import ../src/gateway_frames
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
  let ctx = gatewayTls(certificate, key)
  # OpenSSL ssl.h SSL_CTRL_GET_MIN_PROTO_VERSION = 130.
  doAssert SSL_CTX_ctrl(ctx.context, 130, 0, nil) == 0x0303
  ctx.destroyContext()
  waitFor exercise(certificate, key)
  waitFor admission(certificate, key)
  for paths in [("", key), (certificate, ""), (certificate, path / "missing")]:
    var rejected = false
    try:
      let invalid = gatewayTls(paths[0], paths[1])
      invalid.destroyContext()
    except CatchableError: rejected = true
    doAssert rejected
  echo "gateway TLS configuration checks passed"

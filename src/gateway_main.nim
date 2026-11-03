## Standalone gateway preflight. Live serve remains disabled until auth provider exists.
import std/[os, strutils, net]
import gateway, trustdb

type GatewayConfig* = object
  certificate*, privateKey*, dbDir*, address*: string
  port*, maxConnections*, maxFrame*, timeoutMs*: int
  check*: bool

proc parseConfig*(args: openArray[string]): GatewayConfig =
  result = GatewayConfig(dbDir: "build/gateway/db", address: "127.0.0.1", port: 7443,
                         maxConnections: 64, maxFrame: 65536, timeoutMs: 5000)
  var i = 0
  while i < args.len:
    let option = args[i]
    if option == "--check":
      result.check = true
      inc i
      continue
    if i + 1 >= args.len: raise newException(ValueError, "missing option value: " & option)
    let value = args[i+1]
    case option
    of "--cert": result.certificate = value
    of "--key": result.privateKey = value
    of "--db-dir": result.dbDir = value
    of "--address": result.address = value
    of "--port": result.port = parseInt(value)
    of "--max-connections": result.maxConnections = parseInt(value)
    of "--max-frame": result.maxFrame = parseInt(value)
    of "--timeout-ms": result.timeoutMs = parseInt(value)
    else: raise newException(ValueError, "unknown gateway option: " & option)
    i += 2
  if result.certificate.len == 0 or result.privateKey.len == 0 or
     result.dbDir.len == 0 or result.address.len == 0:
    raise newException(ValueError, "certificate, key, database and address required")
  if result.port < 1 or result.port > 65535 or result.maxConnections < 1 or
     result.maxFrame < 1 or uint64(result.maxFrame) > uint64(high(uint32)) or result.timeoutMs < 1:
    raise newException(ValueError, "invalid gateway numeric limit")

proc checkConfig*(config: GatewayConfig) =
  let tls = gatewayTls(config.certificate, config.privateKey)
  defer: tls.destroyContext()
  createDir(config.dbDir)
  let ownership = acquireLock(config.dbDir / ".owner.lock")
  defer: ownership.release()
  discard loadGateway(config.dbDir)

when isMainModule:
  proc main(): int =
    if commandLineParams() == @["--help"]:
      echo "gateway --check --cert FILE --key FILE [--db-dir DIR] [--address HOST] [--port N]"
      echo "limits: --max-connections N --max-frame BYTES --timeout-ms N"
      return 0
    try:
      let config = parseConfig(commandLineParams())
      if not config.check:
        stderr.writeLine("gateway live serve disabled: authentication provider pending; use --check")
        return 2
      checkConfig(config)
      echo "gateway TLS/database configuration valid"
    except CatchableError as e:
      stderr.writeLine(e.msg)
      return 1
  quit(main())

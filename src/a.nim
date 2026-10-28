import std/[monotimes, os, tables, math, strutils]
import p2p, sync
import client
when defined(simSockets):
  import ../tests/socket_gateway
  from std/nativesockets import Port

type
  Ship = object
    id     : Uid
    p      : sync_v2
    trigger: sync_b
    hp     : int32
    cd     : int32
    msl    : int32
    chr    : Grapheme
    fac    : rgb

const
  usec =         1'i64
  msec =      1000'i64
  sec  = 1_000_000'i64
  tdt  = 25*msec

  etypShip  = 0b0001'u64
  shipMax   = 0xffffe

var
  t0, now, tick: int64
  randS       : int64
  ccmuMask    : uint64
  dbgDur      : int64
  dbgp        = "init"

  ships       : array[shipMax, Ship]
  shipsEnd    : int

  localPeer   = getEnv("A_PEER_ID", "1").parseBiggestUInt.uint64
  net         = initNet(PeerInfo(id: localPeer), 1)
  replication = initSync(net, 1)

template liveShips: untyped = ships.toOpenArray(0, shipsEnd - 1)

proc nowUs(): int64 = getMonoTime().ticks div 1000 - t0

proc hrng(): int64 =
  let s = randS +% 17171
  var r = s *% 0x5D747531573B1B'i64
  r = ashr(r, 7) xor 0x73513D1B7117B3'i64
  randS = r
  r

proc genUid(): Uid =
  (cast[uint64](hrng()), cast[uint64](hrng()))

proc bad(s: string) =
  dbgp   = s
  dbgDur = 120

proc allocShip(): ptr Ship =
  if shipsEnd >= shipMax:
    ccmuMask = ccmuMask or etypShip
    bad("cant more entity")
    dec shipsEnd

  result = addr ships[shipsEnd]
  inc shipsEnd

proc initShips() =
  for i in 0..<7:
    allocShip()[] = Ship(
      id : genUid(), hp: 16, cd: 0, msl: 255,
      chr: Grapheme("A"), fac: 0xeeeeee,
      p  : sv(float32(i*2 - 8), float32(i mod 2*3)))
    replication.owners[ships[i].id] = 1 # shared initial scenario, peer 1 owns it

proc act(a: Action) =
  case a
  of actU: ships[0].p += sv( 0,-1)
  of actL: ships[0].p += sv(-1, 0)
  of actR: ships[0].p += sv( 1, 0)
  of actD: ships[0].p += sv( 0, 1)
  of actF: ships[0].trigger.set(not ships[0].trigger.value)

proc stepShips(dt = 0.025) =
  for i in 0..<shipsEnd:
    when defined(simSockets): continue
    case hrng() mod 5
    of 0: ships[i].p += sv( 1, 0)
    of 1: ships[i].p += sv(-1, 0)
    else: discard

  replication.reconcile(net, liveShips, dt)
  replication.publish(liveShips)

  view = ships[0].p
  for i in 0..<shipsEnd:
    let s = ships[i]
    draw(s.p, Cell(g: s.chr, fg: s.fac, bg: colBaseBg))

proc main(): int =
  if not initScreen(): return 1
  defer: closeScreen()

  initShips()
  when defined(simSockets):
    net.bindClient(Port(getEnv("A_GATEWAY_PORT").parseInt))
  replication.publish(liveShips)
  t0 = nowUs()
  now = 0
  var previous = -tdt

  while true:
    let started = nowUs()
    let dt = float64(started - previous)/float64(sec)
    previous = started

    if not gather.isNil: net.tick()
    screenSize()
    var mouse: i2 = v(-1,-1)
    var ev: TbEvent

    while tb_peek_event(addr ev, 0) == 0:
      if ev.kind == TB_EVENT_RESIZE:
        sdim = (ev.w, ev.h)
        continue
      if ev.kind != TB_EVENT_KEY and ev.kind != TB_EVENT_MOUSE: continue

      case uint32(ev.key)
      of keyUp   : act(actU)
      of keyLeft : act(actL)
      of keyRight: act(actR)
      of keyDown : act(actD)
      of keyClick: mouse = (ev.x, ev.y)
      of TB_KEY_CTRL_C, TB_KEY_ESC: return 0
      else: discard

    drawPad(mouse, act)
    stepShips(dt)
    when defined(simSockets):
      let statePath = getEnv("A_STATE_FILE")
      writeFile(statePath & ".tmp", $ships[0].p.x & " " & $ships[0].p.y)
      moveFile(statePath & ".tmp", statePath)

    if dbgDur > 0:
      debugHeader(dbgp)
      dec dbgDur

    presentScreen()

    now = nowUs()
    let remaining = tdt - (now - started)
    if remaining >= msec: sleep(int(remaining div msec))
    inc tick

when defined(aTests):
  include ../tests/game_checks
elif isMainModule:
  quit main()

# test-only coupling; loopback UDP carries simulated datagrams
import std/[net, nativesockets, json, jsonutils, tables, monotimes]
from std/posix import EAGAIN, EWOULDBLOCK
import ../src/p2p
when isMainModule:
  import std/[os, times, strutils]
  import sim_socket

proc packet(dst: PeerId, e: Event): string =
  $(%*{"dst": dst, "event": e.toJson, "sentAt": getMonoTime().ticks})

proc unpack(msg: JsonNode): Event =
  result = msg["event"].jsonTo(Event)
  # All test processes share this OS monotonic clock, unlike Internet peers.
  result.datum.age += float64(getMonoTime().ticks - msg["sentAt"].getBiggestInt)/1e9

proc bindClient*(n: var Net, port: Port) =
  let socket = newSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
  socket.bindAddr(Port(0), "127.0.0.1")
  socket.getFd.setBlocking(false)
  let source = n.selph
  socket.sendTo("127.0.0.1", port, packet(0, Event(source: source)))
  for id in 1'u64..4'u64:
    if id == source.id: continue
    let p = Peer(info: PeerInfo(id: id), trust: 0.5, up: (0'f32, 1'f32))
    n.peers[id] = p
    n.all.add p
    n.near.add p
  gather = proc(): seq[Event] =
    while true:
      var bytes, host: string
      var remote: Port
      try: discard socket.recvFrom(bytes, 65535, host, remote)
      except OSError as e:
        if e.errorCode notin [int32(EAGAIN), int32(EWOULDBLOCK)]: raise
        break
      result.add unpack(parseJson(bytes))
  sendDatum = proc(p: Peer, k: Kind, d: Datum) =
    socket.sendTo("127.0.0.1", port, packet(p.info.id,
      Event(event: data, source: source, kind: k.id, datum: d)))
  sendPeers = proc(p: Peer, peers: seq[PeerInfo]) = discard
  traffic = proc(p: Peer) = discard
  p2p.accept = proc(p: Peer, k: Kind, d: Datum): bool = true

when isMainModule:
  let socket = newSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
  socket.bindAddr(Port(paramStr(1).parseInt), "127.0.0.1")
  socket.getFd.setBlocking(false)
  var endpoints: Table[PeerId, tuple[host: string, port: Port]]
  var g = initGateway(paramStr(2).parseInt, paramStr(3).parseInt,
                      paramStr(4).parseFloat, 123)
  let started = getMonoTime()
  echo "ready"
  flushFile(stdout)
  while true:
    g.now = (getMonoTime() - started).inMilliseconds
    while true:
      var bytes, host: string
      var port: Port
      try: discard socket.recvFrom(bytes, 65535, host, port)
      except OSError as e:
        if e.errorCode notin [int32(EAGAIN), int32(EWOULDBLOCK)]: raise
        break
      let msg = parseJson(bytes)
      let e = unpack(msg)
      endpoints[e.source.id] = (host, port)
      let dst = msg["dst"].getBiggestInt.uint64
      if dst != 0: g.send(dst, e)
    for id, endpoint in endpoints:
      for e in g.recv(id): socket.sendTo(endpoint.host, endpoint.port, packet(id, e))
    sleep(2)

## Four terminal clients using the test-only loopback gateway (Linux/Unix).
import std/[monotimes, net, os, osproc, streams, strutils, times, tables]
import posix
import multi_observations
import ../src/trustdb

{.passL: "-lutil".}
{.emit: """
#include <pty.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <sys/ioctl.h>
static int a_start_pty(int *master, int peer, int port, const char *state, const char *db) {
  struct winsize size = {30, 80, 0, 0};
  int pid = forkpty(master, NULL, NULL, &size);
  if (pid == 0) {
    char id[16], gateway[16];
    snprintf(id, sizeof id, "%d", peer);
    snprintf(gateway, sizeof gateway, "%d", port);
    setenv("TERM", "xterm-256color", 1);
    setenv("LANG", "C.UTF-8", 1);
    setenv("A_PEER_ID", id, 1);
    setenv("A_GATEWAY_PORT", gateway, 1);
    setenv("A_STATE_FILE", state, 1);
    setenv("A_TEST_VX", "4", 1);
    execl("./build/A-multi", "A-multi", "--db-dir", db, (char *)NULL);
    _exit(127);
  }
  if (pid > 0) fcntl(*master, F_SETFL, fcntl(*master, F_GETFL) | O_NONBLOCK);
  return pid;
}
""".}
proc startPty(master: ptr cint, peer, port: cint, state, db: cstring): cint
  {.importc: "a_start_pty", nodecl.}

type Child = object
  pid   : Pid
  fd    : cint
  output: string
  reaped: bool
  status: cint

let tmpDir = getTempDir() / ("a-multi-" & $getCurrentProcessId())

proc running(child: var Child): bool =
  if child.reaped: return false
  var status: cint
  let rc = waitpid(child.pid, status, WNOHANG)
  if rc > 0:
    child.reaped = true
    child.status = status
  elif rc < 0: raiseOSError(osLastError())
  rc == 0

proc drain(child: var Child) =
  var buf: array[8192, char]
  while true:
    let n = posix.read(child.fd, addr buf[0], buf.len)
    if n <= 0: break
    child.output.add buf.toOpenArray(0, n.int - 1).join("")

proc pump(children: var seq[Child], gateway: Process, seconds: float64) =
  let start = getMonoTime()
  while (getMonoTime() - start).inMilliseconds.float64 < seconds * 1000:
    doAssert gateway.running, "gateway died"
    for c in children.mitems:
      doAssert c.running, "client died"
      c.drain()
    sleep(20)

proc scenario(latency, jitter: int, loss: float64, crash = false) =
  let priorPing = getEnv("A_TEST_PING_MS")
  putEnv("A_TEST_PING_MS", $(2*latency))
  defer: putEnv("A_TEST_PING_MS", priorPing)
  const outDir = "build/multi"
  createDir(outDir)
  for i in 0..<4:
    let state = outDir / ("state-" & $i)
    if fileExists(state): removeFile(state)
    if fileExists(state & ".tmp"): removeFile(state & ".tmp")
  let probe = newSocket(net.AF_INET, net.SOCK_DGRAM, net.IPPROTO_UDP)
  probe.bindAddr(Port(0), "127.0.0.1")
  let port = probe.getLocalAddr()[1]
  probe.close()
  let gateway = startProcess("./build/gateway/relay", args = @[$int(port), $latency, $jitter, $loss],
                             options = {poUsePath, poStdErrToStdOut})
  var children: seq[Child]
  try:
    doAssert gateway.outputStream.readLine() == "ready", "gateway failed to start"
    for i in 0..<4:
      let state = outDir / ("state-" & $i)
      let db = tmpDir / "A" / ("testclient" & $(i+1))
      var c: Child
      c.pid = Pid(startPty(addr c.fd, cint(i+1), cint(port), state.cstring, db.cstring))
      doAssert c.pid > 0, "forkpty failed"
      children.add c
    pump(children, gateway, 1)

    if crash:
      discard kill(children[0].pid, SIGKILL)
      var status: cint
      discard waitpid(children[0].pid, status, 0)
      children[0].reaped = true
      echo "client crash: supervisor cleanup exercised"
      return

    var before, after: seq[Position]
    for i in 0..<4:
      before.add parsePosition(readFile(outDir / ("state-" & $i)))

    let started = getMonoTime()
    for i in 0..<8:
      var key = "\e[A"
      doAssert posix.write(children[0].fd, unsafeAddr key[0], key.len) == key.len
      pump(children, gateway, 0.08)
    pump(children, gateway, 5)

    let elapsed = (getMonoTime() - started).inMilliseconds.float64 / 1000
    for i in 0..<4:
      after.add parsePosition(readFile(outDir / ("state-" & $i)))
    echo "8 owner inputs: displacement=", checkMotion(before, after, elapsed),
         " cells (ideal=8)"

    for i in 0..<4:
      children[i].drain()
      writeFile(outDir / ($latency & "-" & $i & ".ansi"), children[i].output)
      var esc = "\e"
      discard posix.write(children[i].fd, unsafeAddr esc[0], esc.len)
    for c in children.mitems:
      let deadline = getMonoTime()
      while c.running and (getMonoTime() - deadline).inMilliseconds < 5000:
        c.drain()
        sleep(20)
      doAssert c.reaped, "client exit timeout"
      doAssert WIFEXITED(c.status) and WEXITSTATUS(c.status) == 0, "unclean client exit"
    for i in 1..4:
      let dbDir = tmpDir / "A" / ("testclient" & $i)
      doAssert fileExists(dbDir / "trust.toml")
      let saved = trustdb.load(dbDir)
      doAssert saved.paragon.len == 3
      doAssert saved.witnessed.len == 0 # synthetic bootstrap is not firsthand evidence
      for peer in 1..4:
        if peer != i:
          doAssert abs(saved.credibility("test-peer-" & $peer) - 0.4) < 0.00001
    echo "4 clients: latency=", latency, " jitter=", jitter, " loss=", loss, ": passed"
  finally:
    for c in children.mitems:
      if not c.reaped:
        discard kill(c.pid, SIGKILL)
        var status: cint
        discard waitpid(c.pid, status, 0)
      discard posix.close(c.fd)
    if gateway.running: gateway.terminate()
    if gateway.waitForExit(2000) == -1:
      gateway.kill()
      discard gateway.waitForExit()
    gateway.close()

try:
  scenario(0, 0, 0)
  scenario(80, 35, 0.25)
  scenario(80, 35, 0.25, true)
  echo "four-client TUI network tests passed; all child processes reaped"
finally:
  if dirExists(tmpDir): removeDir(tmpDir)

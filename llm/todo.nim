## Print only the active portion of a todo; the remainder stays deferred.
import std/strutils

func boundary(line: string): bool =
  line.strip.toLowerAscii in ["defer>>>", "deferred>>>"]

func active*(todo: string): string =
  for line in todo.splitLines:
    if boundary(line): break
    result.add line & "\n"

when defined(todoTests):
  doAssert active("first\ndefer>>>\nlater\nheading\n  last") == "first\n"
  doAssert active("first\n  Deferred>>>  \nlater") == "first\n"
  doAssert active("first\nDEFER>>>\nlater") == "first\n"
  doAssert active("not a defer>>> boundary") == "not a defer>>> boundary\n"
  echo "todo boundary checks passed"
elif isMainModule:
  import std/os
  if paramCount() != 1: quit("usage: todo path/to/todo.txt", 1)
  stdout.write active(readFile(paramStr(1)))

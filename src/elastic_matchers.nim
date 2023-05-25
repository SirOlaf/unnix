import std/[
  strformat, strutils,
]

import std/json as js

import jsony


type
  MatchName* = object
    name*: string


proc quoted(x: string): string {.inline.} =
  "\"" & x & "\""


template stripJsonDslComma() =
  s = s.strip(chars = {',', ' '})

template buildJson(body: untyped): untyped =
  body
  stripJsonDslComma()

template withJsonObject(body: untyped): untyped =
  s.add("{")
  body
  stripJsonDslComma()
  s.add("}, ")

template withJsonMap(name: string, body: untyped): untyped =
  s.add(name.quoted() & ": ")
  withJsonObject:
    body

template withJsonArray(name: string, body: untyped): untyped =
  s.add(name.quoted() & ": [")
  body
  stripJsonDslComma()
  s.add("], ")

template addJsonVal(name: string, value: typed): untyped =
  when value is string:
    s.add(name.quoted() & ": " & value.quoted())
  else:
    s.add(name.quoted() & ": " & $value)
  s.add(", ")


proc dumpHook*(s: var string, v: MatchName) =
  buildJson:
    withJsonObject:
      withJsonMap("dis_max"):
        addJsonVal("tie_breaker", 0.7)
        withJsonArray("queries"):
          # TODO: Why does it make the order so weird
          #withJsonObject:
          #  withJsonMap("wildcard"):
          #    withJsonMap("package_attr_name"):
          #      addJsonVal("value", v.name & "*")
          withJsonObject:
            withJsonMap("match"):
              addJsonVal("package_programs", v.name)


when isMainModule:
  echo MatchName(name : "firefox").toJson()

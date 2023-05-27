import std/[
  strformat, strutils,
]

import std/json as js

import jsony


type
  MatchName* = object
    name*: string
    exact*: bool

  MatchSearch* = object
    search*: string


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

template addJsonArrayVal(value: typed): untyped =
  when value is string:
    s.add(value.quoted())
  else:
    s.add($value)
  s.add(", ")


proc dumpHook*(s: var string, v: MatchName) =
  buildJson:
    withJsonObject:
      withJsonMap("dis_max"):
        addJsonVal("tie_breaker", 0.7)
        withJsonArray("queries"):
          if v.exact:
            withJsonObject:
              withJsonMap("term"):
                addJsonVal("package_attr_name", v.name)
          else:
            # TODO: Why does it make the order so weird
            withJsonObject:
              withJsonMap("wildcard"):
                withJsonMap("package_attr_name"):
                  addJsonVal("value", v.name & "*")
                  addJsonVal("case_insensitive", true)
            withJsonObject:
              withJsonMap("match"):
                addJsonVal("package_programs", v.name)

proc dumpHook*(s: var string, v: MatchSearch) =
  buildJson:
    withJsonObject:
      withJsonMap("dis_max"):
        addJsonVal("tie_breaker", 0.7)
        withJsonArray("queries"):
          withJsonObject:
            withJsonMap("multi_match"):
              addJsonVal("type", "cross_fields")
              addJsonVal("query", v.search)
              addJsonVal("analyzer", "whitespace")
              addJsonVal("auto_generate_synonyms_phrase_query", false)
              addJsonVal("operator", "and")
              addJsonVal("_name", "multi_match_" & v.search.replace(" ", "_"))
              withJsonArray("fields"):
                addJsonArrayVal("package_attr_name^9")
                addJsonArrayVal("package_attr_name.*^5.3999999999999995")
                addJsonArrayVal("package_programs^9")
                addJsonArrayVal("package_programs.*^5.3999999999999995")
                addJsonArrayVal("package_pname^6")
                addJsonArrayVal("package_pname.*^3.5999999999999996")
                addJsonArrayVal("package_description^1.3")
                addJsonArrayVal("package_description.*^0.78")
                addJsonArrayVal("package_pversion^1.3")
                addJsonArrayVal("package_pversion.*^0.78")
                addJsonArrayVal("package_longDescription^1")
                addJsonArrayVal("package_longDescription.*^0.6")
                addJsonArrayVal("flake_name^0.5")
                addJsonArrayVal("flake_name.*^0.3")
                addJsonArrayVal("flake_resolved.*^99")
          withJsonObject:
            withJsonMap("wildcard"):
              withJsonMap("package_attr_name"):
                addJsonVal("value", "*" & v.search & "*")
                addJsonVal("case_insensitive", true)


when isMainModule:
  echo MatchName(name : "firefox").toJson()

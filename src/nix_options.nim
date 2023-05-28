import std/[
  algorithm,
  htmlparser,
  options,
  sequtils,
  strutils,
  xmltree,
]

import puppy
import jsony

import search_client
import elastic_matchers

export newNixSearchClient, NixSearchQuery


type
  NixSearchRespOption* = object
    `type`*: string
    optionSource*: string
    optionName*: string
    optionDescription*: string
    optionType*: string
    optionDefault*: string
    optionExample*: Option[string]
    optionFlake*: Option[string] # TODO: Is this type correct?


proc queryOptions*(self: NixSearchClient, query: NixSearchQuery): seq[NixSearchRespOption] =
  let preppedQuery = query.prepQuery().toJson()

  var headers: HttpHeaders
  headers["Authorization"] = getDefaultBasicAuth()
  headers["Content-type"] = "application/json"
  let resp = post(
    self.makeBackendSearchUri(query.channel.get("unstable".NixChannel)),
    headers,
    preppedQuery,
  )

  template squashHtml(x): string =
    # TODO: This is nasty
    x.parseHtml().innerText().splitLines().mapIt(it.strip()).filterIt(it.len() > 0).join(" ")

  let respData = resp.body.fromJson(NixSearchResp[NixSearchRespOption])
  for hit in respData.hits.hits:
    if hit.source.`type` != "option":
      continue
    var source = hit.source
    source.optionDescription = source.optionDescription.squashHtml()#.parseHtml().innerText().splitLines().join(" ")
    source.optionDefault = source.optionDefault.squashHtml()
    result.add(source)
  for i in 0 ..< result.len():
    if result[i].optionName.endsWith(".enable"):
      let val = result[i]
      result.delete(i)
      result = @[val] & result



when isMainModule:
  let client = newNixSearchClient()
  let query = NixSearchQuery(
    maxResults : 50,
    search : some MatchSearch(
      search : "mullvad",
    ),
    kind : SearchKind.option
  )

  let packages = client.queryOptions(query)
  #quit(0)
  var i = packages.len()
  for package in packages.reversed():
    echo "  ", i, " ", package.optionName
    echo "     ", package.optionDescription
    dec i

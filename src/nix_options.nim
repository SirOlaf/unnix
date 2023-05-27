import std/[
  algorithm,
  htmlparser,
  options,
  strutils,
  xmltree,
]

import puppy
import jsony

import search_client
import elastic_matchers


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
  headers["Authorization"] = encodeBasicAuth(elasticSearchUsername, elasticSearchPassword)
  headers["Content-type"] = "application/json"
  let resp = post(
    self.makeBackendSearchUri(query.channel.get("unstable".NixChannel)),
    headers,
    preppedQuery,
  )

  let respData = resp.body.fromJson(NixSearchResp[NixSearchRespOption])
  for hit in respData.hits.hits:
    if hit.source.`type` != "option":
      continue
    var source = hit.source
    # TODO: This is nasty
    source.optionDescription = source.optionDescription.parseHtml().innerText().splitLines().join(" ")
    result.add(source)




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

import std/[
  algorithm,
  options,
  strutils,
]

import puppy
import jsony

import search_client
import elastic_matchers


type
  NixSearchRespLicense* = object
    url*: string
    fullName*: string

  NixSearchRespPackage* = object
    `type`*: string
    packageAttrName*: string
    packageAttrSet*: string
    packagePname*: string
    packagePversion*: string
    packagePlatforms*: seq[string]
    packageOutputs*: seq[string]
    packagePrograms*: seq[string]
    packageLicense*: seq[NixSearchRespLicense]
    packageDescription*: string
    packageSystem*: string
    packageHomepage*: seq[string]
    packagePosition*: string


proc queryPackages*(self: NixSearchClient, query: NixSearchQuery): seq[NixSearchRespPackage] =
  let preppedQuery = query.prepQuery().toJson()

  var headers: HttpHeaders
  headers["Authorization"] = encodeBasicAuth(elasticSearchUsername, elasticSearchPassword)
  headers["Content-type"] = "application/json"
  let resp = post(
    self.makeBackendSearchUri(query.channel.get("unstable".NixChannel)),
    headers,
    preppedQuery,
  )

  let respData = resp.body.fromJson(NixSearchResp[NixSearchRespPackage])
  for hit in respData.hits.hits:
    if hit.source.`type` != "package":
      continue
    result.add(hit.source)





when isMainModule:
  let client = newNixSearchClient()
  let query = NixSearchQuery(
    maxResults : 50,
    search : some MatchSearch(
      search : "mullvad",
    ),
    kind : SearchKind.package
  )

  let packages = client.queryPackages(query)
  #quit(0)
  var i = packages.len()
  for package in packages.reversed():
    echo "  ", i, " ", package.packageAttrName
    echo "     ", package.packageDescription
    dec i

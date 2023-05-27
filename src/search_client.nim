import std/[
  algorithm,
  base64,
  hashes,
  htmlparser,
  options,
  sets,
  sequtils,
  strutils,
  tables,
  xmltree,
]

import puppy
import jsony

import elastic_matchers



const
  elasticSearchUsername = "aWVSALXpZv"
  elasticSearchPassword = "X8gPHnzL52wFEekuxsfQ9cSh"
  baseBackendUri = "https://search.nixos.org/backend/"
  backendAliasUri = baseBackendUri & "_aliases"


type
  ElasticAliasDef = object
    aliases: Table[string, RawJson]

  ElasticAliases = Table[string, ElasticAliasDef]


type
  NixChannel* = distinct string

  NixSearchClient* = ref object
    searchPrefix: string
    searchAliases: HashSet[string]
    knownChannels: HashSet[NixChannel]

  NixSearchQuery* = object
    maxResults*: int
    channel*: Option[NixChannel]
    name*: Option[MatchName]
    search*: Option[MatchSearch]
    kind*: SearchKind

  NixSearchQueryJson = object
    `from`, size: int
    sort: seq[OrderedTable[string, string]]
    query: OrderedTable[string, OrderedTable[string, RawJson]]


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

  NixSearchRespOption* = object
    `type`*: string
    optionSource*: string
    optionName*: string
    optionDescription*: string
    optionType*: string
    optionDefault*: string
    optionExample*: Option[string]
    optionFlake*: Option[string] # TODO: Is this type correct?

  NixSearchRespHit[T] = object
    score: float
    source: T #NixSearchRespPackage

  NixSearchResp[T] = object
    took: int
    timedOut: bool
    hits: tuple[hits: seq[NixSearchRespHit[T]]] #tuple[hits: seq[NixSearchRespHit]]


proc renameHook*(v: var NixSearchRespHit, fieldName: var string) =
  fieldName = case fieldName
  of "_source":
    "source"
  of "_score":
    "score"
  else:
    fieldName



proc hash(x: NixChannel): Hash {.borrow.}
proc `==`(x, y: NixChannel): bool {.borrow.}
proc `$`(x: NixChannel): string {.borrow.}


proc encodeBasicAuth(username, password: string): string {.inline.} =
  "Basic " & base64.encode(username & ":" & password)

proc fetchNixosSearchAliases(): HashSet[string] =
  var headers: HttpHeaders
  headers["Authorization"] = encodeBasicAuth(elasticSearchUsername, elasticSearchPassword)
  let resp = get(backendAliasUri, headers)
  for _, data in resp.body.fromJson(ElasticAliases):
    if data.aliases.len() > 0:
      result.incl(data.aliases.keys().toSeq().filterIt("nixos" in it).toHashSet())

proc makeBackendSearchUri(self: NixSearchClient, channel: NixChannel): string {.inline.} =
  doAssert channel in self.knownChannels
  baseBackendUri & self.searchPrefix & "nixos-" & $channel & "/_search"


proc newNixSearchClient*(): NixSearchClient =
  new(result)
  result.searchAliases = fetchNixosSearchAliases()
  # TODO: Better error handling
  doAssert result.searchAliases.len() > 0
  let
    aliasParts = result.searchAliases.mapIt(it.split("nixos-"))
    channels = aliasParts.mapIt(it[1].NixChannel).toHashSet()
  result.searchPrefix = aliasParts[0][0]
  result.knownChannels = channels


proc prepQuery(query: NixSearchQuery): NixSearchQueryJson =
  result.size = query.maxResults
  if query.kind == SearchKind.package:
    result.sort = @[{
      "_score": "desc",
      "package_attr_name": "desc",
      "package_pversion": "desc",
    }.toOrderedTable()]
  elif query.kind == SearchKind.option:
    result.sort = @[{
      "_score": "desc",
      "option_name": "desc",
    }.toOrderedTable()]
  else:
    raise newException(ValueError, "Unhandled SearchKind = " & $query.kind)

  var must = newSeq[RawJson]()
  if query.name.isSome():
    var q = query.name.unsafeGet()
    q.kind = query.kind
    must.add(q.toJson().RawJson)
  if query.search.isSome():
    var q = query.search.unsafeGet()
    q.kind = query.kind
    must.add(q.toJson().RawJson)

  result.query["bool"] = {
    "must": must.toJson().RawJson
  }.toOrderedTable()

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
    #echo "  ", i, " ", package.packageAttrName
    #echo "    ", package.packageDescription
    echo "  ", i, " ", package.optionName
    echo "     ", package.optionDescription.parseHtml().innerText.splitLines().join(" ")
    dec i

  #echo client.backendSearchUri()

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

  NixSearchRespHit*[T] = object
    score*: float
    source*: T

  NixSearchResp*[T] = object
    took*: int
    timedOut*: bool
    hits*: tuple[hits: seq[NixSearchRespHit[T]]]


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


proc encodeBasicAuth*(username, password: string): string {.inline.} =
  "Basic " & base64.encode(username & ":" & password)

proc getDefaultBasicAuth*(): string {.inline.} =
  encodeBasicAuth(elasticSearchUsername, elasticSearchPassword)


proc fetchNixosSearchAliases(): HashSet[string] =
  var headers: HttpHeaders
  headers["Authorization"] = getDefaultBasicAuth()
  let resp = get(backendAliasUri, headers)
  for _, data in resp.body.fromJson(ElasticAliases):
    if data.aliases.len() > 0:
      result.incl(data.aliases.keys().toSeq().filterIt("nixos" in it).toHashSet())

proc makeBackendSearchUri*(self: NixSearchClient, channel: NixChannel): string {.inline.} =
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


proc prepQuery*(query: NixSearchQuery): NixSearchQueryJson =
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


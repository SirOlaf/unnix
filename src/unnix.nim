import std/[
  algorithm,
  options,
  os,
  strutils,
  sequtils,
  sets,

  posix,
]

import search_client
import elastic_matchers


proc isRoot(): bool {.inline.} =
  getuid() == 0


proc getSimpleProgramsPath(): string {.inline.} =
  result = getEnv("UNNIX_SIMPLE_PROGRAMS")
  if result == "":
    echo "You may have forgotten to set the UNNIX_SIMPLE_PROGRAMS environment variable"
    quit(0)


proc loadSimplePrograms(): HashSet[string] =
  if fileExists(getSimpleProgramsPath()):
    let
      contents = readFile(getSimpleProgramsPath())
      progStart = contents.find("[")
      progEnd = contents.find("];")
      progSlice = contents[progStart+1 ..< progEnd]
    progSlice.splitLines().mapIt(it.strip()).filterIt(it.len() > 0).sorted().toHashSet()
  else:
    initHashSet[string]()

proc buildSimpleProgramFile(progs: HashSet[string]): string =
  const
    part1 = """
{pkgs, config, ...}:
{
  environment.systemPackages = with pkgs; [
    """

  result = part1
  result &= progs.toSeq().sorted().join("\n    ") & "\n"
  result &= "  ];\n}"

proc writeSimpleProgramFile(progs: HashSet[string]) {.inline.} =
  # TODO: Create parent dirs if needed
  writeFile(getSimpleProgramsPath(), progs.buildSimpleProgramFile())



proc doNixosRebuild() =
  # TODO: Return error code?
  discard os.execShellCmd("sudo nixos-rebuild switch")

proc presentPackage(package: NixSearchRespPackage, packageIdx: int, installedPackages: HashSet[string]) =
  stdout.write "  ", packageIdx, " ", package.packagePname
  if package.packagePname in installedPackages:
    stdout.write " [Installed]"
  echo ""
  echo "    ", package.packageDescription

proc doInstall(progName: string) =
  var curProgs = loadSimplePrograms()

  var client = newNixSearchClient()
  let webPackages = client.queryPackages(
    NixSearchQuery(
      maxResults : 10,
      name : some MatchName(name : progName)
    )
  )

  var idx = webPackages.len()
  for package in webPackages:
    presentPackage(package, idx, curProgs)
    dec idx

  stdout.write ":: "
  # TODO: Allow stuff like ranges and handle bad input so we don't just crash
  let packIdx = stdin.readLine().parseInt()

  curProgs.incl(webPackages[webPackages.len() - packIdx].packagePname)
  curProgs.writeSimpleProgramFile()
  doNixosRebuild()


proc doUninstall(progName: string) =
  var curProgs = loadSimplePrograms()
  if progName notin curProgs:
    echo progName & " isn't installed!"
    return

  curProgs.excl(progName)
  curProgs.writeSimpleProgramFile()
  doNixosRebuild()



proc main() =
  #if not isRoot():
  #  echo "This needs to be run as root for now"
  #  return

  # TODO: Use parseopt or something for cli
  let modeStr = paramStr(1)
  case modeStr
  of "install":
    doInstall(paramStr(2).toLower())
  of "uninstall":
    doUninstall(paramStr(2).toLower())


when isMainModule:
  main()
  #let progs = loadSimplePrograms()
  #echo progs.buildSimpleProgramFile()

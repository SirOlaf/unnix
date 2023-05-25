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

proc isUnfree(package: NixSearchRespPackage): bool {.inline.} =
  package.packageLicense.anyIt(it.fullName == "Unfree")


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
  stdout.write "  ", packageIdx, " ", package.packageAttrName, " (", package.packagePname, ")"
  if package.packageLicense.anyIt(it.fullName == "Unfree"):
    stdout.write " {UNFREE}"
  if package.packageAttrName in installedPackages:
    stdout.write " [Installed]"
  echo ""
  echo "    ", package.packageDescription

proc doPackageSelect(packages: seq[NixSearchRespPackage], highlightInstalled: bool, installedPackages=none(HashSet[string])): seq[NixSearchRespPackage] =
  var idx = packages.len()
  for package in packages.reversed():
    presentPackage(package, idx, installedPackages.get(initHashSet[string]()))
    dec idx

  stdout.write ":: "
  # TODO: Allow stuff like ranges and handle bad input so we don't just crash
  let packIdx = stdin.readLine().parseInt()
  result.add(packages[packIdx - 1])


template pkgWrapNix(installedPkgs, body: untyped): untyped =
  var client = newNixSearchClient()
  let webPackages = client.queryPackages(
    NixSearchQuery(
      maxResults : 10,
      search : some MatchSearch(search : progName)
    )
  )

  let selectedPackages {.inject, used.} = doPackageSelect(
    packages = webPackages,
    highlightInstalled = true,
    installedPackages = installedPkgs,
  )
  body

template wrapUnfreeNixCommand(package: NixSearchRespPackage, body: untyped) =
  let pkg = package
  if pkg.isUnfree():
    stdout.write(pkg.packageAttrName & " is unfree. Do you want to let nix continue? (y/n) ")
    var resp = stdin.readLine().strip()
    while resp[0] notin { 'y', 'n' }:
      resp = stdin.readLine().strip()
    if resp[0] == 'n':
      echo "Cancelled " & pkg.packageAttrName & ""
      return
    else:
      echo "Continuing..."
  body


proc doInstall(progName: string) =
  var curProgs = loadSimplePrograms()

  pkgWrapNix(some curProgs):
    for package in selectedPackages:
      curProgs.incl(package.packageAttrName)
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

proc doShell(progName: string) =
  pkgWrapNix(none HashSet[string]):
    for package in selectedPackages:
      wrapUnfreeNixCommand(package):
        if package.isUnfree():
          discard os.execShellCmd("NIXPKGS_ALLOW_UNFREE=1 nix shell --impure nixpkgs#" & package.packageAttrName)
        else:
          discard os.execShellCmd("nix shell nixpkgs#" & package.packageAttrName)

proc doRun(progName: string) =
  pkgWrapNix(none HashSet[string]):
    doAssert selectedPackages.len() == 1
    wrapUnfreeNixCommand(selectedPackages[0]):
      if selectedPackages[0].isUnfree():
        discard os.execShellCmd("NIXPKGS_ALLOW_UNFREE=1 nix run --impure nixpkgs#" & selectedPackages[0].packageAttrName)
      else:
        discard os.execShellCmd("nix run nixpkgs#" & selectedPackages[0].packageAttrName)


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
  of "shell":
    doShell(paramStr(2).toLower())
  of "run":
    doRun(paramStr(2).toLower())


when isMainModule:
  main()
  #let progs = loadSimplePrograms()
  #echo progs.buildSimpleProgramFile()

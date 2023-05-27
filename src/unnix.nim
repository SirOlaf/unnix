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


proc getSimpleProgramsPath(required = true): string {.inline.} =
  result = getEnv("UNNIX_SIMPLE_PROGRAMS")
  if result == "" and required:
    echo "You may have forgotten to set the UNNIX_SIMPLE_PROGRAMS environment variable"
    quit(0)


proc loadSimplePrograms(requireProgfile = true): HashSet[string] =
  let progPath = getSimpleProgramsPath(requireProgfile).strip()

  if progPath.len() > 0 and fileExists(progPath):
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
  stdout.write "  ", packageIdx, " ", package.packageAttrName, " (", package.packagePname, "; ", package.packagePversion, ")"
  if package.packageLicense.anyIt(it.fullName == "Unfree"):
    stdout.write " {UNFREE}"
  if package.packageAttrName in installedPackages:
    stdout.write " [Installed]"
  echo ""
  echo "    ", package.packageDescription

proc presentPackages(packages: seq[NixSearchRespPackage], highlightInstalled: bool, installedPackages=none(HashSet[string])) =
  var idx = packages.len()
  for package in packages.reversed():
    presentPackage(package, idx, installedPackages.get(initHashSet[string]()))
    dec idx

proc doPackageSelect(packages: seq[NixSearchRespPackage], highlightInstalled: bool, installedPackages=none(HashSet[string])): seq[NixSearchRespPackage] =
  presentPackages(packages, highlightInstalled, installedPackages)

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

proc readUserYNResp(defaultInput="y"): bool =
  var resp = stdin.readLine().strip()
  if resp.len() == 0:
    resp = defaultInput
  while resp[0] notin { 'y', 'n' }:
    resp = stdin.readLine().strip()
    if resp.len() == 0:
      resp = defaultInput
  resp == "y"

template wrapUnfreeNixCommand(package: NixSearchRespPackage, body: untyped) =
  let pkg = package
  if pkg.isUnfree():
    stdout.write(pkg.packageAttrName & " is unfree. Do you want to let nix continue? (Y/n) ")
    if readUserYNResp():
      echo "Continuing..."
    else:
      echo "Cancelled " & pkg.packageAttrName
      return
  body


proc install(progNames: seq[string]) =
  let prevProgs = loadSimplePrograms()
  var curProgs = prevProgs

  doAssert progNames.len() >= 1

  if progNames.len() > 1:
    for progName in progNames:
      var client = newNixSearchClient()
      let webPackages = client.queryPackages(
        NixSearchQuery(
          maxResults : 1,
          name : some MatchName(name : progName, exact : true)
        )
      )
      if webPackages.len() == 0:
        echo "Could not find package " & progName
        curProgs = prevProgs
        break
      curProgs.incl(progName)
  else:
    let progName = progNames[0]

    pkgWrapNix(some curProgs):
      for package in selectedPackages:
        curProgs.incl(package.packageAttrName)
  if curProgs != prevProgs:
    curProgs.writeSimpleProgramFile()
    doNixosRebuild()


proc uninstall(progNames: seq[string]) =
  let prevProgs = loadSimplePrograms()
  var curProgs = prevProgs

  for progName in progNames:
    if progName notin curProgs:
      echo progName & " isn't installed!"
      if progNames.len() == 1:
        return

    curProgs.excl(progName)
  if curProgs != prevProgs:
    curProgs.writeSimpleProgramFile()
    doNixosRebuild()

proc shell(progName: seq[string]) =
  doAssert progName.len() == 1
  # TODO: Handle multishell
  var progName = progName[0]
  pkgWrapNix(none HashSet[string]):
    for package in selectedPackages:
      wrapUnfreeNixCommand(package):
        if package.isUnfree():
          discard os.execShellCmd("NIXPKGS_ALLOW_UNFREE=1 nix shell --impure nixpkgs#" & package.packageAttrName)
        else:
          discard os.execShellCmd("nix shell nixpkgs#" & package.packageAttrName)

proc run(progName: seq[string]) =
  # TODO: Find better way to forbid multirun
  doAssert progName.len() == 1
  var progname = progName[0]
  pkgWrapNix(none HashSet[string]):
    doAssert selectedPackages.len() == 1
    wrapUnfreeNixCommand(selectedPackages[0]):
      if selectedPackages[0].isUnfree():
        discard os.execShellCmd("NIXPKGS_ALLOW_UNFREE=1 nix run --impure nixpkgs#" & selectedPackages[0].packageAttrName)
      else:
        discard os.execShellCmd("nix run nixpkgs#" & selectedPackages[0].packageAttrName)

proc search(progName: seq[string]) =
  doAssert progName.len() == 1
  let installedProgs = loadSimplePrograms(requireProgfile=false)
  var client = newNixSearchClient()
  let webPackages = client.queryPackages(
    NixSearchQuery(
      maxResults : 10,
      search : some MatchSearch(search : progName[0])
    )
  )
  presentPackages(
    packages = webPackages,
    highlightInstalled = true, 
    installedPackages = some installedProgs
  )


when isMainModule:
  import cligen
  dispatchMulti(
    [install],
    [uninstall],
    [shell],
    [run],
    [search],
  )
  #main()
  #let progs = loadSimplePrograms()
  #echo progs.buildSimpleProgramFile()

import std/[
  algorithm,
  os,
  strutils,
  sequtils,
  sets,

  posix,
]


proc isRoot(): bool {.inline.} =
  getuid() == 0


proc getSimpleProgramsPath(): string {.inline.} =
  getHomeDir() & "unnixer/simple_programs.nix"


proc loadSimplePrograms(): HashSet[string] =
  let
    contents = readFile(getSimpleProgramsPath())
    progStart = contents.find("[")
    progEnd = contents.find("];")
    progSlice = contents[progStart+1 ..< progEnd]
  progSlice.splitLines().mapIt(it.strip()).filterIt(it.len() > 0).sorted().toHashSet()

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
  writeFile(getSimpleProgramsPath(), progs.buildSimpleProgramFile())



proc doNixosRebuild() =
  # TODO: Return error code?
  discard os.execShellCmd("sudo nixos-rebuild switch")

proc doInstall(progName: string) =
  var curProgs = loadSimplePrograms()
  if progName in curProgs:
    echo progName & " is already installed!"
    return

  curProgs.incl(progName)
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

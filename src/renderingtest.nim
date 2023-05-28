import os
import strutils

import illwill

import rendering


illwillInit()
setControlCHook(illwillExitProc)
hideCursor()


var tb = newTerminalBuffer(terminalWidth(), terminalHeight())

tb.setForegroundColor(fgBlack, true)

let testData = @[
  @[
    "name", "type", "value", "description"
  ],
  @[
    "services.mullvad-vpn.package", "package", "pkgs.mullvad", "The Mullvad package to use. pkgs.mullvad only provides the CLI tool, pkgs.mullvad-vpn provides both the CLI and the GUI."
  ],
  @[
    "services.mullvad-vpn.enableExcludeWrapper", "boolean", "true", "This option activates the wrapper that allows the use of mullvad-exclude. Might have minor security impact, so consider disabling if you do not use the feature."
  ],
  @[
    "service.mullvad.enable", "boolean", "false", "This option enables Mullvad VPN daemon. This sets networking.firewall.checkReversePath to “loose”, which might be undesirable for security."
  ],
]

proc onHover(self: var InteractiveTableState, tb: var TerminalBuffer) =
  let
    x = self.posX + self.width + 1
    y = 1
    width = tb.width() - x

  let desc = self.fullData[self.hoveredRow][3].split(" ")

  var
    chunks = newSeq[string]()
    curChunk = ""
  for part in desc:
    if curChunk.len() + part.len() > width:
      chunks.add(curChunk)
      curChunk = ""
    curChunk &= " " & part
  if curChunk.len() > 0:
    chunks.add(curChunk)

  let oldFG = tb.getForegroundColor()
  tb.setForegroundColor(fgWhite, false)

  var yoff = 0
  for chunk in chunks:
    tb.write(x, y + yoff, chunk)
    inc yoff

  tb.setForegroundColor(oldFG, false)


var table = initInteractiveTableState(
  x = 0, y = 0,
  maxColumnWidth = 50,
  height = tb.height,
  fullData = testData,
)
table.onHover = onHover


var selectedRow = 0
var ticks = 0
while true:
  var key = getKey()
  case key
  of Key.Up: dec selectedRow
  of Key.Down: inc selectedRow
  of Key.Enter:
    if table.fullData[table.hoveredRow][1] == "boolean":
      table.fullData[table.hoveredRow][2] = if table.fullData[table.hoveredRow][2] == "false": "true" else: "false"
  else:
    discard

  selectedRow = clamp(selectedRow, 1, 3)
  table.hoveredRow = selectedRow
  tb.clear(" ")

  tb.drawInteractiveTable(table)


  tb.display()
  sleep(20)
  inc ticks

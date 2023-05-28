import os

import illwill

import rendering


illwillInit()
setControlCHook(illwillExitProc)
hideCursor()


var tb = newTerminalBuffer(terminalWidth(), terminalHeight())

tb.setForegroundColor(fgBlack, true)

let testData = @[
  @[
    "name", "type", "default", "description"
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


var table = initInteractiveTableState(
  x = 0, y = 0,
  maxColumnWidth = 70,
  height = tb.height,
  fullData = testData
)


var selectedRow = 0
while true:
  var key = getKey()
  case key
  of Key.Up: dec selectedRow
  of Key.Down: inc selectedRow
  else:
    discard

  selectedRow = clamp(selectedRow, 1, 3)
  table.hoveredRow = selectedRow

  tb.drawInteractiveTable(table)

  tb.display()
  sleep(20)

import os

import illwill

import rendering


illwillInit()
setControlCHook(illwillExitProc)
hideCursor()


var tb = newTerminalBuffer(terminalWidth(), terminalHeight())

tb.setForegroundColor(fgBlack, true)

tb.drawTable(0, 0, 4, 100, 5, 5, @[
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
])

while true:
  tb.display()
  sleep(20)

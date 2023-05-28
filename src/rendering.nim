import illwill


proc exitIllwill*() =
  illwillDeinit()
  showCursor()

proc illwillExitProc*() {.noconv.} =
  exitIllwill()
  quit(0)


proc drawTable*(tb: var TerminalBuffer, atX, atY: int, columns: int, tableWidth: int, tableHeight: int, displayRows: int, data: seq[seq[string]]) =
  let
    columnWidth = tableWidth div columns
    showableRows = min(data.len(), displayRows)

  var bb = newBoxBuffer(tb.width, tb.height)
  for i in 0 .. columns:
    bb.drawVertLine(
      atX + i * columnWidth, atY, tb.height(),
    )

  bb.drawHorizLine(atX, atX+tableWidth-1, atY+1, connect=true)
  tb.write(bb)

  for y in 0 ..< showableRows:
    let row = data[y]
    for x in 0 ..< columns:
      let val = row[x]
      tb.write(x * columnWidth + 1, atY + y + (if y == 0: 0 else: 1), val[0 ..< min(columnWidth - 1, val.len())])

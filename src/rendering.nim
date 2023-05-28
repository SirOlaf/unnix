import illwill


proc exitIllwill*() =
  illwillDeinit()
  showCursor()

proc illwillExitProc*() {.noconv.} =
  exitIllwill()
  quit(0)


type
  InteractiveTableState* = object
    fullData*: seq[seq[string]]
    columns*: int
    posX*, posY*: int
    width*, height*: int
    hoveredRow*: int
    columnWidths*: seq[int]
    columnPositions*: seq[int]
    onHover*: proc(self: var InteractiveTableState, tb: var TerminalBuffer) {.nimcall.}


proc initInteractiveTableState*(x, y: int, maxColumnWidth: int, height: int, fullData: seq[seq[string]]): InteractiveTableState =
  result.fullData = fullData
  result.columns = result.fullData[0].len()
  result.posX = x
  result.posY = y

  result.columnWidths = newSeq[int](result.columns)
  result.columnPositions = newSeq[int](result.columns)
  for row in result.fullData:
    for i in 0 ..< result.columns:
      let col = row[i].len() + 1
      if col <= maxColumnWidth and col > result.columnWidths[i]:
        result.columnWidths[i] = col
      elif col >= maxColumnWidth:
        result.columnWidths[i] = maxColumnWidth
  var off = 0
  for i in 0 ..< result.columns:
    let width = result.columnWidths[i]
    result.columnPositions[i] = off
    off += width
  result.columnPositions.add(result.columnPositions[^1] + result.columnWidths[^1])
  result.width = result.columnPositions[^2] + result.columnWidths[^1]
  result.height = height



proc drawInteractiveTable*(tb: var TerminalBuffer, state: var InteractiveTableState) =
  let oldFG = tb.getForegroundColor()
  tb.setForegroundColor(fgWhite, false)
  var bb = newBoxBuffer(state.width + 1, state.height)
  for x in state.columnPositions:
    bb.drawVertLine(
      state.posX + x, state.posY, state.height
    )
  bb.drawVertLine(state.posX + state.width + 1, state.posY, state.height)

  bb.drawHorizLine(state.posX, state.posX+state.width, state.posY+1, connect=true)
  tb.write(bb)
  tb.setForegroundColor(oldFG, false)

  for y in 0 ..< state.fullData.len():
    let oldFG = tb.getForegroundColor()
    if y == state.hoveredRow:
      tb.setForegroundColor(fgWhite, true)
    let row = state.fullData[y]
    for x in 0 ..< state.columns:
      let val = row[x]
      tb.write(state.posX + state.columnPositions[x] + 1, state.posY + y + (if y == 0: 0 else: 1), val[0 ..< min(val.len(), state.columnWidths[x] - 1)])
    tb.setForegroundColor(oldFG, false)
    if state.onHover != nil:
      state.onHover(state, tb)

proc hoverRow*(self: var InteractiveTableState, row: int) =
  self.hoveredRow = row

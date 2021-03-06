#
#
#           The Nimrod Compiler
#        (c) Copyright 2014 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## This module implements the code generator for the VM.

import
  unsigned, strutils, ast, astalgo, types, msgs, renderer, vmdef, 
  trees, intsets, rodread, magicsys, options

from os import splitFile

when hasFFI:
  import evalffi

type
  TGenFlag = enum gfNone, gfAddrOf
  TGenFlags = set[TGenFlag]

proc debugInfo(info: TLineInfo): string =
  result = info.toFilename.splitFile.name & ":" & $info.line

proc codeListing(c: PCtx, result: var string, start=0) =
  # first iteration: compute all necessary labels:
  var jumpTargets = initIntSet()
  
  for i in start.. < c.code.len:
    let x = c.code[i]
    if x.opcode in relativeJumps:
      jumpTargets.incl(i+x.regBx-wordExcess)

  # for debugging purposes
  var i = start
  while i < c.code.len:
    if i in jumpTargets: result.addf("L$1:\n", i)
    let x = c.code[i]

    let opc = opcode(x)
    if opc < firstABxInstr:
      result.addf("\t$#\tr$#, r$#, r$#", ($opc).substr(3), x.regA, 
                  x.regB, x.regC)
    elif opc in relativeJumps:
      result.addf("\t$#\tr$#, L$#", ($opc).substr(3), x.regA,
                  i+x.regBx-wordExcess)
    elif opc in {opcLdConst, opcAsgnConst}:
      result.addf("\t$#\tr$#, $#", ($opc).substr(3), x.regA, 
        c.constants[x.regBx-wordExcess].renderTree)
    else:
      result.addf("\t$#\tr$#, $#", ($opc).substr(3), x.regA, x.regBx-wordExcess)
    result.add("\t#")
    result.add(debugInfo(c.debug[i]))
    result.add("\n")
    inc i

proc echoCode*(c: PCtx, start=0) {.deprecated.} =
  var buf = ""
  codeListing(c, buf, start)
  echo buf

proc gABC(ctx: PCtx; n: PNode; opc: TOpcode; a, b, c: TRegister = 0) =
  assert opc.ord < 255
  let ins = (opc.uint32 or (a.uint32 shl 8'u32) or
                           (b.uint32 shl 16'u32) or
                           (c.uint32 shl 24'u32)).TInstr
  ctx.code.add(ins)
  ctx.debug.add(n.info)

proc gABI(c: PCtx; n: PNode; opc: TOpcode; a, b: TRegister; imm: BiggestInt) =
  let ins = (opc.uint32 or (a.uint32 shl 8'u32) or
                           (b.uint32 shl 16'u32) or
                           (imm+byteExcess).uint32 shl 24'u32).TInstr
  c.code.add(ins)
  c.debug.add(n.info)

proc gABx(c: PCtx; n: PNode; opc: TOpcode; a: TRegister = 0; bx: int) =
  let ins = (opc.uint32 or a.uint32 shl 8'u32 or 
            (bx+wordExcess).uint32 shl 16'u32).TInstr
  c.code.add(ins)
  c.debug.add(n.info)

proc xjmp(c: PCtx; n: PNode; opc: TOpcode; a: TRegister = 0): TPosition =
  #assert opc in {opcJmp, opcFJmp, opcTJmp}
  result = TPosition(c.code.len)
  gABx(c, n, opc, a, 0)

proc genLabel(c: PCtx): TPosition =
  result = TPosition(c.code.len)
  #c.jumpTargets.incl(c.code.len)

proc jmpBack(c: PCtx, n: PNode, opc: TOpcode, p = TPosition(0)) =
  let dist = p.int - c.code.len
  internalAssert(-0x7fff < dist and dist < 0x7fff)
  gABx(c, n, opc, 0, dist)

proc patch(c: PCtx, p: TPosition) =
  # patch with current index
  let p = p.int
  let diff = c.code.len - p
  #c.jumpTargets.incl(c.code.len)
  internalAssert(-0x7fff < diff and diff < 0x7fff)
  let oldInstr = c.code[p]
  # opcode and regA stay the same:
  c.code[p] = ((oldInstr.uint32 and 0xffff'u32).uint32 or
               uint32(diff+wordExcess) shl 16'u32).TInstr

proc getSlotKind(t: PType): TSlotKind =
  case t.skipTypes(abstractRange-{tyTypeDesc}).kind
  of tyBool, tyChar, tyEnum, tyOrdinal, tyInt..tyInt64, tyUInt..tyUInt64:
    slotTempInt
  of tyString, tyCString:
    slotTempStr
  of tyFloat..tyFloat128:
    slotTempFloat
  else:
    slotTempComplex

const
  HighRegisterPressure = 40

proc getTemp(c: PCtx; typ: PType): TRegister =
  let c = c.prc
  # we prefer the same slot kind here for efficiency. Unfortunately for
  # discardable return types we may not know the desired type. This can happen
  # for e.g. mNAdd[Multiple]:
  let k = if typ.isNil: slotTempComplex else: typ.getSlotKind
  for i in 0 .. c.maxSlots-1:
    if c.slots[i].kind == k and not c.slots[i].inUse:
      c.slots[i].inUse = true
      return TRegister(i)
      
  # if register pressure is high, we re-use more aggressively:
  if c.maxSlots >= HighRegisterPressure:
    for i in 0 .. c.maxSlots-1:
      if not c.slots[i].inUse:
        c.slots[i] = (inUse: true, kind: k)
        return TRegister(i)
  result = TRegister(c.maxSlots)
  c.slots[c.maxSlots] = (inUse: true, kind: k)
  inc c.maxSlots

proc getGlobalSlot(c: PCtx; n: PNode; s: PSym): TRegister =
  let p = c.prc
  for i in 0 .. p.maxSlots-1:
    if p.globals[i] == s.id: return TRegister(i)

  result = TRegister(p.maxSlots)
  p.slots[p.maxSlots] = (inUse: true, kind: slotFixedVar)
  p.globals[p.maxSlots] = s.id
  inc p.maxSlots
  # XXX this is still not correct! We need to load the global in a proc init
  # section, otherwise control flow could lead to a usage before it's been
  # loaded.
  c.gABx(n, opcGlobalAlias, result, s.position)
  # XXX add some internal asserts here

proc freeTemp(c: PCtx; r: TRegister) =
  let c = c.prc
  if c.slots[r].kind >= slotSomeTemp: c.slots[r].inUse = false

proc getTempRange(c: PCtx; n: int; kind: TSlotKind): TRegister =
  # if register pressure is high, we re-use more aggressively:
  let c = c.prc
  if c.maxSlots >= HighRegisterPressure or c.maxSlots+n >= high(TRegister):
    for i in 0 .. c.maxSlots-n:
      if not c.slots[i].inUse:
        block search:
          for j in i+1 .. i+n-1:
            if c.slots[j].inUse: break search
          result = TRegister(i)
          for k in result .. result+n-1: c.slots[k] = (inUse: true, kind: kind)
          return
  if c.maxSlots+n >= high(TRegister):
    internalError("cannot generate code; too many registers required")
  result = TRegister(c.maxSlots)
  inc c.maxSlots, n
  for k in result .. result+n-1: c.slots[k] = (inUse: true, kind: kind)
  
proc freeTempRange(c: PCtx; start: TRegister, n: int) =
  for i in start .. start+n-1: c.freeTemp(TRegister(i))

template withTemp(tmp, typ: expr, body: stmt) {.immediate, dirty.} =
  var tmp = getTemp(c, typ)
  body
  c.freeTemp(tmp)

proc popBlock(c: PCtx; oldLen: int) =  
  for f in c.prc.blocks[oldLen].fixups:
    c.patch(f)
  c.prc.blocks.setLen(oldLen)

template withBlock(labl: PSym; body: stmt) {.immediate, dirty.} =
  var oldLen {.gensym.} = c.prc.blocks.len
  c.prc.blocks.add TBlock(label: labl, fixups: @[])
  body
  popBlock(c, oldLen)

proc gen(c: PCtx; n: PNode; dest: var TDest; flags: TGenFlags = {})
proc gen(c: PCtx; n: PNode; dest: TRegister; flags: TGenFlags = {}) =
  var d: TDest = dest
  gen(c, n, d, flags)
  internalAssert d == dest

proc gen(c: PCtx; n: PNode; flags: TGenFlags = {}) =
  var tmp: TDest = -1
  gen(c, n, tmp, flags)
  #if n.typ.isEmptyType: InternalAssert tmp < 0

proc genx(c: PCtx; n: PNode; flags: TGenFlags = {}): TRegister =
  var tmp: TDest = -1
  gen(c, n, tmp, flags)
  internalAssert tmp >= 0
  result = TRegister(tmp)

proc clearDest(c: PCtx; n: PNode; dest: var TDest) {.inline.} =
  # stmt is different from 'void' in meta programming contexts.
  # So we only set dest to -1 if 'void':
  if dest >= 0 and (n.typ.isNil or n.typ.kind == tyEmpty):
    c.freeTemp(dest)
    dest = -1

proc isNotOpr(n: PNode): bool =
  n.kind in nkCallKinds and n.sons[0].kind == nkSym and
    n.sons[0].sym.magic == mNot

proc isTrue(n: PNode): bool =
  n.kind == nkSym and n.sym.kind == skEnumField and n.sym.position != 0 or
    n.kind == nkIntLit and n.intVal != 0

proc genWhile(c: PCtx; n: PNode) =
  # L1:
  #   cond, tmp
  #   fjmp tmp, L2
  #   body
  #   jmp L1
  # L2:
  let L1 = c.genLabel
  withBlock(nil):
    if isTrue(n.sons[0]):
      c.gen(n.sons[1])
      c.jmpBack(n, opcJmp, L1)
    elif isNotOpr(n.sons[0]):
      var tmp = c.genx(n.sons[0].sons[1])
      let L2 = c.xjmp(n, opcTJmp, tmp)
      c.freeTemp(tmp)
      c.gen(n.sons[1])
      c.jmpBack(n, opcJmp, L1)
      c.patch(L2)
    else:
      var tmp = c.genx(n.sons[0])
      let L2 = c.xjmp(n, opcFJmp, tmp)
      c.freeTemp(tmp)
      c.gen(n.sons[1])
      c.jmpBack(n, opcJmp, L1)
      c.patch(L2)

proc genBlock(c: PCtx; n: PNode; dest: var TDest) =
  withBlock(n.sons[0].sym):
    c.gen(n.sons[1], dest)
  c.clearDest(n, dest)

proc genBreak(c: PCtx; n: PNode) =
  let L1 = c.xjmp(n, opcJmp)
  if n.sons[0].kind == nkSym:
    #echo cast[int](n.sons[0].sym)
    for i in countdown(c.prc.blocks.len-1, 0):
      if c.prc.blocks[i].label == n.sons[0].sym:
        c.prc.blocks[i].fixups.add L1
        return
    internalError(n.info, "cannot find 'break' target")
  else:
    c.prc.blocks[c.prc.blocks.high].fixups.add L1

proc genIf(c: PCtx, n: PNode; dest: var TDest) =
  #  if (!expr1) goto L1;
  #    thenPart
  #    goto LEnd
  #  L1:
  #  if (!expr2) goto L2;
  #    thenPart2
  #    goto LEnd
  #  L2:
  #    elsePart
  #  Lend:
  if dest < 0 and not isEmptyType(n.typ): dest = getTemp(c, n.typ)
  var endings: seq[TPosition] = @[]
  for i in countup(0, len(n) - 1):
    var it = n.sons[i]
    if it.len == 2:
      withTemp(tmp, it.sons[0].typ):
        var elsePos: TPosition
        if isNotOpr(it.sons[0]):
          c.gen(it.sons[0].sons[1], tmp)
          elsePos = c.xjmp(it.sons[0].sons[1], opcTJmp, tmp) # if true
        else:
          c.gen(it.sons[0], tmp)
          elsePos = c.xjmp(it.sons[0], opcFJmp, tmp) # if false
      c.clearDest(n, dest)
      c.gen(it.sons[1], dest) # then part
      if i < sonsLen(n)-1:
        endings.add(c.xjmp(it.sons[1], opcJmp, 0))
      c.patch(elsePos)
    else:
      c.clearDest(n, dest)
      c.gen(it.sons[0], dest)
  for endPos in endings: c.patch(endPos)
  c.clearDest(n, dest)

proc genAndOr(c: PCtx; n: PNode; opc: TOpcode; dest: var TDest) =
  #   asgn dest, a
  #   tjmp|fjmp L1
  #   asgn dest, b
  # L1:
  if dest < 0: dest = getTemp(c, n.typ)
  c.gen(n.sons[1], dest)
  let L1 = c.xjmp(n, opc, dest)
  c.gen(n.sons[2], dest)
  c.patch(L1)

proc nilLiteral(n: PNode): PNode =
  if n.kind == nkNilLit and n.typ.sym != nil and
       n.typ.sym.magic == mPNimrodNode:
    let nilo = newNodeIT(nkNilLit, n.info, n.typ)
    result = newNodeIT(nkMetaNode, n.info, n.typ)
    result.add nilo
  else:
    result = n

proc rawGenLiteral(c: PCtx; n: PNode): int =
  result = c.constants.len
  c.constants.add n.nilLiteral
  internalAssert result < 0x7fff

proc sameConstant*(a, b: PNode): bool =
  result = false
  if a == b:
    result = true
  elif a != nil and b != nil and a.kind == b.kind:
    case a.kind
    of nkSym: result = a.sym == b.sym
    of nkIdent: result = a.ident.id == b.ident.id
    of nkCharLit..nkInt64Lit: result = a.intVal == b.intVal
    of nkFloatLit..nkFloat64Lit: result = a.floatVal == b.floatVal
    of nkStrLit..nkTripleStrLit: result = a.strVal == b.strVal
    of nkType: result = a.typ == b.typ
    of nkEmpty, nkNilLit: result = true
    else: 
      if sonsLen(a) == sonsLen(b): 
        for i in countup(0, sonsLen(a) - 1): 
          if not sameConstant(a.sons[i], b.sons[i]): return 
        result = true

proc genLiteral(c: PCtx; n: PNode): int =
  # types do not matter here:
  for i in 0 .. <c.constants.len:
    if sameConstant(c.constants[i], n): return i
  result = rawGenLiteral(c, n)

proc unused(n: PNode; x: TDest) {.inline.} =
  if x >= 0: 
    #debug(n)
    internalError(n.info, "not unused")

proc genCase(c: PCtx; n: PNode; dest: var TDest) =
  #  if (!expr1) goto L1;
  #    thenPart
  #    goto LEnd
  #  L1:
  #  if (!expr2) goto L2;
  #    thenPart2
  #    goto LEnd
  #  L2:
  #    elsePart
  #  Lend:
  if not isEmptyType(n.typ):
    if dest < 0: dest = getTemp(c, n.typ)
  else:
    unused(n, dest)
  var endings: seq[TPosition] = @[]
  withTemp(tmp, n.sons[0].typ):
    c.gen(n.sons[0], tmp)
    # branch tmp, codeIdx
    # fjmp   elseLabel
    for i in 1 .. <n.len:
      let it = n.sons[i]
      if it.len == 1:
        # else stmt:
        c.gen(it.sons[0], dest)
      else:
        let b = rawGenLiteral(c, it)
        c.gABx(it, opcBranch, tmp, b)
        let elsePos = c.xjmp(it.lastSon, opcFJmp, tmp)
        c.gen(it.lastSon, dest)
        if i < sonsLen(n)-1:
          endings.add(c.xjmp(it.lastSon, opcJmp, 0))
        c.patch(elsePos)
      c.clearDest(n, dest)
  for endPos in endings: c.patch(endPos)

proc genType(c: PCtx; typ: PType): int =
  for i, t in c.types:
    if sameType(t, typ): return i
  result = c.types.len
  c.types.add(typ)
  internalAssert(result <= 0x7fff)

proc genTry(c: PCtx; n: PNode; dest: var TDest) =
  if dest < 0 and not isEmptyType(n.typ): dest = getTemp(c, n.typ)
  var endings: seq[TPosition] = @[]
  let elsePos = c.xjmp(n, opcTry, 0)
  c.gen(n.sons[0], dest)
  c.clearDest(n, dest)
  c.patch(elsePos)
  for i in 1 .. <n.len:
    let it = n.sons[i]
    if it.kind != nkFinally:
      var blen = len(it)
      # first opcExcept contains the end label of the 'except' block:
      let endExcept = c.xjmp(it, opcExcept, 0)
      for j in countup(0, blen - 2): 
        assert(it.sons[j].kind == nkType)
        let typ = it.sons[j].typ.skipTypes(abstractPtrs-{tyTypeDesc})
        c.gABx(it, opcExcept, 0, c.genType(typ))
      if blen == 1: 
        # general except section:
        c.gABx(it, opcExcept, 0, 0)
      c.gen(it.lastSon, dest)
      c.clearDest(n, dest)
      if i < sonsLen(n)-1:
        endings.add(c.xjmp(it, opcJmp, 0))
      c.patch(endExcept)
  for endPos in endings: c.patch(endPos)
  let fin = lastSon(n)
  # we always generate an 'opcFinally' as that pops the safepoint
  # from the stack
  c.gABx(fin, opcFinally, 0, 0)
  if fin.kind == nkFinally:
    c.gen(fin.sons[0], dest)
    c.clearDest(n, dest)
  c.gABx(fin, opcFinallyEnd, 0, 0)

proc genRaise(c: PCtx; n: PNode) =
  let dest = genx(c, n.sons[0])
  c.gABC(n, opcRaise, dest)
  c.freeTemp(dest)

proc genReturn(c: PCtx; n: PNode) =
  if n.sons[0].kind != nkEmpty:
    gen(c, n.sons[0])
  c.gABC(n, opcRet)

proc genCall(c: PCtx; n: PNode; dest: var TDest) =
  if dest < 0 and not isEmptyType(n.typ): dest = getTemp(c, n.typ)
  let x = c.getTempRange(n.len, slotTempUnknown)
  # varargs need 'opcSetType' for the FFI support:
  let fntyp = n.sons[0].typ
  for i in 0.. <n.len:
    var r: TRegister = x+i
    c.gen(n.sons[i], r)
    if i >= fntyp.len:
      internalAssert tfVarargs in fntyp.flags
      c.gABx(n, opcSetType, r, c.genType(n.sons[i].typ))
  if dest < 0:
    c.gABC(n, opcIndCall, 0, x, n.len)
  else:
    c.gABC(n, opcIndCallAsgn, dest, x, n.len)
  c.freeTempRange(x, n.len)

proc needsAsgnPatch(n: PNode): bool = 
  n.kind in {nkBracketExpr, nkDotExpr, nkCheckedFieldExpr}

proc genAsgnPatch(c: PCtx; le: PNode, value: TRegister) =
  case le.kind
  of nkBracketExpr:
    let dest = c.genx(le.sons[0])
    let idx = c.genx(le.sons[1])
    c.gABC(le, opcWrArrRef, dest, idx, value)
  of nkDotExpr, nkCheckedFieldExpr:
    # XXX field checks here
    let left = if le.kind == nkDotExpr: le else: le.sons[0]
    let dest = c.genx(left.sons[0])
    let idx = c.genx(left.sons[1])
    c.gABC(left, opcWrObjRef, dest, idx, value)
  else:
    discard

proc genNew(c: PCtx; n: PNode) =
  let dest = if needsAsgnPatch(n.sons[1]): c.getTemp(n.sons[1].typ)
             else: c.genx(n.sons[1])
  # we use the ref's base type here as the VM conflates 'ref object' 
  # and 'object' since internally we already have a pointer.
  c.gABx(n, opcNew, dest, 
         c.genType(n.sons[1].typ.skipTypes(abstractVar-{tyTypeDesc}).sons[0]))
  c.genAsgnPatch(n.sons[1], dest)
  c.freeTemp(dest)

proc genNewSeq(c: PCtx; n: PNode) =
  let dest = if needsAsgnPatch(n.sons[1]): c.getTemp(n.sons[1].typ)
             else: c.genx(n.sons[1])
  let tmp = c.genx(n.sons[2])
  c.gABx(n, opcNewSeq, dest, c.genType(n.sons[1].typ.skipTypes(
                                                  abstractVar-{tyTypeDesc})))
  c.gABx(n, opcNewSeq, tmp, 0)
  c.freeTemp(tmp)
  c.genAsgnPatch(n.sons[1], dest)
  c.freeTemp(dest)

proc genUnaryABC(c: PCtx; n: PNode; dest: var TDest; opc: TOpcode) =
  let tmp = c.genx(n.sons[1])
  if dest < 0: dest = c.getTemp(n.typ)
  c.gABC(n, opc, dest, tmp)
  c.freeTemp(tmp)

proc genUnaryABI(c: PCtx; n: PNode; dest: var TDest; opc: TOpcode) =
  let tmp = c.genx(n.sons[1])
  if dest < 0: dest = c.getTemp(n.typ)
  c.gABI(n, opc, dest, tmp, 0)
  c.freeTemp(tmp)

proc genBinaryABC(c: PCtx; n: PNode; dest: var TDest; opc: TOpcode) =
  let
    tmp = c.genx(n.sons[1])
    tmp2 = c.genx(n.sons[2])
  if dest < 0: dest = c.getTemp(n.typ)
  c.gABC(n, opc, dest, tmp, tmp2)
  c.freeTemp(tmp)
  c.freeTemp(tmp2)

proc genSetType(c: PCtx; n: PNode; dest: TRegister) =
  let t = skipTypes(n.typ, abstractInst-{tyTypeDesc})
  if t.kind == tySet:
    c.gABx(n, opcSetType, dest, c.genType(t))

proc genBinarySet(c: PCtx; n: PNode; dest: var TDest; opc: TOpcode) =
  let
    tmp = c.genx(n.sons[1])
    tmp2 = c.genx(n.sons[2])
  if dest < 0: dest = c.getTemp(n.typ)
  c.genSetType(n.sons[1], tmp)
  c.genSetType(n.sons[2], tmp2)
  c.gABC(n, opc, dest, tmp, tmp2)
  c.freeTemp(tmp)
  c.freeTemp(tmp2)

proc genBinaryStmt(c: PCtx; n: PNode; opc: TOpcode) =
  let
    dest = c.genx(n.sons[1])
    tmp = c.genx(n.sons[2])
  c.gABC(n, opc, dest, tmp, 0)
  c.freeTemp(tmp)

proc genBinaryStmtVar(c: PCtx; n: PNode; opc: TOpcode) =
  let
    dest = c.genx(n.sons[1], {gfAddrOf})
    tmp = c.genx(n.sons[2])
  c.gABC(n, opc, dest, tmp, 0)
  #c.genAsgnPatch(n.sons[1], dest)
  c.freeTemp(tmp)

proc genUnaryStmt(c: PCtx; n: PNode; opc: TOpcode) =
  let tmp = c.genx(n.sons[1])
  c.gABC(n, opc, tmp, 0, 0)
  c.freeTemp(tmp)

proc genVarargsABC(c: PCtx; n: PNode; dest: var TDest; opc: TOpcode) =
  if dest < 0: dest = getTemp(c, n.typ)
  var x = c.getTempRange(n.len-1, slotTempStr)
  for i in 1..n.len-1: 
    var r: TRegister = x+i-1
    c.gen(n.sons[i], r)
  c.gABC(n, opc, dest, x, n.len-1)
  c.freeTempRange(x, n.len)

proc isInt8Lit(n: PNode): bool =
  if n.kind in {nkCharLit..nkUInt64Lit}:
    result = n.intVal >= low(int8) and n.intVal <= high(int8)

proc isInt16Lit(n: PNode): bool =
  if n.kind in {nkCharLit..nkUInt64Lit}:
    result = n.intVal >= low(int16) and n.intVal <= high(int16)

proc genAddSubInt(c: PCtx; n: PNode; dest: var TDest; opc: TOpcode) =
  if n.sons[2].isInt8Lit:
    let tmp = c.genx(n.sons[1])
    if dest < 0: dest = c.getTemp(n.typ)
    c.gABI(n, succ(opc), dest, tmp, n.sons[2].intVal)
    c.freeTemp(tmp)
  else:
    genBinaryABC(c, n, dest, opc)

proc genConv(c: PCtx; n, arg: PNode; dest: var TDest; opc=opcConv) =  
  let tmp = c.genx(arg)
  c.gABx(n, opcSetType, tmp, genType(c, arg.typ))
  if dest < 0: dest = c.getTemp(n.typ)
  c.gABC(n, opc, dest, tmp)
  c.gABx(n, opc, 0, genType(c, n.typ))
  c.freeTemp(tmp)

proc genCard(c: PCtx; n: PNode; dest: var TDest) =
  let tmp = c.genx(n.sons[1])
  if dest < 0: dest = c.getTemp(n.typ)
  c.genSetType(n.sons[1], tmp)
  c.gABC(n, opcCard, dest, tmp)
  c.freeTemp(tmp)

proc genMagic(c: PCtx; n: PNode; dest: var TDest) =
  let m = n.sons[0].sym.magic
  case m
  of mAnd: c.genAndOr(n, opcFJmp, dest)
  of mOr:  c.genAndOr(n, opcTJmp, dest)
  of mUnaryLt:
    let tmp = c.genx(n.sons[1])
    if dest < 0: dest = c.getTemp(n.typ)
    c.gABI(n, opcSubImmInt, dest, tmp, 1)
    c.freeTemp(tmp)
  of mPred, mSubI, mSubI64:
    c.genAddSubInt(n, dest, opcSubInt)
  of mSucc, mAddI, mAddI64:
    c.genAddSubInt(n, dest, opcAddInt)
  of mInc, mDec:
    unused(n, dest)
    var d = c.genx(n.sons[1]).TDest
    c.genAddSubInt(n, d, if m == mInc: opcAddInt else: opcSubInt)
    c.genAsgnPatch(n.sons[1], d)
    c.freeTemp(d.TRegister)
  of mOrd, mChr, mArrToSeq: c.gen(n.sons[1], dest)
  of mNew, mNewFinalize:
    unused(n, dest)
    c.genNew(n)
  of mNewSeq:
    unused(n, dest)
    c.genNewSeq(n)
  of mNewString:
    genUnaryABC(c, n, dest, opcNewStr)
  of mNewStringOfCap:
    # we ignore the 'cap' argument and translate it as 'newString(0)'.
    # eval n.sons[1] for possible side effects:
    var tmp = c.genx(n.sons[1])
    c.gABx(n, opcLdImmInt, tmp, 0)
    if dest < 0: dest = c.getTemp(n.typ)
    c.gABC(n, opcNewStr, dest, tmp)
    c.freeTemp(tmp)
  of mLengthOpenArray, mLengthArray, mLengthSeq:
    genUnaryABI(c, n, dest, opcLenSeq)
  of mLengthStr:
    genUnaryABI(c, n, dest, opcLenStr)
  of mIncl, mExcl:
    unused(n, dest)
    var d = c.genx(n.sons[1])
    var tmp = c.genx(n.sons[2])
    c.genSetType(n.sons[1], d)
    c.gABC(n, if m == mIncl: opcIncl else: opcExcl, d, tmp)
    c.freeTemp(d)
    c.freeTemp(tmp)
  of mCard: genCard(c, n, dest)
  of mMulI, mMulI64: genBinaryABC(c, n, dest, opcMulInt)
  of mDivI, mDivI64: genBinaryABC(c, n, dest, opcDivInt)
  of mModI, mModI64: genBinaryABC(c, n, dest, opcModInt)
  of mAddF64: genBinaryABC(c, n, dest, opcAddFloat)
  of mSubF64: genBinaryABC(c, n, dest, opcSubFloat)
  of mMulF64: genBinaryABC(c, n, dest, opcMulFloat)
  of mDivF64: genBinaryABC(c, n, dest, opcDivFloat)
  of mShrI, mShrI64: genBinaryABC(c, n, dest, opcShrInt)
  of mShlI, mShlI64: genBinaryABC(c, n, dest, opcShlInt)
  of mBitandI, mBitandI64: genBinaryABC(c, n, dest, opcBitandInt)
  of mBitorI, mBitorI64: genBinaryABC(c, n, dest, opcBitorInt)
  of mBitxorI, mBitxorI64: genBinaryABC(c, n, dest, opcBitxorInt)
  of mAddU: genBinaryABC(c, n, dest, opcAddu)
  of mSubU: genBinaryABC(c, n, dest, opcSubu)
  of mMulU: genBinaryABC(c, n, dest, opcMulu)
  of mDivU: genBinaryABC(c, n, dest, opcDivu)
  of mModU: genBinaryABC(c, n, dest, opcModu)
  of mEqI, mEqI64, mEqB, mEqEnum, mEqCh:
    genBinaryABC(c, n, dest, opcEqInt)
  of mLeI, mLeI64, mLeEnum, mLeCh, mLeB:
    genBinaryABC(c, n, dest, opcLeInt)
  of mLtI, mLtI64, mLtEnum, mLtCh, mLtB:
    genBinaryABC(c, n, dest, opcLtInt)
  of mEqF64: genBinaryABC(c, n, dest, opcEqFloat)
  of mLeF64: genBinaryABC(c, n, dest, opcLeFloat)
  of mLtF64: genBinaryABC(c, n, dest, opcLtFloat)
  of mLePtr, mLeU, mLeU64: genBinaryABC(c, n, dest, opcLeu)
  of mLtPtr, mLtU, mLtU64: genBinaryABC(c, n, dest, opcLtu)
  of mEqProc, mEqRef, mEqUntracedRef, mEqCString:
    genBinaryABC(c, n, dest, opcEqRef)
  of mXor: genBinaryABC(c, n, dest, opcXor)
  of mNot: genUnaryABC(c, n, dest, opcNot)
  of mUnaryMinusI, mUnaryMinusI64: genUnaryABC(c, n, dest, opcUnaryMinusInt)
  of mUnaryMinusF64: genUnaryABC(c, n, dest, opcUnaryMinusFloat)
  of mUnaryPlusI, mUnaryPlusI64, mUnaryPlusF64: gen(c, n.sons[1], dest)
  of mBitnotI, mBitnotI64: genUnaryABC(c, n, dest, opcBitnotInt)
  of mZe8ToI, mZe8ToI64, mZe16ToI, mZe16ToI64, mZe32ToI64, mZeIToI64,
     mToU8, mToU16, mToU32, mToFloat, mToBiggestFloat, mToInt, 
     mToBiggestInt, mCharToStr, mBoolToStr, mIntToStr, mInt64ToStr, 
     mFloatToStr, mCStrToStr, mStrToStr, mEnumToStr:
    genConv(c, n, n.sons[1], dest)
  of mEqStr: genBinaryABC(c, n, dest, opcEqStr)
  of mLeStr: genBinaryABC(c, n, dest, opcLeStr)
  of mLtStr: genBinaryABC(c, n, dest, opcLtStr)
  of mEqSet: genBinarySet(c, n, dest, opcEqSet)
  of mLeSet: genBinarySet(c, n, dest, opcLeSet)
  of mLtSet: genBinarySet(c, n, dest, opcLtSet)
  of mMulSet: genBinarySet(c, n, dest, opcMulSet)
  of mPlusSet: genBinarySet(c, n, dest, opcPlusSet)
  of mMinusSet: genBinarySet(c, n, dest, opcMinusSet)
  of mSymDiffSet: genBinarySet(c, n, dest, opcSymdiffSet)
  of mConStrStr: genVarargsABC(c, n, dest, opcConcatStr)
  of mInSet: genBinarySet(c, n, dest, opcContainsSet)
  of mRepr: genUnaryABC(c, n, dest, opcRepr)
  of mExit:
    unused(n, dest)
    var tmp = c.genx(n.sons[1])
    c.gABC(n, opcQuit, tmp)
    c.freeTemp(tmp)
  of mSetLengthStr, mSetLengthSeq:
    unused(n, dest)
    var d = c.genx(n.sons[1])
    var tmp = c.genx(n.sons[2])
    c.gABC(n, if m == mSetLengthStr: opcSetLenStr else: opcSetLenSeq, d, tmp)
    c.genAsgnPatch(n.sons[1], d)
    c.freeTemp(tmp)
  of mSwap: 
    unused(n, dest)
    var d = c.genx(n.sons[1])
    var tmp = c.genx(n.sons[2])
    c.gABC(n, opcSwap, d, tmp)
    c.freeTemp(tmp)
  of mIsNil: genUnaryABC(c, n, dest, opcIsNil)
  of mCopyStr:
    if dest < 0: dest = c.getTemp(n.typ)
    var
      tmp1 = c.genx(n.sons[1])
      tmp2 = c.genx(n.sons[2])
      tmp3 = c.getTemp(n.sons[2].typ)
    c.gABC(n, opcLenStr, tmp3, tmp1)
    c.gABC(n, opcSubStr, dest, tmp1, tmp2)
    c.gABC(n, opcSubStr, tmp3)
    c.freeTemp(tmp1)
    c.freeTemp(tmp2)
    c.freeTemp(tmp3)
  of mCopyStrLast:
    if dest < 0: dest = c.getTemp(n.typ)
    var
      tmp1 = c.genx(n.sons[1])
      tmp2 = c.genx(n.sons[2])
      tmp3 = c.genx(n.sons[3])
    c.gABC(n, opcSubStr, dest, tmp1, tmp2)
    c.gABC(n, opcSubStr, tmp3)
    c.freeTemp(tmp1)
    c.freeTemp(tmp2)
    c.freeTemp(tmp3)
  of mReset:
    unused(n, dest)
    var d = c.genx(n.sons[1])
    c.gABC(n, opcReset, d)
  of mOf, mIs:
    if dest < 0: dest = c.getTemp(n.typ)
    var tmp = c.genx(n.sons[1])
    var idx = c.getTemp(getSysType(tyInt))
    var typ = n.sons[2].typ
    if m == mOf: typ = typ.skipTypes(abstractPtrs-{tyTypeDesc})
    c.gABx(n, opcLdImmInt, idx, c.genType(typ))
    c.gABC(n, if m == mOf: opcOf else: opcIs, dest, tmp, idx)
    c.freeTemp(tmp)
    c.freeTemp(idx)
  of mSizeOf:
    globalError(n.info, errCannotInterpretNodeX, renderTree(n))
  of mHigh:
    if dest < 0: dest = c.getTemp(n.typ)
    let tmp = c.genx(n.sons[1])
    if n.sons[1].typ.skipTypes(abstractVar-{tyTypeDesc}).kind == tyString:
      c.gABI(n, opcLenStr, dest, tmp, 1)
    else:
      c.gABI(n, opcLenSeq, dest, tmp, 1)
    c.freeTemp(tmp)
  of mEcho:
    unused(n, dest)
    let x = c.getTempRange(n.len-1, slotTempUnknown)
    for i in 1.. <n.len:
      var r: TRegister = x+i-1
      c.gen(n.sons[i], r)
    c.gABC(n, opcEcho, x, n.len-1)
    c.freeTempRange(x, n.len-1)
  of mAppendStrCh:
    unused(n, dest)
    genBinaryStmtVar(c, n, opcAddStrCh)
  of mAppendStrStr: 
    unused(n, dest)
    genBinaryStmtVar(c, n, opcAddStrStr)
  of mAppendSeqElem:
    unused(n, dest)
    genBinaryStmtVar(c, n, opcAddSeqElem)
  of mParseExprToAst:
    genUnaryABC(c, n, dest, opcParseExprToAst)
  of mParseStmtToAst:
    genUnaryABC(c, n, dest, opcParseStmtToAst)
  of mTypeTrait: 
    let tmp = c.genx(n.sons[1])
    if dest < 0: dest = c.getTemp(n.typ)
    c.gABx(n, opcSetType, tmp, c.genType(n.sons[1].typ))
    c.gABC(n, opcTypeTrait, dest, tmp)
    c.freeTemp(tmp)
  of mSlurp: genUnaryABC(c, n, dest, opcSlurp)
  of mStaticExec: genBinaryABC(c, n, dest, opcGorge)
  of mNLen: genUnaryABI(c, n, dest, opcLenSeq)
  of mNChild: genBinaryABC(c, n, dest, opcNChild)
  of mNSetChild, mNDel:
    unused(n, dest)
    var
      tmp1 = c.genx(n.sons[1])
      tmp2 = c.genx(n.sons[2])
      tmp3 = c.genx(n.sons[3])
    c.gABC(n, if m == mNSetChild: opcNSetChild else: opcNDel, tmp1, tmp2, tmp3)
    c.freeTemp(tmp1)
    c.freeTemp(tmp2)
    c.freeTemp(tmp3)
  of mNAdd: genBinaryABC(c, n, dest, opcNAdd)
  of mNAddMultiple: genBinaryABC(c, n, dest, opcNAddMultiple)
  of mNKind: genUnaryABC(c, n, dest, opcNKind)
  of mNIntVal: genUnaryABC(c, n, dest, opcNIntVal)
  of mNFloatVal: genUnaryABC(c, n, dest, opcNFloatVal)
  of mNSymbol: genUnaryABC(c, n, dest, opcNSymbol)
  of mNIdent: genUnaryABC(c, n, dest, opcNIdent)
  of mNGetType: genUnaryABC(c, n, dest, opcNGetType)
  of mNStrVal: genUnaryABC(c, n, dest, opcNStrVal)
  of mNSetIntVal:
    unused(n, dest)
    genBinaryStmt(c, n, opcNSetIntVal)
  of mNSetFloatVal: 
    unused(n, dest)
    genBinaryStmt(c, n, opcNSetFloatVal)
  of mNSetSymbol:
    unused(n, dest)
    genBinaryStmt(c, n, opcNSetSymbol)
  of mNSetIdent: 
    unused(n, dest)
    genBinaryStmt(c, n, opcNSetIdent)
  of mNSetType:
    unused(n, dest)
    genBinaryStmt(c, n, opcNSetType)
  of mNSetStrVal: 
    unused(n, dest)
    genBinaryStmt(c, n, opcNSetStrVal)
  of mNNewNimNode: genBinaryABC(c, n, dest, opcNNewNimNode)
  of mNCopyNimNode: genUnaryABC(c, n, dest, opcNCopyNimNode)
  of mNCopyNimTree: genUnaryABC(c, n, dest, opcNCopyNimTree)
  of mNBindSym:
    if n[1].kind in {nkClosedSymChoice, nkOpenSymChoice, nkSym}:
      let idx = c.genLiteral(n[1])
      if dest < 0: dest = c.getTemp(n.typ)
      c.gABx(n, opcNBindSym, dest, idx)
    else:
      internalError(n.info, "invalid bindSym usage")
  of mStrToIdent: genUnaryABC(c, n, dest, opcStrToIdent)
  of mIdentToStr: genUnaryABC(c, n, dest, opcIdentToStr)
  of mEqIdent: genBinaryABC(c, n, dest, opcEqIdent)
  of mEqNimrodNode: genBinaryABC(c, n, dest, opcEqNimrodNode)
  of mNLineInfo: genUnaryABC(c, n, dest, opcNLineInfo)
  of mNHint: 
    unused(n, dest)
    genUnaryStmt(c, n, opcNHint)
  of mNWarning: 
    unused(n, dest)
    genUnaryStmt(c, n, opcNWarning)
  of mNError:
    unused(n, dest)
    genUnaryStmt(c, n, opcNError)
  of mNCallSite:
    if dest < 0: dest = c.getTemp(n.typ)
    c.gABC(n, opcCallSite, dest)
  of mNGenSym: genBinaryABC(c, n, dest, opcGenSym)
  of mMinI, mMaxI, mMinI64, mMaxI64, mAbsF64, mMinF64, mMaxF64, mAbsI, mAbsI64:
    c.genCall(n, dest)
  of mExpandToAst:
    if n.len != 2:
      globalError(n.info, errGenerated, "expandToAst requires 1 argument")
    let arg = n.sons[1]
    if arg.kind in nkCallKinds:
      #if arg[0].kind != nkSym or arg[0].sym.kind notin {skTemplate, skMacro}:
      #      "ExpandToAst: expanded symbol is no macro or template"
      if dest < 0: dest = c.getTemp(n.typ)
      c.genCall(arg, dest)
      # do not call clearDest(n, dest) here as getAst has a meta-type as such
      # produces a value
    else:
      globalError(n.info, "expandToAst requires a call expression")
  else:
    # mGCref, mGCunref, 
    internalError(n.info, "cannot generate code for: " & $m)

const
  atomicTypes = {tyBool, tyChar,
    tyExpr, tyStmt, tyTypeDesc, tyStatic,
    tyEnum,
    tyOrdinal,
    tyRange,
    tyProc,
    tyPointer, tyOpenArray,
    tyString, tyCString,
    tyInt, tyInt8, tyInt16, tyInt32, tyInt64,
    tyFloat, tyFloat32, tyFloat64, tyFloat128,
    tyUInt, tyUInt8, tyUInt16, tyUInt32, tyUInt64}

proc requiresCopy(n: PNode): bool =
  if n.typ.skipTypes(abstractInst-{tyTypeDesc}).kind in atomicTypes:
    result = false
  elif n.kind in ({nkCurly, nkBracket, nkPar, nkObjConstr}+nkCallKinds):
    result = false
  else:
    result = true

proc unneededIndirection(n: PNode): bool =
  n.typ.skipTypes(abstractInst-{tyTypeDesc}).kind == tyRef

proc genAddrDeref(c: PCtx; n: PNode; dest: var TDest; opc: TOpcode;
                  flags: TGenFlags) = 
  # a nop for certain types
  let flags = if opc == opcAddr: flags+{gfAddrOf} else: flags
  # consider:
  # proc foo(f: var ref int) =
  #   f = new(int)
  # proc blah() =
  #   var x: ref int
  #   foo x
  #
  # The type of 'f' is 'var ref int' and of 'x' is 'ref int'. Hence for
  # nkAddr we must not use 'unneededIndirection', but for deref we use it.
  if opc != opcAddr and unneededIndirection(n.sons[0]):
    gen(c, n.sons[0], dest, flags)
  else:
    let tmp = c.genx(n.sons[0], flags)
    if dest < 0: dest = c.getTemp(n.typ)
    gABC(c, n, opc, dest, tmp)
    c.freeTemp(tmp)

proc whichAsgnOpc(n: PNode): TOpcode =
  case n.typ.skipTypes(abstractRange-{tyTypeDesc}).kind
  of tyBool, tyChar, tyEnum, tyOrdinal, tyInt..tyInt64, tyUInt..tyUInt64:
    opcAsgnInt
  of tyString, tyCString:
    opcAsgnStr
  of tyFloat..tyFloat128:
    opcAsgnFloat
  of tyRef, tyNil, tyVar:
    opcAsgnRef
  else:
    opcAsgnComplex

proc isRef(t: PType): bool = t.skipTypes(abstractRange-{tyTypeDesc}).kind == tyRef

proc whichAsgnOpc(n: PNode; opc: TOpcode): TOpcode =
  if isRef(n.typ): succ(opc) else: opc

proc genAsgn(c: PCtx; dest: TDest; ri: PNode; requiresCopy: bool) =
  let tmp = c.genx(ri)
  assert dest >= 0
  gABC(c, ri, whichAsgnOpc(ri), dest, tmp)
  c.freeTemp(tmp)

template isGlobal(s: PSym): bool = sfGlobal in s.flags and s.kind != skForVar

proc setSlot(c: PCtx; v: PSym) =
  # XXX generate type initialization here?
  if v.position == 0:
    v.position = c.prc.maxSlots
    c.prc.slots[v.position] = (inUse: true,
        kind: if v.kind == skLet: slotFixedLet else: slotFixedVar)
    inc c.prc.maxSlots

proc genAsgn(c: PCtx; le, ri: PNode; requiresCopy: bool) =
  case le.kind
  of nkBracketExpr:
    let dest = c.genx(le.sons[0])
    let idx = c.genx(le.sons[1])
    let tmp = c.genx(ri)
    if le.sons[0].typ.skipTypes(abstractVarRange-{tyTypeDesc}).kind in {
        tyString, tyCString}:
      c.gABC(le, opcWrStrIdx, dest, idx, tmp)
    else:
      c.gABC(le, whichAsgnOpc(le, opcWrArr), dest, idx, tmp)
    c.freeTemp(tmp)
  of nkDotExpr, nkCheckedFieldExpr:
    # XXX field checks here
    let left = if le.kind == nkDotExpr: le else: le.sons[0]
    let dest = c.genx(left.sons[0])
    let idx = c.genx(left.sons[1])
    let tmp = c.genx(ri)
    c.gABC(left, whichAsgnOpc(left, opcWrObj), dest, idx, tmp)
    c.freeTemp(tmp)
  of nkSym:
    let s = le.sym
    if s.isGlobal:
      withTemp(tmp, le.typ):
        gen(c, ri, tmp)
        c.gABx(le, whichAsgnOpc(le, opcWrGlobal), tmp, s.position)
    else:
      if s.kind == skForVar and c.mode == emRepl: c.setSlot s
      internalAssert s.position > 0 or (s.position == 0 and
                                        s.kind in {skParam,skResult})
      var dest: TRegister = s.position + ord(s.kind == skParam)
      gen(c, ri, dest)
  else:
    let dest = c.genx(le)
    genAsgn(c, dest, ri, requiresCopy)

proc genLit(c: PCtx; n: PNode; dest: var TDest) =
  var opc = opcLdConst
  if dest < 0: dest = c.getTemp(n.typ)
  elif c.prc.slots[dest].kind == slotFixedVar: opc = opcAsgnConst
  let lit = genLiteral(c, n)
  c.gABx(n, opc, dest, lit)

proc genTypeLit(c: PCtx; t: PType; dest: var TDest) =
  var n = newNode(nkType)
  n.typ = t
  genLit(c, n, dest)

proc importcSym(c: PCtx; info: TLineInfo; s: PSym) =
  when hasFFI:
    if allowFFI in c.features:
      c.globals.add(importcSymbol(s))
      s.position = c.globals.len
    else:
      localError(info, errGenerated, "VM is not allowed to 'importc'")
  else:
    localError(info, errGenerated,
               "cannot 'importc' variable at compile time")

proc cannotEval(n: PNode) {.noinline.} =
  globalError(n.info, errGenerated, "cannot evaluate at compile time: " &
    n.renderTree)

proc genGlobalInit(c: PCtx; n: PNode; s: PSym) =
  c.globals.add(emptyNode.copyNode)
  s.position = c.globals.len
  # This is rather hard to support, due to the laziness of the VM code
  # generator. See tests/compile/tmacro2 for why this is necesary:
  #   var decls{.compileTime.}: seq[PNimrodNode] = @[]
  c.gABx(n, opcGlobalOnce, 0, s.position)
  let tmp = c.genx(s.ast)
  c.gABx(n, whichAsgnOpc(n, opcWrGlobal), tmp, s.position)
  c.freeTemp(tmp)

proc genRdVar(c: PCtx; n: PNode; dest: var TDest) =
  let s = n.sym
  if s.isGlobal:
    if sfCompileTime in s.flags or c.mode == emRepl:
      discard
    elif s.position == 0:
      cannotEval(n)
    if s.position == 0:
      if sfImportc in s.flags: c.importcSym(n.info, s)
      else: genGlobalInit(c, n, s)
    if dest < 0:
      dest = c.getGlobalSlot(n, s)
      #c.gABx(n, opcAliasGlobal, dest, s.position)
    else:
      c.gABx(n, opcLdGlobal, dest, s.position)
  else:
    if s.kind == skForVar and c.mode == emRepl: c.setSlot s
    if s.position > 0 or (s.position == 0 and
                          s.kind in {skParam,skResult}):
      if dest < 0:
        dest = s.position + ord(s.kind == skParam)
      else:
        # we need to generate an assignment:
        genAsgn(c, dest, n, c.prc.slots[dest].kind >= slotSomeTemp)
    else:
      # see tests/t99bott for an example that triggers it:
      cannotEval(n)

proc genAccess(c: PCtx; n: PNode; dest: var TDest; opc: TOpcode;
               flags: TGenFlags) =
  let a = c.genx(n.sons[0], flags)
  let b = c.genx(n.sons[1], {})
  if dest < 0: dest = c.getTemp(n.typ)
  c.gABC(n, (if gfAddrOf in flags: succ(opc) else: opc), dest, a, b)
  c.freeTemp(a)
  c.freeTemp(b)

proc genObjAccess(c: PCtx; n: PNode; dest: var TDest; flags: TGenFlags) =
  genAccess(c, n, dest, opcLdObj, flags)

proc genCheckedObjAccess(c: PCtx; n: PNode; dest: var TDest; flags: TGenFlags) =
  # XXX implement field checks!
  genAccess(c, n.sons[0], dest, opcLdObj, flags)

proc genArrAccess(c: PCtx; n: PNode; dest: var TDest; flags: TGenFlags) =
  if n.sons[0].typ.skipTypes(abstractVarRange-{tyTypeDesc}).kind in {
      tyString, tyCString}:
    genAccess(c, n, dest, opcLdStrIdx, {})
  else:
    genAccess(c, n, dest, opcLdArr, flags)

proc getNullValue*(typ: PType, info: TLineInfo): PNode
proc getNullValueAux(obj: PNode, result: PNode) = 
  case obj.kind
  of nkRecList:
    for i in countup(0, sonsLen(obj) - 1): getNullValueAux(obj.sons[i], result)
  of nkRecCase:
    getNullValueAux(obj.sons[0], result)
    for i in countup(1, sonsLen(obj) - 1): 
      getNullValueAux(lastSon(obj.sons[i]), result)
  of nkSym:
    addSon(result, getNullValue(obj.sym.typ, result.info))
  else: internalError(result.info, "getNullValueAux")
  
proc getNullValue(typ: PType, info: TLineInfo): PNode = 
  var t = skipTypes(typ, abstractRange-{tyTypeDesc})
  result = emptyNode
  case t.kind
  of tyBool, tyEnum, tyChar, tyInt..tyInt64: 
    result = newNodeIT(nkIntLit, info, t)
  of tyUInt..tyUInt64:
    result = newNodeIT(nkUIntLit, info, t)
  of tyFloat..tyFloat128: 
    result = newNodeIT(nkFloatLit, info, t)
  of tyVar, tyPointer, tyPtr, tyCString, tySequence, tyString, tyExpr,
     tyStmt, tyTypeDesc, tyStatic, tyRef:
    if t.sym != nil and t.sym.magic == mPNimrodNode:
      let nilo = newNodeIT(nkNilLit, info, t)
      result = newNodeIT(nkMetaNode, info, t)
      result.add nilo
    else:
      result = newNodeIT(nkNilLit, info, t)
  of tyProc:
    if t.callConv != ccClosure:
      result = newNodeIT(nkNilLit, info, t)
    else:
      result = newNodeIT(nkPar, info, t)
      result.add(newNodeIT(nkNilLit, info, t))
      result.add(newNodeIT(nkNilLit, info, t))
  of tyObject: 
    result = newNodeIT(nkPar, info, t)
    getNullValueAux(t.n, result)
    # initialize inherited fields:
    var base = t.sons[0]
    while base != nil:
      getNullValueAux(skipTypes(base, skipPtrs).n, result)
      base = base.sons[0]
  of tyArray, tyArrayConstr: 
    result = newNodeIT(nkBracket, info, t)
    for i in countup(0, int(lengthOrd(t)) - 1): 
      addSon(result, getNullValue(elemType(t), info))
  of tyTuple:
    result = newNodeIT(nkPar, info, t)
    for i in countup(0, sonsLen(t) - 1):
      addSon(result, getNullValue(t.sons[i], info))
  of tySet:
    result = newNodeIT(nkCurly, info, t)
  else: internalError("getNullValue: " & $t.kind)

proc genVarSection(c: PCtx; n: PNode) =
  for a in n:
    if a.kind == nkCommentStmt: continue
    #assert(a.sons[0].kind == nkSym) can happen for transformed vars
    if a.kind == nkVarTuple:
      let tmp = c.genx(a.lastSon)
      for i in 0 .. a.len-3:
        setSlot(c, a[i].sym)
        # v = t[i]
        var v: TDest = -1
        genRdVar(c, a[i], v)
        c.gABC(n, opcLdObj, v, tmp, i)
        # XXX globals?
      c.freeTemp(tmp)
    elif a.sons[0].kind == nkSym:
      let s = a.sons[0].sym
      if s.isGlobal:
        if s.position == 0:
          if sfImportc in s.flags: c.importcSym(a.info, s)
          else:
            let sa = if s.ast.isNil: getNullValue(s.typ, a.info) else: s.ast
            c.globals.add(sa)
            s.position = c.globals.len
            # "Once support" is unnecessary here
        if a.sons[2].kind == nkEmpty:
          when false:
            withTemp(tmp, s.typ):
              c.gABx(a, opcLdNull, tmp, c.genType(s.typ))
              c.gABx(a, whichAsgnOpc(a.sons[0], opcWrGlobal), tmp, s.position)
        else:
          let tmp = genx(c, a.sons[2])
          c.gABx(a, whichAsgnOpc(a.sons[0], opcWrGlobal), tmp, s.position)
          c.freeTemp(tmp)
      else:
        setSlot(c, s)
        if a.sons[2].kind == nkEmpty:
          c.gABx(a, opcLdNull, s.position, c.genType(s.typ))
        else:
          gen(c, a.sons[2], s.position.TRegister)
    else:
      # assign to a.sons[0]; happens for closures
      if a.sons[2].kind == nkEmpty:
        let tmp = genx(c, a.sons[0])
        c.gABx(a, opcLdNull, tmp, c.genType(a.sons[0].typ))
        c.freeTemp(tmp)
      else:
        genAsgn(c, a.sons[0], a.sons[2], true)

proc genArrayConstr(c: PCtx, n: PNode, dest: var TDest) =
  if dest < 0: dest = c.getTemp(n.typ)
  c.gABx(n, opcLdNull, dest, c.genType(n.typ))
  if n.len > 0:
    let intType = getSysType(tyInt)
    var tmp = getTemp(c, intType)
    c.gABx(n, opcLdNull, tmp, c.genType(intType))
    for x in n:
      let a = c.genx(x)
      c.gABC(n, whichAsgnOpc(x, opcWrArr), dest, tmp, a)
      c.gABI(n, opcAddImmInt, tmp, tmp, 1)
      c.freeTemp(a)
    c.freeTemp(tmp)

proc genSetConstr(c: PCtx, n: PNode, dest: var TDest) =
  if dest < 0: dest = c.getTemp(n.typ)
  c.gABx(n, opcLdNull, dest, c.genType(n.typ))
  for x in n:
    if x.kind == nkRange:
      let a = c.genx(x.sons[0])
      let b = c.genx(x.sons[1])
      c.gABC(n, opcInclRange, dest, a, b)
      c.freeTemp(b)
      c.freeTemp(a)
    else:
      let a = c.genx(x)
      c.gABC(n, opcIncl, dest, a)
      c.freeTemp(a)

proc genObjConstr(c: PCtx, n: PNode, dest: var TDest) =
  if dest < 0: dest = c.getTemp(n.typ)
  let t = n.typ.skipTypes(abstractRange-{tyTypeDesc})
  if t.kind == tyRef:
    c.gABx(n, opcNew, dest, c.genType(t.sons[0]))
  else:
    c.gABx(n, opcLdNull, dest, c.genType(n.typ))
  for i in 1.. <n.len:
    let it = n.sons[i]
    if it.kind == nkExprColonExpr and it.sons[0].kind == nkSym:
      let idx = c.genx(it.sons[0])
      let tmp = c.genx(it.sons[1])
      c.gABC(it, whichAsgnOpc(it.sons[1], opcWrObj), dest, idx, tmp)
      c.freeTemp(tmp)
      c.freeTemp(idx)
    else:
      internalError(n.info, "invalid object constructor")

proc genTupleConstr(c: PCtx, n: PNode, dest: var TDest) =
  if dest < 0: dest = c.getTemp(n.typ)
  c.gABx(n, opcLdNull, dest, c.genType(n.typ))
  # XXX x = (x.old, 22)  produces wrong code ... stupid self assignments
  for i in 0.. <n.len:
    let it = n.sons[i]
    if it.kind == nkExprColonExpr:
      let idx = c.genx(it.sons[0])
      let tmp = c.genx(it.sons[1])
      c.gABC(it, whichAsgnOpc(it.sons[1], opcWrObj), dest, idx, tmp)
      c.freeTemp(tmp)
      c.freeTemp(idx)
    else:
      let tmp = c.genx(it)
      c.gABC(it, whichAsgnOpc(it, opcWrObj), dest, i.TRegister, tmp)
      c.freeTemp(tmp)

proc genProc*(c: PCtx; s: PSym): int

proc gen(c: PCtx; n: PNode; dest: var TDest; flags: TGenFlags = {}) =
  case n.kind
  of nkSym:
    let s = n.sym
    case s.kind
    of skVar, skForVar, skTemp, skLet, skParam, skResult:
      genRdVar(c, n, dest)
    of skProc, skConverter, skMacro, skTemplate, skMethod, skIterator:
      # 'skTemplate' is only allowed for 'getAst' support:
      if sfImportc in s.flags: c.importcSym(n.info, s)
      genLit(c, n, dest)
    of skConst:
      gen(c, s.ast, dest)
    of skEnumField:
      if dest < 0: dest = c.getTemp(n.typ)
      if s.position >= low(int16) and s.position <= high(int16):
        c.gABx(n, opcLdImmInt, dest, s.position)
      else:
        var lit = genLiteral(c, newIntNode(nkIntLit, s.position))
        c.gABx(n, opcLdConst, dest, lit)
    of skField:
      internalAssert dest < 0
      if s.position > high(dest):
        internalError(n.info, 
          "too large offset! cannot generate code for: " & s.name.s)
      dest = s.position
    of skType:
      genTypeLit(c, s.typ, dest)
    else:
      internalError(n.info, "cannot generate code for: " & s.name.s)
  of nkCallKinds:
    if n.sons[0].kind == nkSym and n.sons[0].sym.magic != mNone:
      genMagic(c, n, dest)
    else:
      genCall(c, n, dest)
      clearDest(c, n, dest)
  of nkCharLit..nkInt64Lit:
    if isInt16Lit(n):
      if dest < 0: dest = c.getTemp(n.typ)
      c.gABx(n, opcLdImmInt, dest, n.intVal.int)
    else:
      genLit(c, n, dest)
  of nkUIntLit..pred(nkNilLit): genLit(c, n, dest)
  of nkNilLit:
    if not n.typ.isEmptyType: genLit(c, n, dest)
    else: unused(n, dest)
  of nkAsgn, nkFastAsgn: 
    unused(n, dest)
    genAsgn(c, n.sons[0], n.sons[1], n.kind == nkAsgn)
  of nkDotExpr: genObjAccess(c, n, dest, flags)
  of nkCheckedFieldExpr: genCheckedObjAccess(c, n, dest, flags)
  of nkBracketExpr: genArrAccess(c, n, dest, flags)
  of nkDerefExpr, nkHiddenDeref: genAddrDeref(c, n, dest, opcDeref, flags)
  of nkAddr, nkHiddenAddr: genAddrDeref(c, n, dest, opcAddr, flags)
  of nkWhenStmt, nkIfStmt, nkIfExpr: genIf(c, n, dest)
  of nkCaseStmt: genCase(c, n, dest)
  of nkWhileStmt:
    unused(n, dest)
    genWhile(c, n)
  of nkBlockExpr, nkBlockStmt: genBlock(c, n, dest)
  of nkReturnStmt:
    unused(n, dest)
    genReturn(c, n)
  of nkRaiseStmt:
    unused(n, dest)
    genRaise(c, n)
  of nkBreakStmt:
    unused(n, dest)
    genBreak(c, n)
  of nkTryStmt: genTry(c, n, dest)
  of nkStmtList:
    unused(n, dest)
    for x in n: gen(c, x)
  of nkStmtListExpr:
    let L = n.len-1
    for i in 0 .. <L: gen(c, n.sons[i])
    gen(c, n.sons[L], dest, flags)
  of nkDiscardStmt:
    unused(n, dest)
    gen(c, n.sons[0])
  of nkHiddenStdConv, nkHiddenSubConv, nkConv:
    genConv(c, n, n.sons[1], dest)
  of nkVarSection, nkLetSection:
    unused(n, dest)
    genVarSection(c, n)
  of declarativeDefs:
    unused(n, dest)
  of nkLambdaKinds:
    let s = n.sons[namePos].sym
    discard genProc(c, s)
    genLit(c, n.sons[namePos], dest)
  of nkChckRangeF, nkChckRange64, nkChckRange: 
    let
      tmp0 = c.genx(n.sons[0])
      tmp1 = c.genx(n.sons[1])
      tmp2 = c.genx(n.sons[2])
    c.gABC(n, opcRangeChck, tmp0, tmp1, tmp2)
    c.freeTemp(tmp1)
    c.freeTemp(tmp2)
    if dest >= 0:
      gABC(c, n, whichAsgnOpc(n), dest, tmp0)
      c.freeTemp(tmp0)
    else:
      dest = tmp0
  of nkEmpty, nkCommentStmt, nkTypeSection, nkConstSection, nkPragma,
     nkTemplateDef, nkIncludeStmt, nkImportStmt, nkFromStmt:
    unused(n, dest)
  of nkStringToCString, nkCStringToString:
    gen(c, n.sons[0], dest)
  of nkBracket: genArrayConstr(c, n, dest)
  of nkCurly: genSetConstr(c, n, dest)
  of nkObjConstr: genObjConstr(c, n, dest)
  of nkPar, nkClosure: genTupleConstr(c, n, dest)
  of nkCast:
    if allowCast in c.features:
      genConv(c, n, n.sons[1], dest, opcCast)
    else:
      localError(n.info, errGenerated, "VM is not allowed to 'cast'")
  else:
    internalError n.info, "too implement " & $n.kind

proc removeLastEof(c: PCtx) =
  let last = c.code.len-1
  if last >= 0 and c.code[last].opcode == opcEof:
    # overwrite last EOF:
    assert c.code.len == c.debug.len
    c.code.setLen(last)
    c.debug.setLen(last)

proc genStmt*(c: PCtx; n: PNode): int =
  c.removeLastEof
  result = c.code.len
  var d: TDest = -1
  c.gen(n, d)
  c.gABC(n, opcEof)
  if d >= 0: internalError(n.info, "some destination set")

proc genExpr*(c: PCtx; n: PNode, requiresValue = true): int =
  c.removeLastEof
  result = c.code.len
  var d: TDest = -1
  c.gen(n, d)
  if d < 0:
    if requiresValue: internalError(n.info, "no destination set")
    d = 0
  c.gABC(n, opcEof, d)

proc genParams(c: PCtx; params: PNode) =
  # res.sym.position is already 0
  c.prc.slots[0] = (inUse: true, kind: slotFixedVar)
  for i in 1.. <params.len:
    let param = params.sons[i].sym
    c.prc.slots[i] = (inUse: true, kind: slotFixedLet)
  c.prc.maxSlots = max(params.len, 1)

proc finalJumpTarget(c: PCtx; pc, diff: int) =
  internalAssert(-0x7fff < diff and diff < 0x7fff)
  let oldInstr = c.code[pc]
  # opcode and regA stay the same:
  c.code[pc] = ((oldInstr.uint32 and 0xffff'u32).uint32 or
                uint32(diff+wordExcess) shl 16'u32).TInstr

proc optimizeJumps(c: PCtx; start: int) =
  const maxIterations = 10
  for i in start .. <c.code.len:
    let opc = c.code[i].opcode
    case opc
    of opcTJmp, opcFJmp:
      var reg = c.code[i].regA
      var d = i + c.code[i].jmpDiff
      for iters in countdown(maxIterations, 0):
        case c.code[d].opcode
        of opcJmp:
          d = d + c.code[d].jmpDiff
        of opcTJmp, opcFJmp:
          if c.code[d].regA != reg: break
          # tjmp x, 23
          # ...
          # tjmp x, 12
          # -- we know 'x' is true, and so can jump to 12+13:
          if c.code[d].opcode == opc:
            d = d + c.code[d].jmpDiff
          else:
            # tjmp x, 23
            # fjmp x, 22
            # We know 'x' is true so skip to the next instruction:
            d = d + 1
        else: break
      if d != i + c.code[i].jmpDiff:
        c.finalJumpTarget(i, d - i)
    of opcJmp:
      var d = i + c.code[i].jmpDiff
      var iters = maxIterations
      while c.code[d].opcode == opcJmp and iters > 0:
        d = d + c.code[d].jmpDiff
        dec iters
      if c.code[d].opcode == opcRet:
        # optimize 'jmp to ret' to 'ret' here
        c.code[i] = c.code[d]
      elif d != i + c.code[i].jmpDiff:
        c.finalJumpTarget(i, d - i)
    else: discard

proc genProc(c: PCtx; s: PSym): int =
  let x = s.ast.sons[optimizedCodePos]
  if x.kind == nkEmpty:
    #if s.name.s == "outterMacro" or s.name.s == "innerProc":
    #  echo "GENERATING CODE FOR ", s.name.s
    let last = c.code.len-1
    var eofInstr: TInstr
    if last >= 0 and c.code[last].opcode == opcEof:
      eofInstr = c.code[last]
      c.code.setLen(last)
      c.debug.setLen(last)
    #c.removeLastEof
    result = c.code.len+1 # skip the jump instruction
    s.ast.sons[optimizedCodePos] = newIntNode(nkIntLit, result)
    # thanks to the jmp we can add top level statements easily and also nest
    # procs easily:
    let body = s.getBody
    let procStart = c.xjmp(body, opcJmp, 0)
    var p = PProc(blocks: @[])
    let oldPrc = c.prc
    c.prc = p
    # iterate over the parameters and allocate space for them:
    genParams(c, s.typ.n)
    if tfCapturesEnv in s.typ.flags:
      #let env = s.ast.sons[paramsPos].lastSon.sym
      #assert env.position == 2
      c.prc.slots[c.prc.maxSlots] = (inUse: true, kind: slotFixedLet)
      inc c.prc.maxSlots
    gen(c, body)
    # generate final 'return' statement:
    c.gABC(body, opcRet)
    c.patch(procStart)
    c.gABC(body, opcEof, eofInstr.regA)
    c.optimizeJumps(result)
    s.offset = c.prc.maxSlots
    #if s.name.s == "concatStyleInterpolation":
    #  c.echoCode(result)
    # echo renderTree(body)
    c.prc = oldPrc
  else:
    c.prc.maxSlots = s.offset
    result = x.intVal.int

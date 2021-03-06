# Simple tool to merge C projects into a single C file

import os, sets, pegs

type
  TProcessResult = enum prSkipIncludeDir, prAddIncludeDir

proc process(dir, infile: string, outfile: TFile, 
             processed: var TSet[string]): TProcessResult =
  if processed.containsOrIncl(infile): return prSkipIncludeDir
  let toProcess = dir / infile
  if not existsFile(toProcess):
    echo "Warning: could not process: ", toProcess
    return prAddIncludeDir
  echo "adding: ", toProcess
  for line in lines(toProcess):
    if line =~ peg"""s <- ig '#include' ig '"' {[^"]+} '"' ig
                     comment <- '/*' !'*/'* '*/' / '//' .*
                     ig <- (comment / \s+)* """:
      # follow the include file:
      if process(dir, matches[0], outfile, processed) == prAddIncludeDir:
        writeln(outfile, line)
    else:
      writeln(outfile, line)

proc main(dir, outfile: string) =
  var o: TFile
  if open(o, outfile, fmWrite):
    var processed = initSet[string]()
    processed.incl(outfile)
    for infile in walkfiles(dir / "*.c"):
      discard process(dir, extractFilename(infile), o, processed)
    close(o)
  else:
    quit("Cannot open for writing: " & outfile)

if paramCount() != 2:
  quit "Usage: cmerge directory outfile"
else:
  main(paramStr(1), addFileExt(paramStr(2), "c"))

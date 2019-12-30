# Package

version       = "0.5.2"
author        = "jiro4989"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["faker/cli/faker"]
binDir        = "bin"

from os import `/`, splitFile
import strformat, strutils, sequtils

# Dependencies

requires "nim >= 1.0.4"

let
  providerDir = "src" / "faker" / "provider"
  locales = ["en_US", "ja_JP"]

task docs, "Generate API documents":
  exec "nimble doc --index:on --project --out:docs --hints:off src/faker.nim"

task genMod, "Generate module":
  let module = paramStr(paramCount())
  if module == "genMod":
    echo "Need 1 args"
    quit 1

  # Copy module dir
  let
    srcModule = "job"
    srcDir = providerDir / srcModule
    dstDir = providerDir / module
  rmDir dstDir
  cpDir srcDir, dstDir
  echo "Generated: " & module

  # Copy module index file
  let
    srcFile = srcDir & ".nim"
    dstFile = dstDir & ".nim"
  rmFile dstFile
  cpFile srcFile, dstFile
  echo "Generated: " & dstFile

  # Rename module name
  for path in listFiles(dstDir):
    let (dir, name, ext) = splitFile(path)
    if name == "interfaces":
      continue
    let newName = name.replace(srcModule, module)
    let newPath = dir / newName & ext
    mvFile path, newPath
    echo "Generated: " & newPath

task genProvs, "Generate provider file":
  for dir in listDirs(providerDir):
    let dstFile = dir & ".nim"
    var lines: seq[string]
    lines.add("# ----------------------------------------------- #")
    lines.add("# This module was generated by 'nimble genProvs'. #")
    lines.add("# See 'faker.nimble'.                             #")
    lines.add("# ----------------------------------------------- #")
    lines.add("")
    lines.add("import util")
    lines.add("import ../base")

    # Get submodule names
    let (_, prefix, _) = splitFile(dir)
    var modules: seq[string]
    for file in listFiles(dir):
      let (_, moduleName, _) = splitFile(file)
      if moduleName == "interfaces":
        continue
      modules.add(moduleName)
    lines.add(&"""import {prefix}/[{modules.join(", ")}]""")

    lines.add("export base")
    lines.add("")

    # Set proc name list and locales

    # 1. proc
    lines.add(&"genProc {prefix},")
    lines.add("  [")
    let procs = readFile(dir / "interfaces.nim")
      .split("\n")
      .filterIt(it.startsWith("proc") and "*(f: Faker)" in it)
    for p in procs:
      let procStr = p.split("*")[0].split("proc ")[1].strip()
      lines.add(&"    {procStr},")
    lines.add("  ], [")

    # 2. locale
    for locale in locales:
      lines.add(&"    {locale},")
    lines.add("  ]")

    let body = lines.join("\n")
    writeFile(dir & ".nim", body)


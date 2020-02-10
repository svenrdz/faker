# Package

version       = "0.9.0"
author        = "jiro4989"
description   = "faker is a Nim package that generates fake data for you."
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["faker/cli/faker"]
binDir        = "bin"

from os import `/`, splitFile
from algorithm import sort
import strformat, strutils, sequtils

# Dependencies

requires "nim >= 1.0.0"

let
  providerDir = "src" / "faker" / "provider"

proc addGeneratedText(lines: var seq[string]) =
  lines.add("# ----------------------------------------------- #")
  lines.add("# This module was generated by 'nimble genProvs'. #")
  lines.add("# See 'faker.nimble'.                             #")
  lines.add("# ----------------------------------------------- #")
  lines.add("")

proc readPublicProcs(file: string): seq[string] =
  readFile(file)
    .split("\n")
    .filterIt(it.startsWith("proc") and "*(f: Faker)" in it)

proc readImplementedLocales(dir, provider: string): seq[string] =
  for path in listFiles(dir):
    let (_, name, _) = splitFile(path)
    if name == "interfaces":
      continue
    result.add(name.replace(&"{provider}_", ""))

proc genProviderIndexFile(provider: string) =
  ## Generate provider/ `provider` .nim file.
  let interfaceFile = providerDir/provider/"interfaces.nim"
  let procs = readPublicProcs(interfaceFile)
  let locales = readImplementedLocales(providerDir/provider, provider)
  var lines: seq[string]
  lines.addGeneratedText()
  lines.add("import util")
  lines.add("import ../base")
  let modules = locales.mapIt(&"{provider}_{it}").join(", ")
  lines.add(&"import {provider}/[{modules}]")
  lines.add("export base")
  lines.add("")
  for p in procs:
    let procName = p.split("*")[0].split("proc ")[1].strip()
    let args = p.split("*")[1].split(":")[0..^2].join(":")
    let returnType = p.split(":")[^1].strip()
    lines.add(&"proc {procName}*{args}: {returnType} =")
    lines.add(&"  ## Generates random {procName}.")
    lines.add(&"  runnableExamples:")
    lines.add(&"    let f = newFaker()")
    let arg2 =
      if 1 < args.split(",").len:
        args.replace("f: Faker, ", "")
      else:
        ""
    lines.add(&"    echo f.{procName}({arg2})")
    lines.add("")
    lines.add(&"  case f.locale")
    let arg3 =
      if arg2 == "": "f"
      else: &"f, {arg2}"
    for locale in locales:
      lines.add(&"""  of "{locale}": {provider}_{locale}.{procName}({arg3})""")
    lines.add(&"  else: {provider}_en_US.{procName}({arg3})")
    lines.add("")
  let indexFile = providerDir/provider & ".nim"
  writeFile(indexFile, lines.join("\n"))

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
  # generate provider / `provider` .nim file
  var providers: seq[string]
  for dir in listDirs(providerDir):
    let (_, provider, _) = splitFile(dir)
    genProviderIndexFile(provider)
    providers.add(provider)

  providers.sort()

  # generate provider.nim
  var lines: seq[string]
  let prov = providers.join(", ")
  lines.addGeneratedText()
  lines.add(&"import provider/[{prov}]")
  lines.add(&"export {prov}")
  let body = lines.join("\n")
  writeFile(providerDir & ".nim", body)

{.warning[Uninit]:off, warning[ProveInit]:off.} # Should be verbosity:2 not 1
import cligen/[strUt, textUt], std/[re, strutils]
when not declared(stdin): import std/syncio
type
  Shell* = enum zsh, bash, fish

  Sub* = object
    name, desc: string
    shortLongHelps: seq[(string, string, string)]

proc escape*(s: string, cs={'[', ']'}, esc='\\'): string =
  for c in s:
    if c in cs: result.add esc; result.add c
    else: result.add c

proc renderZsh*(main: string, subs: seq[Sub]) =
  const mainTmpl = """#compdef _@main @main
# Initially generated by complgen; Edit/Specialize it as desired.
_@{main}() {
  local line state
  _arguments -C "1: :->cmds" "*::arg:->args"
  case "$state" in
    cmds)
      _values "@main command" \
        @cmdsHelps;;
    args) case $line[1] in
        @{cmdsDispatch}esac ;;
  esac
}"""
  const subTmpl = """_@{sub}_cmd() {
  _arguments \
  @subFlags}"""
  let ind = repeat(' ', 8)
  for (id, arg, call) in mainTmpl.tmplParse(meta='@'):
    if id.idIsLiteral: stdout.write mainTmpl[arg]
    else:
      case mainTmpl[id]
      of "main": stdout.write main
      of "cmdsHelps":
        for i, sub in subs:
          if i > 0: stdout.write ind
          stdout.write '\'', sub.name, '[' , sub.desc.escape, """]' \""", '\n'
        stdout.write ind
      of "cmdsDispatch":
        for i, sub in subs:
          if i > 0: stdout.write ind
          stdout.write sub.name, ") _", sub.name, "_cmd ;;\n"
        stdout.write ind
      else: stdout.write mainTmpl[call]
  for sub in subs:
    stdout.write "\n\n"
    for (id, arg, call) in tmplParse(subTmpl, meta='@'):
      if id.idIsLiteral: stdout.write subTmpl[arg]
      else:
        case subTmpl[id]
        of "sub": stdout.write sub.name
        of "subFlags":
          for i, (short, long, help) in sub.shortLongHelps:
            if i > 0: stdout.write "  "
            stdout.write """'($long $short)'{$short,$long}'[$help]' \""" % [
              "short", short, "long", long, "help", help ], '\n'
        else: stdout.write subTmpl[call]
  stdout.write '\n'

proc renderBash*(main: string, subs: seq[Sub]) = discard # TODO
proc renderFish*(main: string, subs: seq[Sub]) = discard # TODO

proc parseSubs*(f: File; main, name, desc, opts: Regex): (string, seq[Sub]) =
  var caps: array[4, tuple[first, last: int]]   # regex captures
  var i, j: int
  for ln in f.lines:
    inc i
    let ln = ln.stripSGR
    if   ln.findBounds(main, caps) != (-1, 0):
      result[0] = ln[caps[0][0]..caps[0][1]]
    elif ln.findBounds(name, caps) != (-1, 0):
      result[1].add Sub(name: ln[caps[0][0]..caps[0][1]])
      j = i
    elif ln.findBounds(desc, caps) != (-1, 0):
      if i == j+1: result[1][^1].desc = ln[caps[0][0]..caps[0][1]]
    elif ln.findBounds(opts, caps) != (-1, 0):
      result[1][^1].shortLongHelps.add (ln[caps[0][0]..caps[0][1]],
                                        ln[caps[1][0]..caps[1][1]],
                                        ln[caps[2][0]..caps[2][1]])

proc cg*(shell=zsh, input="", main="^ *([^ ]*) .SUBCMD.",
         name="^  ([^ ][^ ]*) .*[^:]$", desc="^    ([^ ].*)$",
         opts="  *(-.)=*, (-[^ ]*)=*  *(.*)$") =
  ## *multiCmd help | complgen > autoloaded/_multiCmd* will parse the default
  ## output help for a `dispatchMulti` command, generating shell autocompletion
  ## code (that is intended as a starting not ending point, but may work as is).
  let f = if input.len > 0: open(input) else: stdin
  let (main, subs) = parseSubs(f, main.re, name.re, desc.re, opts.re)
  case shell
  of zsh : renderZsh(main, subs)
  of bash: renderBash(main, subs)
  of fish: renderFish(main, subs)

when isMainModule:
  import cligen; include cligen/mergeCfgEnv
  dispatch cg, cmdName="complgen", help={
    "help" : "CLIGEN-NOHELP", "help-syntax": "CLIGEN-NOHELP",
    "shell": "complete for: zsh,bash,fish",
    "input": "main help dump path; \"\"=stdin",
    "main" : "RE for main command name",
    "name" : "RE for subcmd name",
    "desc" : "RE for subcmd descriptn",
    "opts" : "RE for (short,long,rest)"}

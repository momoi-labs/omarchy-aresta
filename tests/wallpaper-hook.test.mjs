import { test } from "node:test"
import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import { chmodSync, cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const hook = fileURLToPath(new URL("../hooks/aresta-wallpaper", import.meta.url))

function switchTheme({ keep, from = "day", to = "night", current, pictures }) {
  const home = mkdtempSync(join(tmpdir(), "aresta-hook-"))
  const state = join(home, ".local/state/omarchy")
  const staged = join(state, "current/theme/backgrounds")
  const paths = {
    own: theme => join(home, ".config/omarchy/themes", theme, "backgrounds"),
    yours: theme => join(home, ".config/omarchy/backgrounds", theme),
    staged,
    other: join(home, "Pictures"),
  }
  for (const theme of ["day", "night", "third"]) mkdirSync(paths.own(theme), { recursive: true })
  for (const [folder, theme, names] of pictures) {
    const directory = theme ? paths[folder](theme) : paths[folder]
    mkdirSync(directory, { recursive: true })
    for (const name of names) writeFileSync(join(directory, name), `${folder} ${theme} ${name}`)
  }
  mkdirSync(join(home, ".config/aresta"), { recursive: true })
  writeFileSync(
    join(home, ".config/aresta/settings.toml"),
    `light_theme = "day"\ndark_theme = "night"\nwallpaper_keep = ${keep}\n`,
  )
  mkdirSync(join(state, "theme-backgrounds"), { recursive: true })
  writeFileSync(join(state, "aresta-last-theme"), `${from}\n`)
  writeFileSync(join(state, "theme-backgrounds", from), `${current(paths)}\n`)
  cpSync(dirname(paths.own(to)), join(state, "current/theme"), { recursive: true })
  writeFileSync(join(state, "current/theme.name"), `${to}\n`)
  writeFileSync(join(home, "start.png"), "start")
  symlinkSync(join(home, "start.png"), join(state, "current/background"))
  const bin = join(home, "bin")
  mkdirSync(bin)
  writeFileSync(join(bin, "omarchy-theme-bg-set"), '#!/bin/bash\nprintf "%s" "$1" >"$HOME/set"\n')
  chmodSync(join(bin, "omarchy-theme-bg-set"), 0o755)
  const run = spawnSync("bash", [hook, to], {
    env: { HOME: home, PATH: `${bin}:/usr/bin:/bin`, OMARCHY_PATH: join(home, "omarchy") },
  })
  const set = existsSync(join(home, "set")) ? readFileSync(join(home, "set"), "utf8").replace(home, "~") : null
  rmSync(home, { recursive: true })
  assert.equal(run.status, 0)
  return set
}

const stagedPath = name => `~/.local/state/omarchy/current/theme/backgrounds/${name}`
const yoursPath = (theme, name) => `~/.config/omarchy/backgrounds/${theme}/${name}`

test("keep off picks the picture with the same file name", () => {
  const pictures = [
    ["own", "day", ["1-a.webp", "2-b.webp", "3-c.webp"]],
    ["own", "night", ["0-z.webp", "3-c.webp"]],
    ["yours", "day", ["robin.png"]],
    ["yours", "night", ["brook.png", "robin.png"]],
  ]
  assert.equal(switchTheme({ keep: false, pictures, current: p => join(p.staged, "3-c.webp") }), stagedPath("3-c.webp"))
  assert.equal(
    switchTheme({ keep: false, pictures, current: p => join(p.yours("day"), "robin.png") }),
    yoursPath("night", "robin.png"),
  )
  assert.equal(
    switchTheme({ keep: false, from: "night", to: "day", pictures, current: p => join(p.yours("night"), "robin.png") }),
    yoursPath("day", "robin.png"),
  )
})

test("keep off falls back to the same position in the list", () => {
  const pictures = [
    ["own", "day", ["1-a.webp", "2-b.webp"]],
    ["own", "night", ["1-x.webp", "2-y.webp"]],
    ["yours", "day", [".hidden.png", "robin.png"]],
    ["yours", "night", ["brook.png", "franky.png"]],
  ]
  assert.equal(switchTheme({ keep: false, pictures, current: p => join(p.staged, "2-b.webp") }), stagedPath("2-y.webp"))
  assert.equal(switchTheme({ keep: false, pictures, current: p => join(p.own("day"), "2-b.webp") }), stagedPath("2-y.webp"))
  assert.equal(
    switchTheme({ keep: false, pictures, current: p => join(p.yours("day"), "robin.png") }),
    yoursPath("night", "franky.png"),
  )
})

test("keep off leaves Omarchy's choice when no picture matches", () => {
  const pictures = [
    ["own", "day", ["1-a.webp", "2-b.webp"]],
    ["own", "night", ["1-x.webp"]],
    ["own", "third", ["2-b.webp"]],
    ["other", null, ["trip.jpg"]],
  ]
  assert.equal(switchTheme({ keep: false, pictures, current: p => join(p.staged, "2-b.webp") }), null)
  assert.equal(switchTheme({ keep: false, pictures, current: p => join(p.other, "trip.jpg") }), null)
  assert.equal(switchTheme({ keep: false, to: "third", pictures, current: p => join(p.staged, "2-b.webp") }), null)
})

test("keep on sets the picture of the previous theme again", () => {
  const pictures = [
    ["own", "day", ["1-a.webp"]],
    ["own", "night", ["1-a.webp"]],
    ["yours", "day", ["robin.png"]],
    ["yours", "night", ["robin.png"]],
  ]
  assert.equal(
    switchTheme({ keep: true, pictures, current: p => join(p.yours("day"), "robin.png") }),
    yoursPath("day", "robin.png"),
  )
  assert.equal(
    switchTheme({ keep: true, pictures, current: p => join(p.staged, "1-a.webp") }),
    "~/.config/omarchy/themes/day/backgrounds/1-a.webp",
  )
})

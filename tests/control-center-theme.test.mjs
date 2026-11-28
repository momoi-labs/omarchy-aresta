import { test } from "node:test"
import assert from "node:assert/strict"
import { spawn, spawnSync } from "node:child_process"
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { fileURLToPath } from "node:url"

const act = fileURLToPath(new URL("../control-center/act.sh", import.meta.url))

function scratch({ current, mode, themeSet = "", lock = true }) {
  const home = mkdtempSync(join(tmpdir(), "aresta-act-"))
  const state = join(home, ".local/state/omarchy/current")
  const hooks = join(home, ".config/omarchy/hooks/theme-set.d")
  const bin = join(home, "bin")
  const log = join(home, "calls")
  for (const directory of [join(state, "theme"), hooks, bin, join(home, ".config/aresta")]) {
    mkdirSync(directory, { recursive: true })
  }
  if (!lock) mkdirSync(join(home, ".local/state/aresta/theme-lock"), { recursive: true })
  writeFileSync(join(home, ".config/aresta/settings.toml"), 'light_theme = "day"\ndark_theme = "night"\n')
  writeFileSync(join(state, "theme.name"), `${current}\n`)
  writeFileSync(join(state, "theme/colors.toml"), `mode = "${mode}"\n`)
  writeFileSync(join(hooks, "aresta-wallpaper"), `#!/bin/bash\necho "hook $*" >>"${log}"\n`)
  writeFileSync(join(bin, "omarchy-theme-set"), `#!/bin/bash\necho "theme-set $*" >>"${log}"\n${themeSet}`)
  chmodSync(join(bin, "omarchy-theme-set"), 0o755)
  const env = { ...process.env, HOME: home, PATH: `${bin}:${process.env.PATH}` }
  const calls = () => {
    const lines = existsSync(log) ? readFileSync(log, "utf8").trim().split("\n") : []
    rmSync(home, { recursive: true, force: true })
    return lines
  }
  return { env, calls }
}

function setTheme({ current, mode, argument }) {
  const { env, calls } = scratch({ current, mode })
  const result = spawnSync("bash", [act, "theme", ...(argument ? [argument] : [])], { env, encoding: "utf8" })
  return { status: result.status, calls: calls() }
}

test("the choice that is already on changes nothing", () => {
  for (const [current, mode, argument] of [
    ["night", "dark", "dark"],
    ["day", "light", "light"],
  ]) {
    assert.deepEqual(setTheme({ current, mode, argument }), { status: 0, calls: [] })
  }
})

test("the other choice prepares the wallpaper and sets the theme", () => {
  assert.deepEqual(setTheme({ current: "night", mode: "dark", argument: "light" }).calls, [
    "hook day prepare",
    "theme-set day",
  ])
  assert.deepEqual(setTheme({ current: "day", mode: "light", argument: "dark" }).calls, [
    "hook night prepare",
    "theme-set night",
  ])
})

test("the toggle goes to the other mode", () => {
  assert.deepEqual(setTheme({ current: "night", mode: "dark" }).calls, ["hook day prepare", "theme-set day"])
  assert.deepEqual(setTheme({ current: "day", mode: "light" }).calls, ["hook night prepare", "theme-set night"])
})

test("a second request during a switch does not set the theme again", async () => {
  const { env, calls } = scratch({
    current: "day",
    mode: "light",
    themeSet: 'sleep 0.3\necho "$1" >"$HOME/.local/state/omarchy/current/theme.name"\n',
  })
  const run = () => new Promise(resolve => spawn("bash", [act, "theme", "dark"], { env }).on("close", resolve))
  assert.deepEqual(await Promise.all([run(), run()]), [0, 0])
  assert.deepEqual(calls(), ["hook night prepare", "theme-set night"])
})

test("without the lock the theme stays", () => {
  const { env, calls } = scratch({ current: "day", mode: "light", lock: false })
  assert.equal(spawnSync("bash", [act, "theme", "dark"], { env }).status, 1)
  assert.deepEqual(calls(), [])
})

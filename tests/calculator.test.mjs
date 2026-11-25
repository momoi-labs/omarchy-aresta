import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import vm from "node:vm"

const source = readFileSync(new URL("../menu/Calculator.js", import.meta.url), "utf8")
const calc = {}
vm.runInNewContext(source.replace(/^\.pragma library$/m, ""), calc)

const cases = {
  "1+2": "3",
  "(3.5*4)/2": "7",
  "2^10": "1024",
  "15%": "0.15",
  "sqrt(2)*pi": "4.44288293816",
  "0.1+0.2": "0.3",
  "6×7": "42",
  "9÷3": "3",
  "-3+1": "-2",
  "-2^2": "-4",
  "2^-1": "0.5",
  "1/3": "0.333333333333",
  ".5*2": "1",
  "2^100": "1.26765060023e+30",
  "SQRT(16)": "4",
  "e*1": "2.71828182846",
}

const rejected = ["1+", "firefox", "42", "-42", "+42", "1/0", "0/0", "sqrt(-1)", "pi", "e", "(1+2", "1+2)", "sqrt 4", "2..3+1", "1+x", "", "-", "settings"]

test("evaluates full expressions", () => {
  for (const [query, result] of Object.entries(cases)) assert.equal(calc.evaluate(query), result, query)
})

test("rejects anything that is not a full expression", () => {
  for (const query of rejected) assert.equal(calc.evaluate(query), "", query)
})

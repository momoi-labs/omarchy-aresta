.pragma library

function tokenize(text) {
  var tokens = []
  var i = 0
  while (i < text.length) {
    var c = text[i]
    if (c === " " || c === "\t") { i++; continue }
    var number = /^(\d+\.?\d*|\.\d+)/.exec(text.slice(i))
    if (number) {
      tokens.push({ type: "num", value: parseFloat(number[1]) })
      i += number[1].length
      continue
    }
    var word = /^[a-z]+/i.exec(text.slice(i))
    if (word) {
      var name = word[0].toLowerCase()
      if (name === "pi") tokens.push({ type: "num", value: Math.PI })
      else if (name === "e") tokens.push({ type: "num", value: Math.E })
      else if (name === "sqrt") tokens.push({ type: "fn", value: name })
      else return null
      i += word[0].length
      continue
    }
    if (c === "×") c = "*"
    else if (c === "÷") c = "/"
    if ("+-*/^%()".indexOf(c) < 0) return null
    tokens.push({ type: "op", value: c })
    i++
  }
  return tokens
}

function parse(tokens) {
  var pos = 0

  function peek(value) {
    var t = tokens[pos]
    return t && t.type === "op" && t.value === value
  }

  function expr() {
    var left = term()
    while (peek("+") || peek("-")) {
      var op = tokens[pos++].value
      var right = term()
      left = op === "+" ? left + right : left - right
    }
    return left
  }

  function term() {
    var left = unary()
    while (peek("*") || peek("/")) {
      var op = tokens[pos++].value
      var right = unary()
      left = op === "*" ? left * right : left / right
    }
    return left
  }

  function unary() {
    if (peek("-")) { pos++; return -unary() }
    if (peek("+")) { pos++; return unary() }
    return power()
  }

  function power() {
    var base = postfix()
    if (peek("^")) {
      pos++
      return Math.pow(base, unary())
    }
    return base
  }

  function postfix() {
    var value = primary()
    while (peek("%")) { pos++; value = value / 100 }
    return value
  }

  function primary() {
    var t = tokens[pos++]
    if (!t) throw new Error("end")
    if (t.type === "num") return t.value
    if (t.type === "fn") {
      if (!peek("(")) throw new Error("call")
      pos++
      var arg = expr()
      if (!peek(")")) throw new Error("paren")
      pos++
      return Math.sqrt(arg)
    }
    if (t.value === "(") {
      var inner = expr()
      if (!peek(")")) throw new Error("paren")
      pos++
      return inner
    }
    throw new Error("token")
  }

  var value = expr()
  if (pos !== tokens.length) throw new Error("trailing")
  return value
}

function format(value) {
  var rounded = Number(value.toPrecision(12))
  if (rounded === 0) return "0"
  return String(rounded)
}

function evaluate(query) {
  var text = String(query || "").trim()
  if (!/[-+*\/^%×÷]|sqrt/i.test(text)) return ""
  var tokens = tokenize(text)
  if (!tokens || tokens.length === 0) return ""
  var value
  try {
    value = parse(tokens)
  } catch (error) {
    return ""
  }
  if (typeof value !== "number" || !isFinite(value)) return ""
  return format(value)
}

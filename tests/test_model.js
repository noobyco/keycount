const assert = require('node:assert/strict')
const model = require('../keycount_model.js')

const state = model.emptyState()
const result = model.recordRun(state, 72, '2026-11-03')
assert.equal(result.newBest, true)
assert.equal(result.state.bestSpeed, 72)
assert.equal(result.state.streak, 1)
assert.equal(model.recordRun(result.state, 70, '2026-11-03').state.streak, 1)
assert.equal(model.position('bottom-left-edge').horizontal, 'left')
assert.equal(model.position('typo').vertical, 'top')
assert.equal(model.speedFor(100, 60000), 100)
assert.equal(model.qualifies(1, 1000), false)
assert.equal(model.qualifies(2, 999), false)
assert.equal(model.qualifies(2, 1000), true)
assert.equal(model.positionOptions()[0].value, 'top-center')

const KEY = {
  a: 38, b: 56, c: 54, d: 40, e: 26, h: 43, i: 31, l: 46, n: 57, o: 32, r: 27, t: 28, w: 25,
  space: 65, enter: 36, quote: 48, minus: 20, shift: 50, ctrl: 37, backspace: 22, left: 113
}

function press(typing, name, shifted) {
  let next = typing
  if (shifted) next = model.applyKey(next, KEY.shift, 1)
  next = model.applyKey(next, KEY[name], 1)
  next = model.applyKey(next, KEY[name], 0)
  if (shifted) next = model.applyKey(next, KEY.shift, 0)
  return next
}

function typePhrase(phrase) {
  let typing = model.emptyTyping()
  for (const ch of phrase) {
    if (ch === ' ') typing = press(typing, 'space')
    else if (ch === "'") typing = press(typing, 'quote')
    else if (ch === '-') typing = press(typing, 'minus')
    else if (ch === '\n') typing = press(typing, 'enter')
    else typing = press(typing, ch.toLowerCase(), ch !== ch.toLowerCase())
  }
  return typing.text
}

assert.equal(typePhrase('hi there'), 'hi there')
assert.equal(model.wordCount(typePhrase('hi there')), 2)
assert.equal(model.wordCount(typePhrase("don't")), 1)
assert.equal(model.wordCount(typePhrase('well-known')), 1)
let bang = press(model.emptyTyping(), 'h')
bang = press(bang, 'i')
bang = model.applyKey(bang, 50, 1)
bang = model.applyKey(bang, 10, 1)
bang = model.applyKey(bang, 50, 0)
assert.equal(bang.text, 'hi!')
assert.equal(model.wordCount(bang.text), 1)
assert.equal(model.wordCount(''), 0)

let held = model.emptyTyping()
held = model.applyKey(held, KEY.shift, 1)
held = model.applyKey(held, KEY.shift, 0)
held = model.applyKey(held, KEY.ctrl, 1)
held = model.applyKey(held, KEY.a, 1)
held = model.applyKey(held, KEY.left, 1)
assert.equal(held.text, '')
assert.equal(model.wordCount(held.text), 0)

let erased = press(model.emptyTyping(), 'h')
erased = press(erased, 'i')
erased = model.applyKey(erased, KEY.backspace, 1)
assert.equal(erased.text, 'h')
assert.equal(model.wordCount(erased.text), 1)

const saved = model.readState(JSON.stringify({ bestSpeed: 72, bestDate: '2026-11-03', streak: 2 }))
const savedBefore = JSON.stringify(saved)
assert.equal(model.liveSpeed(model.emptyRun(), 5000), 0)

let run = model.noteText(model.emptyRun(), 'hi', 1000, 1)
run = model.noteText(run, 'hi there', 1500, 1)
assert.equal(run.startedAt, 1000)
assert.equal(model.wordCount(run.text), 2)
assert.equal(model.liveSpeed(run, 1500), model.speedFor(2, 500))
const minute = { text: 'hi there', startedAt: 0, updatedAt: 60000, gen: 1 }
assert.equal(model.liveSpeed(minute, 60000), 2)
assert.equal(model.liveSpeed(minute, 60000 + model.RUN_PAUSE_MS + 1), 0)
assert.equal(JSON.stringify(saved), savedBefore)

const faster = model.recordRun(saved, 90, '2026-11-04')
assert.equal(faster.newBest, true)
assert.equal(faster.state.bestSpeed, 90)
assert.equal(faster.state.bestDate, '2026-11-04')
assert.equal(faster.state.streak, 3)
assert.equal(saved.bestSpeed, 72)
assert.equal(saved.streak, 2)
console.log('keycount model checks passed')

// 金额输入框的简单加减法支持
//
// 用法：给金额输入框加 data-amount-expression 属性，输入 12.5+3 这类算式，
// 失焦（或提交前）自动计算为 15.50 再提交。
//
// 注意：金额输入框用 type="text"（type="number" 读取不到算式内容），
// 非法算式（如 12++3）会在提交时被拦截并提示，不会被静默按前缀数字入库。

const AMOUNT_INPUT_SELECTOR = 'input[data-amount-expression]'

const NUMBER_PATTERN = String.raw`\d+(?:\.\d*)?|\.\d+`
const PLAIN_NUMBER_PATTERN = new RegExp(`^[+-]?(?:${NUMBER_PATTERN})$`)
const EXPRESSION_PATTERN = new RegExp(`^[+-]?(?:${NUMBER_PATTERN})(?:[+-](?:${NUMBER_PATTERN}))+$`)

export const INVALID_AMOUNT_MESSAGE = '金额算式无效，请输入数字或如 12.5+3 的算式'

const installedDocuments = new WeakSet()

// 全角数字、全角符号、千分位逗号、空格都归一化为半角紧凑写法
function normalize(value) {
  return String(value)
    .replace(/[\uFF10-\uFF19]/g, (char) => String.fromCharCode(char.charCodeAt(0) - 0xfee0))
    .replace(/＋/g, '+')
    .replace(/[－−–]/g, '-')
    .replace(/[．。]/g, '.')
    .replace(/[，,]/g, '')
    .replace(/\s+/g, '')
}

function formatAmount(number) {
  return (Math.round(number * 100) / 100).toFixed(2)
}

// 返回 { valid, changed, value }：
// valid=false 表示既不是数字也不是合法算式；changed=true 表示 value 与输入不同，需要写回输入框
export function evaluateAmountExpression(rawValue) {
  const raw = String(rawValue ?? '').trim()
  if (raw === '') return { valid: true, changed: false, value: raw }

  const compact = normalize(raw)
  if (compact === '') return { valid: true, changed: false, value: raw }

  if (PLAIN_NUMBER_PATTERN.test(compact)) {
    if (compact === raw) return { valid: true, changed: false, value: raw }
    return { valid: true, changed: true, value: formatAmount(Number(compact)) }
  }

  if (!EXPRESSION_PATTERN.test(compact)) {
    return { valid: false, changed: false, value: raw }
  }

  const terms = compact.match(/[+-]?(?:\d+(?:\.\d*)?|\.\d+)/g) || []
  const total = terms.reduce((sum, term) => sum + Number(term), 0)
  return { valid: true, changed: true, value: formatAmount(total) }
}

// 计算容器内所有金额输入框，返回第一个非法输入框（没有则返回 null）
export function applyAmountExpressions(root) {
  if (!root || typeof root.querySelectorAll !== 'function') return null

  let invalidInput = null
  root.querySelectorAll(AMOUNT_INPUT_SELECTOR).forEach((input) => {
    const result = evaluateAmountExpression(input.value)
    if (result.valid && result.changed) input.value = result.value
    if (!result.valid && !invalidInput) invalidInput = input
  })
  return invalidInput
}

// 安装全局处理：失焦时把算式换成结果，提交时拦截非法算式
// （用捕获阶段监听，保证在表单自身的 submit 监听之前拿到计算结果）
export function installAmountExpressionSupport({ document: doc = document, onInvalid } = {}) {
  if (installedDocuments.has(doc)) return
  installedDocuments.add(doc)

  doc.addEventListener('focusout', (event) => {
    const input = event.target
    if (!input || typeof input.matches !== 'function' || !input.matches(AMOUNT_INPUT_SELECTOR)) return

    const result = evaluateAmountExpression(input.value)
    if (result.valid && result.changed) input.value = result.value
  }, true)

  doc.addEventListener('submit', (event) => {
    const invalidInput = applyAmountExpressions(event.target)
    if (!invalidInput) return

    event.preventDefault()
    // 编辑弹窗等表单会自己发请求，必须阻止事件继续传递
    event.stopPropagation()

    if (typeof invalidInput.focus === 'function') invalidInput.focus()
    if (typeof invalidInput.select === 'function') invalidInput.select()
    if (typeof onInvalid === 'function') onInvalid(invalidInput)
  }, true)
}

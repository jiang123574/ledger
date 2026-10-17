import { describe, it, expect, vi, beforeAll, beforeEach, afterEach } from 'vitest'
import {
  evaluateAmountExpression,
  applyAmountExpressions,
  installAmountExpressionSupport,
  INVALID_AMOUNT_MESSAGE
} from '../../app/javascript/amount_expression.js'

describe('evaluateAmountExpression', () => {
  it('保留普通数字原样', () => {
    expect(evaluateAmountExpression('12.50')).toEqual({ valid: true, changed: false, value: '12.50' })
    expect(evaluateAmountExpression('')).toEqual({ valid: true, changed: false, value: '' })
    expect(evaluateAmountExpression('-50')).toEqual({ valid: true, changed: false, value: '-50' })
  })

  it('计算加法', () => {
    expect(evaluateAmountExpression('12.5+3')).toEqual({ valid: true, changed: true, value: '15.50' })
    expect(evaluateAmountExpression('12 + 3')).toEqual({ valid: true, changed: true, value: '15.00' })
  })

  it('计算连加减', () => {
    expect(evaluateAmountExpression('100-20.5+0.5')).toEqual({ valid: true, changed: true, value: '80.00' })
    expect(evaluateAmountExpression('-50+20')).toEqual({ valid: true, changed: true, value: '-30.00' })
  })

  it('避免浮点误差', () => {
    expect(evaluateAmountExpression('0.1+0.2').value).toBe('0.30')
  })

  it('支持全角符号与千分位', () => {
    expect(evaluateAmountExpression('１２＋３')).toEqual({ valid: true, changed: true, value: '15.00' })
    expect(evaluateAmountExpression('1,000')).toEqual({ valid: true, changed: true, value: '1000.00' })
    expect(evaluateAmountExpression('1,000+500.5')).toEqual({ valid: true, changed: true, value: '1500.50' })
  })

  it('拒绝非法算式', () => {
    for (const raw of ['12++3', '12+', '+', 'abc', '1.2.3', '12*3', '12/3']) {
      expect(evaluateAmountExpression(raw), raw).toEqual({ valid: false, changed: false, value: raw })
    }
  })
})

describe('applyAmountExpressions', () => {
  beforeEach(() => {
    document.body.innerHTML = `
      <form id="form">
        <input type="text" name="amount" data-amount-expression value="12.5+3">
        <input type="text" name="note" value="1+1">
      </form>
    `
  })

  it('只计算带标记的输入框', () => {
    const form = document.getElementById('form')
    expect(applyAmountExpressions(form)).toBeNull()
    expect(form.querySelector('[name="amount"]').value).toBe('15.50')
    expect(form.querySelector('[name="note"]').value).toBe('1+1')
  })

  it('返回第一个非法输入框', () => {
    const form = document.getElementById('form')
    form.querySelector('[name="amount"]').value = '12++3'
    expect(applyAmountExpressions(form)).toBe(form.querySelector('[name="amount"]'))
    expect(form.querySelector('[name="amount"]').value).toBe('12++3')
  })
})

describe('installAmountExpressionSupport', () => {
  const onInvalid = vi.fn()

  // 全局处理器只安装一次（与 application.js 中的调用一致）
  beforeAll(() => {
    installAmountExpressionSupport({ document, onInvalid })
  })

  beforeEach(() => {
    onInvalid.mockClear()
    document.body.innerHTML = `
      <form id="form">
        <input type="text" name="amount" data-amount-expression value="12.5+3">
      </form>
    `
  })

  afterEach(() => {
    document.body.innerHTML = ''
  })

  it('失焦时把算式换成结果', () => {
    const input = document.querySelector('[name="amount"]')
    input.dispatchEvent(new FocusEvent('focusout', { bubbles: true }))
    expect(input.value).toBe('15.50')
  })

  it('提交前算好结果，表单自身的 submit 监听读到的是结果', () => {
    const form = document.getElementById('form')
    const seen = []
    form.addEventListener('submit', (event) => {
      event.preventDefault()
      seen.push(form.querySelector('[name="amount"]').value)
    })

    form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }))

    expect(seen).toEqual(['15.50'])
    expect(onInvalid).not.toHaveBeenCalled()
  })

  it('非法算式阻止提交并提示', () => {
    const form = document.getElementById('form')
    form.querySelector('[name="amount"]').value = '12++3'
    const formSubmitHandler = vi.fn()
    form.addEventListener('submit', formSubmitHandler)

    const event = new Event('submit', { bubbles: true, cancelable: true })
    form.dispatchEvent(event)

    expect(event.defaultPrevented).toBe(true)
    expect(formSubmitHandler).not.toHaveBeenCalled()
    expect(onInvalid).toHaveBeenCalledTimes(1)
    expect(onInvalid.mock.calls[0][0]).toBe(form.querySelector('[name="amount"]'))
    expect(INVALID_AMOUNT_MESSAGE).toBeTruthy()
  })
})

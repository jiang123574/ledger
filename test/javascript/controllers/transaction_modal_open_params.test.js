import { describe, it, expect, vi, beforeEach } from 'vitest'
import TransactionModalController from '../../../app/javascript/controllers/transaction_modal_controller.js'

// 只测 URL 参数分支，不跑 connect()，所以不用铺整个弹窗 DOM
function buildController() {
  const controller = Object.create(TransactionModalController.prototype)
  controller.openNewTransactionModal = vi.fn()
  controller.toggleTransferMode = vi.fn()
  return controller
}

function visit(search) {
  window.history.replaceState({}, '', `/accounts${search}`)
}

describe('TransactionModalController#openFromUrlParams', () => {
  beforeEach(() => {
    document.body.innerHTML = '<div id="add-transaction-modal" class="hidden"></div>'
  })

  it('open_new_transaction=1 时打开新建交易弹窗', () => {
    visit('?open_new_transaction=1')
    const controller = buildController()

    controller.openFromUrlParams()

    expect(controller.openNewTransactionModal).toHaveBeenCalledTimes(1)
    expect(controller.toggleTransferMode).not.toHaveBeenCalled()
  })

  it('open_modal=true 时打开新建交易弹窗（顶栏「+」与仪表盘「新建记账」）', () => {
    visit('?open_modal=true')
    const controller = buildController()

    controller.openFromUrlParams()

    expect(controller.openNewTransactionModal).toHaveBeenCalledTimes(1)
  })

  it('transfer=1 时打开后切到转账模式', () => {
    visit('?open_new_transaction=1&transfer=1')
    const controller = buildController()

    controller.openFromUrlParams()

    expect(controller.openNewTransactionModal).toHaveBeenCalledTimes(1)
    expect(controller.toggleTransferMode).toHaveBeenCalledTimes(1)
  })

  it('没有相关参数时不打开', () => {
    visit('?account_id=3&type=EXPENSE')
    const controller = buildController()

    controller.openFromUrlParams()

    expect(controller.openNewTransactionModal).not.toHaveBeenCalled()
    expect(controller.toggleTransferMode).not.toHaveBeenCalled()
  })

  it('页面上没有新建交易弹窗时不动（预算/报表页只有编辑弹窗）', () => {
    document.body.innerHTML = ''
    visit('?open_new_transaction=1&transfer=1')
    const controller = buildController()

    controller.openFromUrlParams()

    expect(controller.openNewTransactionModal).not.toHaveBeenCalled()
    expect(controller.toggleTransferMode).not.toHaveBeenCalled()
  })
})

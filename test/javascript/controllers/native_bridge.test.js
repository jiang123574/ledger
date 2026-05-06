import { describe, it, expect, vi, afterEach } from 'vitest'
import NativeBridgeController, { NativeApp } from '../../../app/javascript/controllers/native_bridge_controller.js'
import { startController, stopController } from './stimulus_test_helper.js'

describe('NativeBridgeController', () => {
  let application

  afterEach(async () => {
    if (application) await stopController(application)
  })

  it('detects the native bridge from the exported NativeApp helper', () => {
    window.LedgerNative = { isNativeApp: vi.fn().mockReturnValue(true) }

    expect(NativeApp.isNative).toBe(true)
    expect(window.LedgerNative.isNativeApp).toHaveBeenCalled()
  })

  it('calls native share and pickFile when available', () => {
    window.LedgerNative = {
      isNativeApp: vi.fn().mockReturnValue(true),
      share: vi.fn(),
      pickFile: vi.fn()
    }

    expect(NativeApp.share('Title', 'Text')).toBe(true)
    expect(window.LedgerNative.share).toHaveBeenCalledWith('Title', 'Text')

    expect(NativeApp.pickFile('image/*')).toBe(true)
    expect(window.LedgerNative.pickFile).toHaveBeenCalledWith('image/*')
  })

  it('marks the element and reveals native-only share controls on connect', async () => {
    window.LedgerNative = { isNativeApp: vi.fn().mockReturnValue(true) }

    const result = await startController('native-bridge', NativeBridgeController, `
      <div data-controller="native-bridge">
        <button data-native-bridge-target="shareBtn" class="hidden">Share</button>
      </div>
    `)
    application = result.application
    const element = result.element
    const button = element.querySelector('button')

    expect(element.classList.contains('native-app')).toBe(true)
    expect(element.dataset.nativeApp).toBe('true')
    expect(button.classList.contains('hidden')).toBe(false)
    expect(button.classList.contains('inline-flex')).toBe(true)
  })

  it('falls back to the Web Share API when not native', async () => {
    const share = vi.fn().mockResolvedValue(undefined)
    Object.defineProperty(navigator, 'share', { configurable: true, value: share })
    window.history.pushState({}, '', '/share-target')

    ;({ application } = await startController('native-bridge', NativeBridgeController, `
      <div data-controller="native-bridge" data-native-bridge-share-title-value="Report" data-native-bridge-share-text-value="Summary">
        <button data-action="click->native-bridge#share">Share</button>
      </div>
    `))

    document.querySelector('button').click()

    expect(share).toHaveBeenCalledWith({
      title: 'Report',
      text: 'Summary',
      url: window.location.href
    })
  })

  it('falls back to clipboard and toast when Web Share is unavailable', async () => {
    const writeText = vi.fn()
    Object.defineProperty(navigator, 'share', { configurable: true, value: undefined })
    Object.defineProperty(navigator, 'clipboard', { configurable: true, value: { writeText } })
    window.history.pushState({}, '', '/clipboard-target')

    ;({ application } = await startController('native-bridge', NativeBridgeController, `
      <div data-controller="native-bridge">
        <button data-action="click->native-bridge#share">Share</button>
      </div>
    `))

    document.querySelector('button').click()

    expect(writeText).toHaveBeenCalledWith(window.location.href)
    expect(document.body.textContent).toContain('链接已复制')
  })

  it('clicks the fallback file input when native file picker is unavailable', async () => {
    ;({ application } = await startController('native-bridge', NativeBridgeController, `
      <div data-controller="native-bridge">
        <button data-action="click->native-bridge#pickFile">Pick</button>
        <input data-native-bridge-target="fileInput" type="file">
      </div>
    `))

    const input = document.querySelector('input')
    const click = vi.spyOn(input, 'click').mockImplementation(() => {})
    document.querySelector('button').click()

    expect(click).toHaveBeenCalledTimes(1)
  })
})

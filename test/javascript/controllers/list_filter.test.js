import { describe, it, expect, afterEach } from 'vitest'
import ListFilterController from '../../../app/javascript/controllers/list_filter_controller.js'
import { startController, stopController } from './stimulus_test_helper.js'

describe('ListFilterController', () => {
  let application

  afterEach(async () => {
    if (application) await stopController(application)
  })

  async function mountList() {
    ;({ application } = await startController('list-filter', ListFilterController, `
      <div data-controller="list-filter">
        <input data-list-filter-target="input" data-action="input->list-filter#filter">
        <div data-list-filter-target="list">
          <div class="filterable-item" data-filter-name="Apple">Apple</div>
          <div class="filterable-item" data-filter-name="Banana">Banana</div>
          <div class="filterable-item">Cherry Pie</div>
        </div>
      </div>
    `))

    return document.querySelector('[data-controller="list-filter"]')
  }

  it('shows matching items and hides non-matches', async () => {
    const element = await mountList()
    const input = element.querySelector('input')
    const items = element.querySelectorAll('.filterable-item')

    input.value = 'app'
    input.dispatchEvent(new Event('input', { bubbles: true }))

    expect(items[0].classList.contains('hidden')).toBe(false)
    expect(items[1].classList.contains('hidden')).toBe(true)
    expect(items[2].classList.contains('hidden')).toBe(true)
  })

  it('matches case-insensitively and falls back to text content', async () => {
    const element = await mountList()
    const input = element.querySelector('input')
    const items = element.querySelectorAll('.filterable-item')

    input.value = 'CHERRY'
    input.dispatchEvent(new Event('input', { bubbles: true }))

    expect(items[0].classList.contains('hidden')).toBe(true)
    expect(items[1].classList.contains('hidden')).toBe(true)
    expect(items[2].classList.contains('hidden')).toBe(false)
  })

  it('shows every item for an empty query', async () => {
    const element = await mountList()
    const input = element.querySelector('input')
    const items = element.querySelectorAll('.filterable-item')

    input.value = ''
    input.dispatchEvent(new Event('input', { bubbles: true }))

    items.forEach((item) => expect(item.classList.contains('hidden')).toBe(false))
  })
})

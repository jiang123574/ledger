import { Application } from '@hotwired/stimulus'

export async function startController(identifier, ControllerClass, html) {
  document.body.innerHTML = html

  const application = Application.start()
  application.register(identifier, ControllerClass)

  await Promise.resolve()

  return {
    application,
    element: document.querySelector(`[data-controller~="${identifier}"]`)
  }
}

export async function stopController(application) {
  application.stop()
  await Promise.resolve()
}

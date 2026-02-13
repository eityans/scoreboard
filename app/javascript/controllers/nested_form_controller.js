import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["template", "container"]

  add(event) {
    event.preventDefault()
    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, new Date().getTime())
    this.containerTarget.insertAdjacentHTML("beforeend", content)
  }

  remove(event) {
    event.preventDefault()
    const wrapper = event.target.closest("[data-nested-form-wrapper]")
    const destroyInput = wrapper.querySelector("input[name*='_destroy']")

    if (destroyInput) {
      destroyInput.value = "1"
      wrapper.style.display = "none"
    } else {
      wrapper.remove()
    }
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "form"]
  static values = { url: String }

  toggle(event) {
    event.preventDefault()
    this.formTarget.classList.toggle("hidden")
    if (!this.formTarget.classList.contains("hidden")) {
      this.inputTarget.focus()
    }
  }

  async submit(event) {
    event.preventDefault()
    const name = this.inputTarget.value.trim()
    if (!name) return

    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content

    const response = await fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": csrfToken
      },
      body: JSON.stringify({ player: { display_name: name } })
    })

    if (response.ok) {
      const player = await response.json()
      document.querySelectorAll("select[name*='player_id']").forEach(select => {
        const option = new Option(player.display_name, player.id)
        select.add(option)
      })
      this.inputTarget.value = ""
      this.formTarget.classList.add("hidden")
    }
  }
}

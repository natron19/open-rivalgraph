import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Fallback for the battlecard page while research runs. Results normally arrive by Turbo Stream
// broadcast, but a run that ends before this page subscribes (a gatekeeper block fails in
// milliseconds) broadcasts to nobody and leaves the spinner up forever. Polling the same page
// catches that: once the server-rendered status is no longer pending/running, reload it.
export default class extends Controller {
  static values = { url: String, interval: { type: Number, default: 4000 } }

  connect() {
    this.timer = setInterval(() => this.check(), this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  async check() {
    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "text/html" } })
      const html = await response.text()
      const doc = new DOMParser().parseFromString(html, "text/html")
      const status = doc.querySelector("[data-analysis-status]")?.dataset.analysisStatus
      if (status && !["pending", "running"].includes(status)) {
        clearInterval(this.timer)
        Turbo.visit(this.urlValue, { action: "replace" })
      }
    } catch {
      // Network blip: try again on the next tick.
    }
  }
}

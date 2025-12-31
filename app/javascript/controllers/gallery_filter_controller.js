import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="gallery-filter"
export default class extends Controller {
  static targets = ["item", "noResults", "search"]

  filter(event) {
    const searchTerm = event.target.value.toLowerCase().trim()
    let visibleCount = 0

    this.itemTargets.forEach(item => {
      const caption = item.dataset.caption?.toLowerCase() || ""
      const matches = caption.includes(searchTerm)

      if (matches) {
        item.classList.remove("d-none")
        visibleCount++
      } else {
        item.classList.add("d-none")
      }
    })

    // Show/hide "no results" message
    if (this.hasNoResultsTarget) {
      if (visibleCount === 0 && searchTerm.length > 0) {
        this.noResultsTarget.classList.remove("d-none")
      } else {
        this.noResultsTarget.classList.add("d-none")
      }
    }
  }
}

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="scroller"
export default class extends Controller {
  fire() {
    const yPos = window.scrollY
    console.log(yPos);
    scrollTo(0,-yPos)
  }
}

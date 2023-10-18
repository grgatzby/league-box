import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toggle"
export default class extends Controller {
  static targets = ["togglableElement", "button", "button2"]

  fire() {
    this.togglableElementTarget.classList.toggle("d-none");
    this.button2Target.classList.toggle("d-none");
    const btn = this.buttonTarget
    let txt = btn.innerText
    btn.textContent = txt == "View the rules" ? "Hide the rules" : "View the rules"
    window.scrollTo({
      top: window.innerHeight-66-24,
      left: 0,
      behaviour: "smooth",
    });
  }
}

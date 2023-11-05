import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toggle"
export default class extends Controller {
  static targets = ["togglableElement", "toggler", "topButton", "infoLeagueTable"]


  scrollFunction() {
    // When the user scrolls down half way from the top of the Rules window, show the Top button
    let windowHeight = window.innerHeight/2 // one half of the screen height in pixels
    if (this.togglableElementTarget.scrollTop > windowHeight){
      this.topButtonTarget.classList.remove("d-none");
    } else {
      this.topButtonTarget.classList.add("d-none");
    }
  }

  // When the user clicks on the Top button, scroll to the top of the document
  scrollToTop() {
    // this.togglableElementTarget.scrollTop = 0 // instantaneous scrollTop
    this.togglableElementTarget.scrollTo({top: 0, behavior: 'smooth'});
  }

  // when the user clicks on the hide/display the rules button
  fire() {
    this.togglableElementTarget.scrollTop = 0
    this.togglableElementTarget.classList.toggle("d-none");
    const btn = this.togglerTarget
    let txt = btn.innerText
    btn.textContent = txt == "Display the rules" ? "Hide the rules" : "Display the rules"
    window.scrollTo({top: window.innerHeight-66-24, behaviour: "smooth"});
  }

  toggleText() {

  }
}

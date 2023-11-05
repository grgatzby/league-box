import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toggle"
export default class extends Controller {
  static targets = ["togglableElement", "toggler", "topButton"]


  scrollFunction() {
    // when the scrolling in the scroll-box starts, scroll te entire window up
    window.scrollTo(0, document.body.scrollHeight);
    // when the scrolling in the scroll-box is half way down, show the Top button
    if (this.togglableElementTarget.scrollTop > window.innerHeight/2){
      this.topButtonTarget.classList.remove("d-none");
    } else {
      this.topButtonTarget.classList.add("d-none");
    }
  }

  scrollToTop() {
    // when the user clicks on the Top button, scroll to the top of the document
    // this.togglableElementTarget.scrollTop = 0 // instantaneous scrollTop
    this.togglableElementTarget.scrollTo({top: 0, behavior: 'smooth'});
  }

  fire() {
    // when the user clicks on the hide/display the rules button
    this.togglableElementTarget.scrollTop = 0 // instantaneous scrollTop
    this.togglableElementTarget.classList.toggle("d-none");
    const btn = this.togglerTarget
    let txt = btn.innerText
    btn.textContent = txt == "Display the rules" ? "Hide the rules" : "Display the rules"
    window.scrollTo({top: window.innerHeight-66-24, behaviour: "smooth"});
  }
}

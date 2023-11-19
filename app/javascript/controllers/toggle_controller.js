import { Controller } from "@hotwired/stimulus"

const scrollDirection = function() {
  var oldScrollY = window.scrollY;
  window.onscroll = function(e) {
    if (oldScrollY < window.scrollY) {
      return 1;
    } else {
      return -1;
    }
  }
}

// Connects to data-controller="toggle"
export default class extends Controller {
  static targets = ["togglableButton", "togglableElement", "toggler", "topButton"]
  static values = {
    displayRules: String,
    hideRules: String
  }

  connect() {
    var context = this.togglableElementTarget
    var button = this.topButtonTarget
    var oldScrollY = context.scrollTop;
    context.onscroll = function(e) {
      // when scrolling UP in the scroll-box, scroll the entire window up
      if (oldScrollY < context.scrollTop && context.scrollTop > 0) {
        window.scrollTo(0, document.body.scrollHeight);
        console.log("old:", oldScrollY, "context:", context.scrollTop, "half window:", window.innerHeight/2);
        console.log("scrolling top")
      }
      oldScrollY = context.scrollTop;
      // when the scrolling in the scroll-box is half way down, show the Top button
      if (context.scrollTop > window.innerHeight/2){
        button.classList.remove("d-none");
      } else {
        button.classList.add("d-none");
      }
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
    this.togglableButtonTarget.classList.toggle("d-none");
    const btn = this.togglerTarget
    let txt = btn.innerText
    // btn.textContent = txt == "Display the rules" ? "Hide the rules" : "Display the rules"
    btn.textContent = txt == this.displayRulesValue ? this.hideRulesValue : this.displayRulesValue
    window.scrollTo({top: window.innerHeight-66-24, behaviour: "smooth"});
  }
}

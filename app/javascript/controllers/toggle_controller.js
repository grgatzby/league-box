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
    hideRules: String,
    screenType: String
  }

  connect() {
    var currentElement = this.togglableElementTarget;
    var oldScrollY = currentElement.scrollTop;
    var screenType = this.screenTypeValue;
    var topButton = this.topButtonTarget;

    currentElement.onscroll = function(e) {
      if (oldScrollY < currentElement.scrollTop && currentElement.scrollTop > 0 && screenType !== "mobile") {
        // when scrolling UP in the scroll-box, scroll the entire window up if NOT on a mobile screen
        window.scrollTo(0, document.body.scrollHeight);
      }
      oldScrollY = currentElement.scrollTop;
      // console.log('top button', topButton.classList);
      if (currentElement.scrollTop > window.innerHeight/3) {
        // when the scrolling through the scroll-box, show the Top button
        topButton.classList.remove("d-none");
      } else {
        topButton.classList.add("d-none");
      }
    }
  }


  scrollToTop() {
    // when the user clicks on the "Top" button, scroll to the top of the document
    // this.togglableElementTarget.scrollTop = 0 // instantaneous scrollTop
    this.togglableElementTarget.scrollTo({top: 0, behavior: 'smooth'});
  }

  toggleRules() {
    // when the user clicks on the "hide/display the rules" button
    this.togglableElementTarget.scrollTop = 0 // instantaneous scrollTop
    this.togglableElementTarget.classList.toggle("d-none");
    this.togglableButtonTarget.classList.toggle("d-none");
    const btn = this.togglerTarget
    let txt = btn.innerText
    btn.textContent = txt == this.displayRulesValue ? this.hideRulesValue : this.displayRulesValue
    window.scrollTo({top: window.innerHeight-66-24, behaviour: "smooth"});
  }
}

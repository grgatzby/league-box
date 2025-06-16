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
  static targets = ["togglableButton", "togglableElement", "toggler", "topButton", "image"]
  static values = {
    displayRules: String,
    hideRules: String,
    screenType: String
  }

  connect() {
    var currentElement = this.togglableElementTarget,
    wSinit = currentElement.scrollTop, // number of pixels by which content is scrolled from its top edge.
    screenType = this.screenTypeValue,
    topButton = this.topButtonTarget,
    hasImage = this.hasImageTarget
    if (hasImage) {
      // console.log('image target is in the DOM');
      var image = this.imageTarget,
      iH = image.firstElementChild.clientHeight; // 325
    }

    currentElement.onscroll = function(e) {
      var wH = window.innerHeight, // 988
      woH = window.outerHeight, // 920
      wS = currentElement.scrollTop; // 0 - 1083
      if (hasImage) {
        var hT = image.offsetTop // 2011 (distance from the outer border of image to the top padding edge of the offsetParent.
        console.log (wH, woH, wS, wS+iH, hT-wH, wS+iH-(hT-wH), ((wS+iH-(hT-wH))/iH));
        if (wS+iH > (hT-wH)) {
            console.log('image on the view!');
        }
        if (wS+iH/2 > (hT-wH)) {
            console.log('center of image on the view!');
            // fade image in at the end of scroll down
            image.style.opacity = ((wS+iH/2-(hT-wH))/iH);
        } else {
          image.style.opacity = 0;
        }
      }

      if (wSinit < wS && wS > 0 && screenType !== "mobile") {
        // when scrolling UP in the scroll-box, scroll the entire window up if NOT on a mobile screen
        window.scrollTo(0, document.body.scrollHeight);
      }
      wSinit = wS;
      // console.log('top button', topButton.classList);
      if (wS > wH/3) {
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

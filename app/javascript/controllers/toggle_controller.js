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
  static targets = ["togglableButton", "togglableElement", "tournamentRules", "topButton", "image",
    "section1", "section2", "section3", "section4", "section5", "section6", "section7"]
  static values = {
    displayRounds: String,
    hideRounds: String,
    screenType: String
  }

  connect() {
    var currentElement = this.togglableElementTarget,
    wSinit = currentElement.scrollTop, // number of pixels by which content is scrolled from its top edge.
    screenType = this.screenTypeValue,
    topButton = this.topButtonTarget,
    hasImage = this.hasImageTarget
    //console.log(this.tournamentRulesTarget,this.displayRoundsValue, this.hideRoundsValue);
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
        // console.log (wH, woH, wS, wS+iH, hT-wH, wS+iH-(hT-wH), ((wS+iH-(hT-wH))/iH));
        if (wS+iH > (hT-wH)) {
            // console.log('image on the view!');
        }
        if (wS+iH/2 > (hT-wH)) {
            // console.log('center of image on the view!');
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
    // when the user clicks on the "hide/display round dates" button
    this.togglableElementTarget.scrollTop = 0 // instantaneous scrollTop
    this.togglableElementTarget.classList.toggle("d-none");
    this.togglableButtonTarget.classList.toggle("d-none");
    const btn = this.tournamentRulesTarget
    let txt = btn.innerText
    btn.textContent = txt == this.displayRoundsValue ? this.hideRoundsValue : this.displayRoundsValue
    window.scrollTo({top: window.innerHeight-66-24, behaviour: "smooth"});
  }

  toggleSection1() {
    this.collapseSections(1);
    // when the user clicks on the section
    this.section1Target.classList.toggle("d-none");
  }

  toggleSection2() {
    this.collapseSections(2);
    // when the user clicks on the section
    this.section2Target.classList.toggle("d-none");
  }

  toggleSection3() {
    this.collapseSections(3);
    // when the user clicks on the section
    this.section3Target.classList.toggle("d-none");
  }

  toggleSection4() {
    this.collapseSections(4);
    // when the user clicks on the section
    this.section4Target.classList.toggle("d-none");
  }

  toggleSection5() {
    this.collapseSections(5);
    // when the user clicks on the section
    this.section5Target.classList.toggle("d-none");
  }

  toggleSection6() {
    this.collapseSections(6);
    // when the user clicks on the section
    this.section6Target.classList.toggle("d-none");
  }

  toggleSection7() {
    this.collapseSections(7);
    // when the user clicks on the section
    this.section7Target.classList.toggle("d-none");
  }

  collapseSections(number) {
    console.log("section");
//    if (number == 1 || !this.hasSection1Target) {} else {this.section1Target.classList.add("d-none")};
    if (number !== 1 && this.hasSection1Target) {this.section1Target.classList.add("d-none")};
    if (number !== 2 && this.hasSection2Target) {this.section2Target.classList.add("d-none")};
    if (number !== 3 && this.hasSection3Target) {this.section3Target.classList.add("d-none")};
    if (number !== 4 && this.hasSection4Target) {this.section4Target.classList.add("d-none")};
    if (number !== 5 && this.hasSection5Target) {this.section5Target.classList.add("d-none")};
    if (number !== 6 && this.hasSection6Target) {this.section6Target.classList.add("d-none")};
    if (number !== 7 && this.hasSection7Target) {this.section7Target.classList.add("d-none")};
  }

}

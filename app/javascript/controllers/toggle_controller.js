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
    const isCurrentlyHidden = this.togglableElementTarget.classList.contains("d-none");
    this.togglableElementTarget.classList.toggle("d-none");
    this.togglableButtonTarget.classList.toggle("d-none");
    const btn = this.tournamentRulesTarget
    let txt = btn.innerText
    btn.textContent = txt == this.displayRoundsValue ? this.hideRoundsValue : this.displayRoundsValue

    // Scroll to appropriate section based on whether we're showing or hiding
    setTimeout(() => {
      if (isCurrentlyHidden) {
        // Gallery is being shown - scroll to gallery header
        const galleryHeader = document.getElementById("gallery-header");
        if (galleryHeader) {
          galleryHeader.scrollIntoView({ behavior: "smooth", block: "start" });
        }
      } else {
        // Gallery is being hidden - scroll to page header (rules or my-club)
        const myClubHeader = document.getElementById("my-club-header");
        const rulesHeader = document.getElementById("rules-header");
        const headerToScroll = myClubHeader || rulesHeader;
        if (headerToScroll) {
          headerToScroll.scrollIntoView({ behavior: "smooth", block: "start" });
        }
      }
    }, 100); // Small delay to ensure DOM has updated
  }

  toggleSection(event) {
    // toggle the section that is clicked and collapse all other sections
    const sectionNumber = parseInt(event.currentTarget.dataset.section, 10);
    this.collapseSections(sectionNumber);
    // when the user clicks on the section
    const sectionTarget = this[`section${sectionNumber}Target`];
    if (sectionTarget) {
      sectionTarget.classList.toggle("d-none");
    }
  }

  collapseSections(number) {
    // collapse all sections except the one that is clicked
    for (let i = 1; i <= 7; i++) {
      if (number !== i && this[`hasSection${i}Target`]) {
        this[`section${i}Target`].classList.add("d-none");
      }
    }
  }

}

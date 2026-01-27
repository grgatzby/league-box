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
    "section1", "section2", "section3", "section4", "section5", "section6", "section7", "section8", "section9", "section10", "section11", "section12"]
  static values = {
    displayRounds: String,
    hideRounds: String,
    screenType: String
  }

  connect() {
    var currentElement = this.togglableElementTarget,
    scroTopinit = currentElement.scrollTop, // number of pixels by which content is scrolled from its top edge.
    screenType = this.screenTypeValue,
    topButton = this.topButtonTarget,
    hasImage = this.hasImageTarget,
    image = null,
    imH = 0
    //console.log(this.tournamentRulesTarget,this.displayRoundsValue, this.hideRoundsValue);
    if (hasImage) {
      // console.log('image target is in the DOM');
      image = this.imageTarget;
      imH = image.firstElementChild.clientHeight; // 325
    }

    currentElement.onscroll = function(e) {
      var inH = window.innerHeight, // 988
      outH = window.outerHeight, // 920
      scroTop = currentElement.scrollTop; // 0 - 1083
      if (hasImage) {
        var imOffsTop = image.offsetTop // 2011 (distance from the outer border of image to the top padding edge of the offsetParent.
        console.log ("inH, outH, scroTop, scroTop+imH, imOffsTop-inH, scroTop+imH-(imOffsTop-inH), imH,((scroTop+imH-(imOffsTop-inH))/imH", inH, outH, scroTop, scroTop+imH, imOffsTop-inH, scroTop+imH-(imOffsTop-inH), imH,((scroTop+imH-(imOffsTop-inH))/imH));
        if (scroTop+imH > (imOffsTop-inH)) {
            // console.log('image on the view!');
        }
        if (scroTop+imH/2 > (imOffsTop-inH)) {
            // console.log('center of image on the view!');
            // fade image in at the end of scroll down
            image.style.opacity = ((scroTop+imH/2-(imOffsTop-inH))/imH);
        } else {
          image.style.opacity = 0;
        }
      }

      if (scroTopinit < scroTop && scroTop > 0 && screenType !== "mobile") {
        // when scrolling UP in the scroll-box, scroll the entire window up if NOT on a mobile screen
        window.scrollTo(0, document.body.scrollHeight);
      }
      scroTopinit = scroTop;
      // console.log('top button', topButton.classList);
      if (scroTop > inH/3) {
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
      const isCurrentlyHidden = sectionTarget.classList.contains("d-none");
      sectionTarget.classList.toggle("d-none");
      
      // Rotate arrow icon when section opens/closes
      const arrow = event.currentTarget.querySelector('.sitemap-arrow');
      if (arrow) {
        if (isCurrentlyHidden) {
          arrow.style.transform = 'rotate(180deg)';
        } else {
          arrow.style.transform = 'rotate(0deg)';
        }
      }

      // If section is being expanded, check if we need to scroll to bottom
      if (isCurrentlyHidden) {
        // Wait for the animation to start, then check if next section is hidden
        setTimeout(() => {
          this.checkAndScrollToBottom(sectionNumber);
        }, 50);
      }
    }
  }

  checkAndScrollToBottom(expandedSectionNumber) {
    const scrollableContainer = this.togglableElementTarget;
    if (!scrollableContainer) return;

    // Check if this is the last section (12 is the maximum)
    const isLastSection = expandedSectionNumber >= 12;

    // Check if next section header exists and is hidden
    let nextSectionHeaderHidden = false;
    if (!isLastSection) {
      const nextSectionNumber = expandedSectionNumber + 1;
      const nextSectionHeader = document.querySelector(`[data-section="${nextSectionNumber}"]`);
      if (nextSectionHeader) {
        const nextSectionRect = nextSectionHeader.getBoundingClientRect();
        const containerRect = scrollableContainer.getBoundingClientRect();
        // Check if next section header is below the visible area
        nextSectionHeaderHidden = nextSectionRect.top > containerRect.bottom;
      }
    }

    // Scroll to bottom if it's the last section or next section header is hidden
    if (isLastSection || nextSectionHeaderHidden) {
      scrollableContainer.scrollTo({
        top: scrollableContainer.scrollHeight,
        behavior: 'smooth'
      });
    }
  }

  collapseSections(number) {
    // collapse all sections except the one that is clicked
    for (let i = 1; i <= 12; i++) {
      if (number !== i && this[`hasSection${i}Target`]) {
        this[`section${i}Target`].classList.add("d-none");
        // Reset arrow rotation for collapsed sections
        const sectionHeader = document.querySelector(`[data-section="${i}"]`);
        if (sectionHeader) {
          const arrow = sectionHeader.querySelector('.sitemap-arrow');
          if (arrow) {
            arrow.style.transform = 'rotate(0deg)';
          }
        }
      }
    }
  }

}

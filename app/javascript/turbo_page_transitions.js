// Lightweight fade on Turbo Drive navigations (e.g. box grid → match show).
// Skips animation on first full page load; respects prefers-reduced-motion via CSS.

let pendingTurboVisit = false

document.addEventListener("turbo:before-visit", () => {
  pendingTurboVisit = true
  document.body.classList.add("turbo-nav--leave")
})

document.addEventListener("turbo:fetch-request-error", () => {
  pendingTurboVisit = false
  document.body.classList.remove("turbo-nav--leave")
})

document.addEventListener("turbo:load", () => {
  document.body.classList.remove("turbo-nav--leave")

  if (!pendingTurboVisit) {
    return
  }
  pendingTurboVisit = false

  document.body.classList.add("turbo-nav--enter")
  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      document.body.classList.remove("turbo-nav--enter")
    })
  })
})

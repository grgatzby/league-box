import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

// Connects to data-controller="notification"
export default class extends Controller {
  connect() {
    this.channel = createConsumer().subscriptions.create(
      { channel: "NotificationChannel" },
      { received: data => this.#handleReceivedData(data) }
    )
    console.log("Subscribed to NotificationChannel")
  }

  disconnect() {
    console.log("Unsubscribed from NotificationChannel")
    if (this.channel) {
      this.channel.unsubscribe()
    }
  }

  #handleReceivedData(data) {
    try {
      const parsed = JSON.parse(data)

      if (parsed.type === "new_message" || parsed.type === "new_chatroom") {
        this.#showNotification(parsed)
      }
    } catch (e) {
      console.error("Error parsing notification data:", e, "Data:", data)
    }
  }

  #showNotification(notification) {
    // Don't show notification if user is currently viewing that chatroom
    const currentPath = window.location.pathname
    if (currentPath.includes(`/chatrooms/${notification.chatroom_id}`)) {
      return
    }

    const container = document.querySelector(".notifications-container")
    if (!container) return

    const toast = document.createElement("div")
    toast.className = "notification-toast"

    const message = notification.type === "new_message"
      ? `New message in #${notification.chatroom_name}`
      : `New chatroom opened: #${notification.chatroom_name}`

    // Get the current locale from the URL or default to empty
    const locale = window.location.pathname.match(/^\/(en|fr|nl)/)?.[1] || ""
    const localePrefix = locale ? `/${locale}` : ""
    //const chatroomUrl = `${localePrefix}/chatrooms/${notification.chatroom_id}`
    // corrected the chatroom url as chatrooms/0?chatroom=#{chatroom_name}
    //TO DO : change the links to enable url chatrooms/${chatroom_id}`
    const chatroomUrl = `${localePrefix}/chatrooms/0?chatroom=%23${notification.chatroom_name}`

    toast.innerHTML = `
      <a href="${chatroomUrl}" class="notification-link" data-turbo-frame="_top">
        <div class="notification-content">${message}</div>
      </a>
      <button type="button" class="notification-close" data-action="click->notification#dismissToast">&times;</button>
    `

    // Prevent navigation when clicking the close button
    const closeButton = toast.querySelector(".notification-close")
    closeButton.addEventListener("click", (e) => {
      e.stopPropagation()
      e.preventDefault()
    })
//console.log("toast", chatroomUrl)
    // Ensure the link is clickable - add click handler as fallback
    const link = toast.querySelector(".notification-link")
    link.addEventListener("click", (e) => {
      // Let the default link behavior handle navigation
      // Turbo will intercept it automatically
    })

    container.appendChild(toast)

    // Auto-dismiss after 8 seconds
    setTimeout(() => {
      this.#dismissToast({ currentTarget: toast.querySelector(".notification-close") })
    }, 8000)
  }

  dismissToast(event) {
    this.#dismissToast(event)
  }

  #dismissToast(event) {
    const toast = event.currentTarget.closest(".notification-toast")
    if (toast) {
      toast.classList.add("fade-out")
      setTimeout(() => {
        toast.remove()
      }, 300)
    }
  }
}

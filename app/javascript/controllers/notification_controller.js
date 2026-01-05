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

    toast.innerHTML = `
      <div class="notification-content">${message}</div>
      <button type="button" class="notification-close" data-action="click->notification#dismissToast">&times;</button>
    `

    container.appendChild(toast)

    // Auto-dismiss after 5 seconds
    setTimeout(() => {
      this.#dismissToast({ currentTarget: toast.querySelector(".notification-close") })
    }, 5000)
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

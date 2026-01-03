import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

// Connects to data-controller="chatroom-subscription"
export default class extends Controller {
  static values = { chatroomId: Number,
                    chatroomName: String
                  }
  static targets = ["messages"]

  connect(data) {
    this.#scrollDown(data)
    this.channel = createConsumer().subscriptions.create(
      { channel: "ChatroomChannel", id: this.chatroomIdValue },
      { received: data => this.#handleReceivedData(data) }
      )
      console.log(`Subscribed to the chatroom ${this.chatroomNameValue} with the id ${this.chatroomIdValue}.`)
    }

  resetForm(event) {
    event.target.reset()
  }

  disconnect() {
    console.log("Unsubscribed from the chatroom")
    this.channel.unsubscribe()
  }

  #handleReceivedData(data) {
    // Check if it's a delete action (JSON) or a new message (HTML string)
    try {
      const parsed = JSON.parse(data)
      if (parsed.action === "delete") {
        this.#removeMessage(parsed.message_id)
      }
    } catch (e) {
      // Not JSON, treat as HTML message
      this.#insertMessageAndScrollDown(data)
    }
  }

  #removeMessage(messageId) {
    const messageElement = document.getElementById(`message-${messageId}`)
    if (messageElement) {
      messageElement.remove()
    }
  }

  #insertMessageAndScrollDown(data) {
    this.messagesTarget.insertAdjacentHTML("beforeend", data)
    this.#scrollDown(data)
  }

  #scrollDown(data) {
    this.messagesTarget.scrollTo(0, this.messagesTarget.scrollHeight)
  }

  deleteMessage(event) {
    // Get message ID from the link's data attribute or href URL
    const link = event.currentTarget
    const messageId = link.dataset.messageId ||
                      link.href?.match(/\/messages\/(\d+)/)?.[1]

    if (messageId) {
      // Immediately remove the message from DOM for better UX
      // The ActionCable broadcast will also remove it for other users
      this.#removeMessage(parseInt(messageId))
    }
  }
}

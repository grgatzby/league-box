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
      { received: data => this.#insertMessageAndScrollDown(data) }
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

  #insertMessageAndScrollDown(data) {
    this.messagesTarget.insertAdjacentHTML("beforeend", data)
    this.#scrollDown(data)
  }

  #scrollDown(data) {
    this.messagesTarget.scrollTo(0, this.messagesTarget.scrollHeight)
  }
}

import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

// Connects to data-controller="contact-us"
export default class extends Controller {
  static values = { chatroomId: Number }
  static targets = ["message"]

connect(data) {
    this.channel = createConsumer().subscriptions.create(
      { channel: "ChatroomChannel", id: this.chatroomIdValue },
      { received: data => this.#validate(data) }
      )
      console.log(`Subscribed to the chatroom with the id ${this.chatroomIdValue}.`)
    }

submitForm(event) {
    this.messageTarget.classList.remove("d-none")
}


// resetForm(event) {
//       event.target.reset()
//     }

disconnect() {
  console.log("Unsubscribed from the chatroom")
  this.channel.unsubscribe()
}
#validate() {
  console.log("message submitted")
}


}

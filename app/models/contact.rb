class Contact < MailForm::Base
  attribute :subject,   validate: true
  attribute :name,      validate: true
  attribute :email,     validate: /\A([\w\.%\+\-]+)@([\w\-]+\.)+([\w]{2,})\z/i
  attribute :files,     attachment: true
  attribute :phone,     validate: /\(?([0-9]{0,3})\)?([0-9]{0,10})/
  attribute :message,   validate: true
  attribute :nickname,  captcha: true

  def headers
    {
      to: "gcazals06+league_box@gmail.com",       # email sent to
      subject: "League-box request: #{subject}",
      from: "gcazals06+lb_contact@gmail.com",     # email sender
      reply_to: %("#{name}" <#{email}>)           # email form
    }
  end
end

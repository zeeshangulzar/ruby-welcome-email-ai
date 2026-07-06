class WelcomeMailer
  def self.deliver(user, ai_content)
    new(user, ai_content).deliver
  end

  def initialize(user, ai_content)
    @user       = user
    @ai_content = ai_content
  end

  def deliver
    mail = Mailtrap::Mail::FromTemplate.new(
      from:               { email: ENV.fetch("MAILTRAP_FROM_EMAIL"), name: "ACME" },
      to:                 [{ email: @user.email, name: @user.name }],
      template_uuid:      ENV.fetch("MAILTRAP_WELCOME_TEMPLATE_UUID"),
      template_variables: {
        "user_name" => @user.name,
        "headline"  => @ai_content["headline"],
        "body"      => @ai_content["body"],
        "cta_text"  => @ai_content["cta_text"],
        "cta_url"   => ENV.fetch("APP_DASHBOARD_URL", "https://example.com/dashboard")
      }
    )

    client.send(mail)
  end

  private

  # Chooses between Sandbox (safe test inbox, no real delivery) and production
  # sending purely from ENV — no code change needed to flip modes.
  def client
    if sandbox_mode?
      Mailtrap::Client.new(
        api_key:  ENV.fetch("MAILTRAP_API_TOKEN"),
        sandbox:  true,
        inbox_id: ENV.fetch("MAILTRAP_SANDBOX_INBOX_ID")
      )
    else
      Mailtrap::Client.new(api_key: ENV.fetch("MAILTRAP_API_TOKEN"))
    end
  end

  def sandbox_mode?
    ENV["MAILTRAP_ENV"].to_s.strip.downcase == "sandbox"
  end
end

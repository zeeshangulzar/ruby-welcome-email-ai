require "json"

class WelcomeEmailGenerator
  FALLBACK = {
    "headline"  => "Welcome to ACME!",
    "body"      => "Thanks for signing up. We're excited to have you on board — reply to this email if you need anything to get started.",
    "cta_text"  => "Explore your dashboard"
  }.freeze

  def initialize(user)
    @user = user
  end

  def call
    client   = Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"))
    response = client.messages.create(
      model:      "claude-haiku-4-5-20251001",
      max_tokens: 400,
      messages:   [{ role: "user", content: prompt }]
    )

    parse(response.content.first.text.to_s)
  rescue => e
    Rails.logger.error("WelcomeEmailGenerator error: #{e.message}")
    FALLBACK
  end

  private

  def parse(text)
    json = text[/\{.*\}/m]
    return FALLBACK if json.blank?

    data = JSON.parse(json)
    {
      "headline" => data["headline"].to_s.presence  || FALLBACK["headline"],
      "body"     => data["body"].to_s.presence      || FALLBACK["body"],
      "cta_text" => data["cta_text"].to_s.presence  || FALLBACK["cta_text"]
    }
  rescue JSON::ParserError
    FALLBACK
  end

  def prompt
    <<~PROMPT
      Write a short, personalized welcome email for a new SaaS signup.
      Respond with valid JSON only — no markdown, no commentary — with these keys:
        - headline:  a 5–10 word subject line that speaks to their role
        - body:      2–3 sentence email body addressing them by name and referencing their use case
        - cta_text:  a 3–5 word call-to-action button label

      User profile:
        Name:         #{@user.name}
        Role:         #{@user.role}
        Company size: #{@user.company_size}
        Use case:     #{@user.use_case.presence || "not specified"}

      Product name: ACME (a fictional SaaS tool for team collaboration).
    PROMPT
  end
end

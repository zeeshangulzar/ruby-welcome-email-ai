namespace :simulate do
  desc "Simulate a signup — creates a User, calls Anthropic for personalization, and delivers the welcome email via Mailtrap Email API. Usage: bin/rails simulate:welcome_email[you@example.com]"
  task :welcome_email, [:recipient] => :environment do |_t, args|
    recipient = args[:recipient].presence || ENV.fetch("SIMULATE_RECIPIENT", "xeetest786@gmail.com")

    User.where(email: recipient).destroy_all
    user = User.create!(
      name:         "Jane Founder",
      email:        recipient,
      role:         "founder",
      company_size: "1-10",
      use_case:     "Coordinating async engineering standups across 3 timezones."
    )
    puts "Created User ##{user.id} (#{user.email})"

    puts "Generating personalized content with Anthropic..."
    ai_content = WelcomeEmailGenerator.new(user).call
    puts "  headline: #{ai_content['headline']}"
    puts "  body:     #{ai_content['body']}"
    puts "  cta_text: #{ai_content['cta_text']}"

    puts "Delivering via Mailtrap Email API..."
    WelcomeMailer.deliver(user, ai_content)
    user.update!(welcome_email_status: "sent")

    puts "Sent. Check the recipient inbox and Mailtrap → API/SMTP → Email Logs."
  rescue => e
    warn "FAILED: #{e.class} — #{e.message}"
    exit 1
  end
end

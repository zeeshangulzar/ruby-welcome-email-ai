# ruby-welcome-email-ai

A Ruby on Rails demo showing how to send an **AI-personalized welcome email** on SaaS signup using the **Mailtrap Email API** with a template hosted in the Mailtrap dashboard. The same app can route through **Mailtrap Sandbox** for previewing AI-generated copy in development or through the Mailtrap production endpoint for real delivery — the switch is a single env var (`MAILTRAP_ENV`), no code change.

On signup, the app captures the user's `name`, `email`, `role`, `company_size`, and `use_case`. `WelcomeEmailGenerator` calls the [Anthropic API](https://docs.anthropic.com/en/api/getting-started) to generate a personalized `{headline, body, cta_text}` payload, which is passed to the Mailtrap template as variables. The email HTML lives in Mailtrap, not in `app/views`.

## Features

- Signup form at `/signup` collecting profile fields used for personalization
- Anthropic Claude generates a role-aware `{headline, body, cta_text}` for each user
- Email is delivered via `Mailtrap::Mail::FromTemplate` (Email API) with a template UUID and variables map
- **Sandbox / production switching is config-only** — set `MAILTRAP_ENV=sandbox` to route to a safe Mailtrap Sandbox inbox, `MAILTRAP_ENV=production` to send real emails
- Graceful degradation — if the Anthropic API is unavailable, the app falls back to a generic welcome copy
- Mail delivery failures are logged and the user's `welcome_email_status` records `sent`/`failed`
- All signups persisted to the database with input validation and duplicate-email protection

## Architecture

```
Browser ─► POST /signup ─► SignupsController
                                │
                                ├── User.save! (validate + persist)
                                │
                                ├── WelcomeEmailGenerator.call ─► Anthropic API
                                │                                  {headline, body, cta_text}
                                │
                                └── WelcomeMailer.deliver ─► Mailtrap Email API
                                                             (template_uuid + variables)
                                                                      │
                                                     MAILTRAP_ENV ─── │
                                                                      │
                                                  ┌───────────────────┴──────────────────┐
                                                  ▼                                      ▼
                                        Mailtrap Sandbox                        Mailtrap production
                                        (safe test inbox)                       (real delivery)
```

## Requirements

- Ruby 3.3.6
- Rails 7.2
- SQLite3
- A [Mailtrap](https://mailtrap.io) account (free tier works)
- An [Anthropic](https://console.anthropic.com) API key

## Setup

```bash
git clone https://github.com/zeeshangulzar/ruby-welcome-email-ai
cd ruby-welcome-email-ai

bundle install

cp .env.example .env
# Edit .env — add your Mailtrap and Anthropic credentials

rails db:create db:migrate
rails server
```

Open `http://localhost:3000` in your browser.

### Mailtrap setup — one token, two modes

**1. Create the template (used by both modes)**

Go to Mailtrap → **Templates** → **New Template**, category `Transactional`, and paste HTML that references these variables:

- `{{user_name}}`
- `{{headline}}` — AI-generated subject/heading line
- `{{body}}` — AI-generated 2–3 sentence body
- `{{cta_text}}` — AI-generated CTA button label
- `{{cta_url}}` — the target URL for the CTA button

Copy the **Template UUID** into `.env` as `MAILTRAP_WELCOME_TEMPLATE_UUID`.

**2. Create an API token**

Mailtrap → **Settings** → **API Tokens** → **Add API Token** with the **Admin** scope. Put it into `.env` as `MAILTRAP_API_TOKEN`.

**3a. Sandbox mode (recommended for development)**

Mailtrap → **Sandboxes** → open a project inbox → **SMTP/API Integrations** → copy the numeric **Inbox ID**. Set:

```env
MAILTRAP_ENV=sandbox
MAILTRAP_SANDBOX_INBOX_ID=<the numeric id>
```

Emails now land in the Sandbox inbox instead of a real recipient — perfect for iterating on the AI-generated copy.

**3b. Production mode (real delivery)**

Mailtrap → **Domains** → verify your own sending domain, or use the pre-created **`demomailtrap.co`** demo domain (only delivers to your Mailtrap account owner email). Set:

```env
MAILTRAP_ENV=production
MAILTRAP_FROM_EMAIL=hello@demomailtrap.co
```

Restart `rails server` after changing `.env`. No code change is needed to switch between modes.

## Environment Variables

| Variable | Description |
|----------|-------------|
| `MAILTRAP_API_TOKEN` | Mailtrap API token (Admin scope) |
| `MAILTRAP_ENV` | `sandbox` (dev) or `production` (real delivery) |
| `MAILTRAP_SANDBOX_INBOX_ID` | Sandbox inbox numeric ID — required when `MAILTRAP_ENV=sandbox` |
| `MAILTRAP_FROM_EMAIL` | Verified sender address (e.g. `hello@demomailtrap.co`) — used in production mode |
| `MAILTRAP_WELCOME_TEMPLATE_UUID` | UUID of the welcome template in Mailtrap → Templates |
| `APP_DASHBOARD_URL` | URL used in the welcome email's CTA button (optional) |
| `ANTHROPIC_API_KEY` | API key from [console.anthropic.com](https://console.anthropic.com) → API Keys |

## Signup Flow

1. Prospect visits `/signup` and fills in name, email, role, company size, and use case
2. `SignupsController#create` validates and saves the `User`
3. `WelcomeEmailGenerator.new(user).call` sends a prompt to Claude that includes the user's profile and asks for a JSON `{headline, body, cta_text}` response
4. If Anthropic returns a valid response — it is used as the personalized content. If anything goes wrong — the generator returns a hardcoded fallback so signups never break because of AI availability
5. `WelcomeMailer.deliver(user, ai_content)` builds a `Mailtrap::Mail::FromTemplate` with the template UUID and the variables map, then calls the Mailtrap Email API
6. The user's `welcome_email_status` is updated to `sent` or `failed` and the browser is redirected to `/signup/success`

## Key Files

| File | Purpose |
|------|---------|
| `app/controllers/signups_controller.rb` | Signup form, orchestrates persist → generate → deliver |
| `app/services/welcome_email_generator.rb` | Calls Anthropic API and returns `{headline, body, cta_text}` |
| `app/services/welcome_mailer.rb` | Calls Mailtrap Email API with the template UUID + variables |
| `app/models/user.rb` | Validates signup fields and persists the profile |
| `app/views/signups/new.html.erb` | Signup form |
| `app/views/signups/success.html.erb` | Post-signup confirmation page |
| `config/routes.rb` | Defines `/`, `/signup`, `/signup/success` |
| `db/migrate/*_create_users.rb` | Users table with unique email index |

## Mailtrap Integration

The welcome email HTML lives in the Mailtrap dashboard, not in `app/views`. The app calls the Email API with a template UUID and a variables map. The same code path handles both Sandbox and production — only the client instantiation differs, and it's driven entirely by `MAILTRAP_ENV`:

```ruby
# app/services/welcome_mailer.rb
mail = Mailtrap::Mail::FromTemplate.new(
  from:               { email: ENV.fetch("MAILTRAP_FROM_EMAIL"), name: "ACME" },
  to:                 [{ email: user.email, name: user.name }],
  template_uuid:      ENV.fetch("MAILTRAP_WELCOME_TEMPLATE_UUID"),
  template_variables: {
    "user_name" => user.name,
    "headline"  => ai_content["headline"],
    "body"      => ai_content["body"],
    "cta_text"  => ai_content["cta_text"],
    "cta_url"   => ENV.fetch("APP_DASHBOARD_URL", "https://example.com/dashboard")
  }
)

client =
  if ENV["MAILTRAP_ENV"].to_s.downcase == "sandbox"
    Mailtrap::Client.new(
      api_key:  ENV.fetch("MAILTRAP_API_TOKEN"),
      sandbox:  true,
      inbox_id: ENV.fetch("MAILTRAP_SANDBOX_INBOX_ID")
    )
  else
    Mailtrap::Client.new(api_key: ENV.fetch("MAILTRAP_API_TOKEN"))
  end

client.send(mail)
```

## Running Tests

```bash
bundle exec rspec
```

Tests cover:

- User model validations (name, email format, uniqueness, role/company size inclusion)
- Signup form renders and rejects invalid submissions
- Successful signup persists the user and marks welcome email status
- Anthropic generator returns the fallback content when the API errors out

## License

MIT License — see [LICENSE](LICENSE) for details.

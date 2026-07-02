require "rails_helper"

RSpec.describe "Signups", type: :request do
  describe "GET /signup" do
    it "renders the signup form" do
      get signup_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /signup" do
    let(:valid_params) do
      {
        user: {
          name:         "Jane",
          email:        "jane@example.com",
          role:         "founder",
          company_size: "1-10",
          use_case:     "Team standups"
        }
      }
    end

    let(:invalid_params) do
      { user: { name: "", email: "bad", role: "", company_size: "", use_case: "" } }
    end

    context "with valid params" do
      before do
        allow_any_instance_of(WelcomeEmailGenerator).to receive(:call).and_return(WelcomeEmailGenerator::FALLBACK)
        allow(WelcomeMailer).to receive(:deliver)
      end

      it "creates the user and redirects to success" do
        expect { post signup_path, params: valid_params }.to change(User, :count).by(1)
        expect(response).to redirect_to(signup_success_path(user_id: User.last.id))
      end

      it "marks the welcome_email_status as sent when delivery succeeds" do
        post signup_path, params: valid_params
        expect(User.last.welcome_email_status).to eq("sent")
      end

      it "marks the welcome_email_status as failed when delivery raises" do
        allow(WelcomeMailer).to receive(:deliver).and_raise(StandardError, "boom")
        post signup_path, params: valid_params
        expect(User.last.welcome_email_status).to eq("failed")
      end

      it "passes AI-generated content to WelcomeMailer" do
        post signup_path, params: valid_params
        expect(WelcomeMailer).to have_received(:deliver).with(User.last, hash_including("headline", "body", "cta_text"))
      end
    end

    context "with invalid params" do
      it "re-renders the form with errors" do
        post signup_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end

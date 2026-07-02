require "rails_helper"

RSpec.describe User, type: :model do
  let(:valid_attrs) do
    { name: "Jane", email: "jane@example.com", role: "founder", company_size: "1-10", use_case: "Async standups." }
  end

  describe "validations" do
    it "is valid with all required attributes" do
      expect(User.new(valid_attrs)).to be_valid
    end

    it "requires a name" do
      expect(User.new(valid_attrs.merge(name: ""))).not_to be_valid
    end

    it "requires a valid email" do
      expect(User.new(valid_attrs.merge(email: "not-an-email"))).not_to be_valid
    end

    it "requires a unique email (case-insensitive)" do
      User.create!(valid_attrs)
      dup = User.new(valid_attrs.merge(email: "JANE@example.com"))
      expect(dup).not_to be_valid
    end

    it "restricts role to the whitelist" do
      expect(User.new(valid_attrs.merge(role: "ceo"))).not_to be_valid
    end

    it "restricts company_size to the whitelist" do
      expect(User.new(valid_attrs.merge(company_size: "big"))).not_to be_valid
    end
  end

  describe "callbacks" do
    it "normalizes email on save" do
      user = User.create!(valid_attrs.merge(email: "  MIXED@Case.com  "))
      expect(user.email).to eq("mixed@case.com")
    end
  end
end

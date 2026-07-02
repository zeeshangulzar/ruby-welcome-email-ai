class User < ApplicationRecord
  ROLES         = %w[developer designer product_manager founder marketer other].freeze
  COMPANY_SIZES = ["1-10", "11-50", "51-200", "201-1000", "1000+"].freeze
  STATUSES      = %w[pending sent failed].freeze

  validates :name,         presence: true, length: { maximum: 100 }
  validates :email,        presence: true, uniqueness: { case_sensitive: false },
                           format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role,         presence: true, inclusion: { in: ROLES }
  validates :company_size, presence: true, inclusion: { in: COMPANY_SIZES }
  validates :use_case,     length: { maximum: 1000 }
  validates :welcome_email_status, inclusion: { in: STATUSES }

  before_validation :normalize_email

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end

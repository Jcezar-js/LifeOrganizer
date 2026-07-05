class User < ApplicationRecord
  has_secure_password

  has_many :project_memberships, dependent: :destroy
  has_many :projects, through: :project_memberships

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: true
  validates :name, presence: true
  validates :password, length: { minimum: 8 },
                       format: { with: /[^a-zA-Z0-9]/, message: "deve conter pelo menos 1 caractere especial" },
                       allow_nil: true
end

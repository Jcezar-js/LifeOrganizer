class Project < ApplicationRecord
  belongs_to :owner, class_name: "User"
  has_many :memberships, class_name: "ProjectMembership", dependent: :destroy
  has_many :members, through: :memberships, source: :user

  validates :name, presence: true
end

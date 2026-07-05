class ProjectMembership < ApplicationRecord
  belongs_to :project
  belongs_to :user

  # enum de strings: legível direto no banco/logs, sem mapa mental de ints
  enum :role, { owner: "owner", member: "member" }, validate: true

  validates :user_id, uniqueness: { scope: :project_id }
end

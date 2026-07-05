class CreateProjectMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :project_memberships do |t|
      # index: false — índice composto único abaixo cobre prefixo project_id
      t.references :project, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false

      t.timestamps
    end
    add_index :project_memberships, [ :project_id, :user_id ], unique: true
  end
end

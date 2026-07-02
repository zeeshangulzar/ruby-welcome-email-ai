class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :name,                 null: false
      t.string :email,                null: false
      t.string :role,                 null: false
      t.string :company_size,         null: false
      t.text :use_case
      t.string :welcome_email_status, null: false, default: "pending"

      t.timestamps
    end
    add_index :users, :email, unique: true
  end
end

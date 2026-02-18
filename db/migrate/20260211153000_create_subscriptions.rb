class CreateSubscriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :subscriptions do |t|
      t.string :user, null: false
      t.string :ontology, null: false
      t.integer :notification_type, null: false
      t.datetime :created_at, null: false

      t.index :user
      t.index :ontology
      t.index :notification_type
      t.index [:user, :ontology], unique: true
    end
  end
end

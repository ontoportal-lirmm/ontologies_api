class CreateNotifications < ActiveRecord::Migration[7.1]
  def change
    create_table :notifications do |t|
      t.string :source, null: false
      t.string :target, null: false
      t.string :title, null: false
      t.text :body
      t.integer :channels, null: false, default: 1 

      t.datetime :created_at, null: false
      t.datetime :seen_at

      t.index :source
      t.index :target
      t.index :created_at
      t.index :seen_at
    end
  end
end
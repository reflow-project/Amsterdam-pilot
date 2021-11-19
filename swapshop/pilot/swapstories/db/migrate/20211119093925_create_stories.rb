class CreateStories < ActiveRecord::Migration[6.0]
  def change
    create_table :stories do |t|
      t.integer :resource_id
      t.text :content

      t.timestamps
    end
  end
end

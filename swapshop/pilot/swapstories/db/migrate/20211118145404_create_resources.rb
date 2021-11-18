class CreateResources < ActiveRecord::Migration[6.0]
  def change
    create_table :resources do |t|
      t.string :title
      t.text :description
      t.string :image_url
      t.string :tracking_id
      t.integer :shop_id
      t.string :ros_id

      t.timestamps
    end
  end
end

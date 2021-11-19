class CreateEvents < ActiveRecord::Migration[6.0]
  def change
    create_table :events do |t|
      t.integer :event_type
      t.integer :source_agent_id
      t.integer :target_agent_id
      t.integer :resource_id
      t.string :location

      t.timestamps
    end
  end
end

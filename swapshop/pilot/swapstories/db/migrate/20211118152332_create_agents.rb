class CreateAgents < ActiveRecord::Migration[6.0]
  def change
    create_table :agents do |t|
      t.string :label
      t.integer :agent_type
      t.integer :telegram_id
      t.string :ros_id

      t.timestamps
    end
  end
end

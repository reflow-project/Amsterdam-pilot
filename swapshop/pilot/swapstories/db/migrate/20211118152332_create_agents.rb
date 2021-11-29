class CreateAgents < ActiveRecord::Migration[6.0]
  def change
    create_table :agents do |t|
      t.string :label
      t.integer :agent_type
      t.integer :telegram_id
      t.string :ros_id
      t.string :dialog_state #state of the converstation we're currently in
      t.integer :dialog_subject #id of the resource we're talking about 
      t.string :role
      t.timestamps
    end
  end
end

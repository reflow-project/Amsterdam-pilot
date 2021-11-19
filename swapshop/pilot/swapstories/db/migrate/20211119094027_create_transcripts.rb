class CreateTranscripts < ActiveRecord::Migration[6.0]
  def change
    create_table :transcripts do |t|
      t.integer :resource_id
      t.integer :agent_id
      t.text :log

      t.timestamps
    end
  end
end

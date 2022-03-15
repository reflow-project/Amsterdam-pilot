class AddPingAtToAgents < ActiveRecord::Migration[6.0]
  def change
    add_column :agents, :ping_at, :datetime
  end
end

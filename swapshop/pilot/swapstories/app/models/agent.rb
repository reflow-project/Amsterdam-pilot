module AgentType 
  PARTICIPANT = 0
  SWAPSHOP = 1
end

class Agent < ApplicationRecord

  #finds or creates a new agent for a given telegram id
  def self.find_or_create_by_telegram_id(telegram_id)
    agent = Agent.find_by telegram_id: telegram_id
    if(agent == nil)
      agent = Agent.create(label: 'Deelnemer',
               agent_type: 0,
               telegram_id: telegram_id,
               ros_id: nil,
               dialog_state: nil) 
      agent.label = "#{agent.label} #{agent.id}"
      agent.save!
    end
    agent
  end
  
  #toggles the role of the agent instance
  def toggle_role!
    if self.agent_type == AgentType::SWAPSHOP 
      self.agent_type = AgentType::PARTICIPANT 
    else
      self.agent_type = AgentType::SWAPSHOP 
    end
    self.save!
  end
end

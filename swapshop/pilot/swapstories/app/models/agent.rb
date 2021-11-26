module AgentType 
  PARTICIPANT = 0
  SWAPSHOP = 1
end

class Agent < ApplicationRecord
  validates :dialog_state, presence: true
  before_validation :set_initial_state, on: :create

  def set_initial_state
    self.dialog_state = fsm.current
  end

  after_find :restore_state
  after_initialize :restore_state

  def restore_state
    fsm.restore!(self.dialog_state.to_sym) if self.dialog_state.present?
  end

  def fsm
    @fsm ||= FiniteMachine.new(self) do

      initial :root

      #swapshop register new item branch
      event :register, :root => :r_title 
      event :next, :r_title => :r_description 
      event :next, :r_description => :r_photo
      event :next, :r_photo => :root
     
      #participant swap new item branch
      event :swap, :root => :s_q1
      event :next, :s_q1 => :s_q2
      event :next, :s_q2 => :s_q_photo
      event :next, :s_q_photo => :root
    
      on_enter do |event|
        target.dialog_state = event.to
        target.save!
      end
    end
  end

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

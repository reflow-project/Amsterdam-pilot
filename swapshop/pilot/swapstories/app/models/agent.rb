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

      initial :start

      # show intro on start, and then main menu (two messages)
      # or if an item is new item, then we go automatically in new branch
      event :branch_new, :start => :new_kind
      event :branch_main, :start => :main

      #main option branches
      event :branch_care, :main => :care_intro
      event :branch_other, :main => :other_intro
      event :branch_wear, :main => :wear_intro
      event :branch_swap, :main => :swap_intro

      # the care branches
      event :branch_adjusted, :care_intro => :care_adjusted
      event :branch_repaired, :care_intro => :care_repaired
      event :cancel, :care_intro => :main

      # the care adjusted sub branch 
      event :next,
        :care_adjusted => :care_adjusted_reason,
        :care_adjusted_reason => :care_adjusted_end,
        :care_adjusted_end => :main

      # the care repaired sub branch 
      event :next,
        :care_repaired => :care_repaired_end,
        :care_repaired_end => :main

      # the other branch happy flow
      event :next, 
        :other_intro => :other_share,
        :other_share => :other_share_yes,
        :other_share_yes => :main,
        :other_share_no => :main

      # other branch unhappy flow
      event :no, 
        :other_share => :other_share_no

      # the wear branch happy flow
      event :next,
        :wear_intro => :wear_occasion,
        :wear_occasion => :wear_share,
        :wear_share => :wear_share_confirmation,
        :wear_share_confirmation => :main

      # wear branch unhappy flow
      event :no, 
        :wear_intro => :main, # basically a cancel
        :wear_share => :main # we save it but don't share it

      # swap branch flow
      event :next, 
        :swap_intro => :swap_date,
        :swap_date => :swap_origin,
        :swap_origin => :swap_reason,
        :swap_reason => :swap_end,
        :swap_end => :main

      #the 'new' branch happy flow (18 questions)
      event :next, 
        :new_kind => :new_model,
        :new_model => :new_color,
        :new_color => :new_size,
        :new_size => :new_brand,
        :new_brand => :new_material,
        :new_material => :new_extra,
        :new_extra => :new_summary,
        :new_summary => :new_memory, #yes equals next in this case
        :new_memory => :new_date,
        :new_date => :new_usage,
        :new_usage => :new_last,
        :new_last => :new_reason,
        :new_reason => :new_pm,
        :new_pm => :new_photo,
        :new_photo => :new_publish, #yes equals next in this case
        :new_publish => :new_confirmation,
        :new_confirmation => :new_end,
        :new_end => :main #and we're back

      #the 'new' branch exceptions
      event :no, 
        :new_summary => :new_kind, #start over
        :new_publish => :new_end,#skip the publishing part
        :new_photo => :new_end #skip the photo part

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

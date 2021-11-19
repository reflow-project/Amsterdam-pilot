module SwapEvent 
  SWAP_IN = 1
  SWAP_OUT = 2
  USE = 3
  REPAIR = 4
end

class Event < ApplicationRecord

    belongs_to :source, class_name: "Agent", foreign_key: "source_agent_id"
    belongs_to :target, class_name: "Agent", foreign_key: "target_agent_id"
    has_one :resource

    def description
      event_type = read_attribute("event_type")
      case event_type 
        when SwapEvent::SWAP_IN
          "Swap in"
        when SwapEvent::SWAP_OUT
          "Swap out"
        when SwapEvent::USE
          "Use"
        when SwapEvent::REPAIR
          "Repair"
        else
          ""
        end 
    end
end

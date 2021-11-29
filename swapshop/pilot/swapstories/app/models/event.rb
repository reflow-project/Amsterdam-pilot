module SwapEvent 
  BORN = 0
  SWAP_IN = 1
  SWAP_OUT = 2
  USE = 3
  REPAIR = 4
  SWAP = 5
end

class Event < ApplicationRecord

    belongs_to :source, class_name: "Agent", foreign_key: "source_agent_id"
    belongs_to :target, class_name: "Agent", foreign_key: "target_agent_id"
    has_one :resource

    def description
      event_type = read_attribute("event_type")
      case event_type 
        when SwapEvent::BORN # register by shop (produce or raise)
          "Registered in inventory"
        when SwapEvent::SWAP_IN #swap from participant to shop
          "Swap in"
        when SwapEvent::SWAP_OUT #swap from shop to participant
          "Swap out"
        when SwapEvent::SWAP #swap between participants
          "Swap"
        when SwapEvent::USE # use by participant
          "Use"
        when SwapEvent::REPAIR # repair by participant / shop
          "Repair"
        else
          ""
        end 
    end
end

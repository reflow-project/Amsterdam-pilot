module SwapEvent 
  BORN = 0
  SWAP_IN = 1
  SWAP_OUT = 2
  USE = 3
  REPAIR = 4
  SWAP = 5
  ADJUST = 6
end

class Event < ApplicationRecord

    belongs_to :source, class_name: "Agent", foreign_key: "source_agent_id"
    belongs_to :target, class_name: "Agent", foreign_key: "target_agent_id"
    belongs_to :resource

    def description
      event_type = read_attribute("event_type")
      case event_type 
        when SwapEvent::BORN # register by shop (produce or raise)
          "Registered"
        when SwapEvent::SWAP_IN #swap from participant to shop
          "Swapped in"
        when SwapEvent::SWAP_OUT #swap from shop to participant
          "Swapped out"
        when SwapEvent::SWAP #swap between participants
          "Swapped"
        when SwapEvent::USE # use by participant
          "Wear"
        when SwapEvent::REPAIR # repair by participant / shop
          "Repair"
        when SwapEvent::ADJUST # adjustment made by participant / shop
          "Adjustment"
        else
          ""
        end 
    end

  def icon 
      event_type = read_attribute("event_type")
      case event_type 
        when SwapEvent::BORN # register by shop (produce or raise)
          "icon-swap"
        when SwapEvent::SWAP_IN #swap from participant to shop
          "icon-swap"
        when SwapEvent::SWAP_OUT #swap from shop to participant
          "icon-swap"
        when SwapEvent::SWAP #swap between participants
          "icon-swap"
        when SwapEvent::USE # use by participant
          "icon-use"
        when SwapEvent::REPAIR # repair by participant / shop
          "icon-repair"
        when SwapEvent::ADJUST # adjustment made by participant / shop
          "icon-adjust"
        else
          ""
        end 
    end

end

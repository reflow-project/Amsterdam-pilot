class Event < ApplicationRecord
    belongs_to :source, class_name: "Agent", foreign_key: "source_agent_id"
    belongs_to :target, class_name: "Agent", foreign_key: "target_agent_id"
    has_one :resource
end

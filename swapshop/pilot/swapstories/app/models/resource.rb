class Resource < ApplicationRecord
  has_many :events
  has_many :transcripts
  has_one :story
  accepts_nested_attributes_for :story

  #returns last chat transcript or self
  def last_activity
    return self.transcripts.last.created_at rescue self.updated_at 
  end

  def current_state
    return Agent.find(self.owner).dialog_state rescue ''
  end

  def participant 
    return Agent.find(self.owner).label rescue ''
  end

end

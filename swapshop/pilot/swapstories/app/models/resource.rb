class Resource < ApplicationRecord
  has_many :events
  has_many :transcripts
  has_one :story
end

class EventObserver < ActiveRecord::Observer
  def after_create(event)
    puts("New event has been created: #{event.id}: of type: #{event.event_type}")
  end
end

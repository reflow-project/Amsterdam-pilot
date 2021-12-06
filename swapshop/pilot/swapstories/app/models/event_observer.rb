# this class is responsible for observing event changes and to sync the changes when appropriate
class EventObserver < ActiveRecord::Observer
  def after_create(event)
    puts("New event has been created: #{event.id}: of type: #{event.event_type}")
    if(event.event_type == SwapEvent::BORN)
      #TODO create economic event in reflow os and return the resource id and save that in the event.resource
      puts "registering: #{event.resource.inspect} in reflow os"
      event.resource.ros_id = "XXX"
      event.resource.save
    end
  end
end

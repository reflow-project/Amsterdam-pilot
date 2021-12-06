# this class is responsible for observing event changes and to sync the changes when appropriate
class EventObserver < ActiveRecord::Observer
  def after_create(event)
    puts("New event has been created: #{event.id}: of type: #{event.event_type}")
    if(event.event_type == SwapEvent::BORN)
      # TODO require the reflow os client
      # TODO configure the reflow os client from the env file with the shared instance 
      # TODO also create a ros id for the event table to keep a reference to that, and to keep track on what is synced
      # TODO create a 'produce' economic event in reflow os and return the resource id and save 
      # that in the event.resource.ros_id, and the event id in the event.ros_id
      #
      puts "registering: #{event.resource.inspect} in reflow os"
      event.resource.ros_id = "XXX"
      event.resource.save
    end
  end
end

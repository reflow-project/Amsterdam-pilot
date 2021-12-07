# this class is responsible for observing event changes and to sync the changes when appropriate
class EventObserver < ActiveRecord::Observer
  def after_create(event)
    puts("New event has been created: #{event.id}: of type: #{event.event_type}")
    if(event.event_type == SwapEvent::BORN)

      puts "registering: #{event.resource.inspect} in reflow os"
      client = ReflowOsClient.new
      puts client.me(ENV['ROS_SWAPSHOP_TOKEN'])

      # TODO create a ros id for the event table to keep a reference to that, and to keep track on what is synced
      # TODO event.ros_id = "EEE"
      # TODO create a 'produce' economic event in reflow os and return the resource id and save 
      # TODO event.resource.ros_id = "XXX"
      # TODO event.resource.save

    end
  end
end

# this class is responsible for observing event changes and to sync the changes when appropriate
require 'date'

class EventObserver < ActiveRecord::Observer
  def after_create(event)
    puts("New event has been created: #{event.id}: of type: #{event.event_type}")
    if(event.event_type == SwapEvent::BORN)

      puts "registering: #{event.resource.inspect} in reflow os"
      begin
        client = ReflowOsClient.new
        token = client.login(ENV['ROS_EMAIL'],ENV['ROS_PW'])
        agent_id = client.me(token)

        result = client.produce_one(
          token, 
          agent_id, 
          event.resource.title, 
          event.resource.tracking_id, 
          ENV['ROS_LOCATION'],
          "born event for item #{event.resource.id}",
          event.resource.description,
          event.created_at.iso8601,
          ENV['ROS_UNIT'])

        event.ros_id = result.id
        event.resource.ros_id = result.resource_inventoried_as.id  
        event.resource.save!
        event.save!
      rescue => e
        puts "Reflow OS Client error: #{e}"
      end
    end
  end
end

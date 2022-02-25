require 'dotenv/load'
SKU_REGEX = %r{\ARP(?<nr>\d\d\d\d\d)\Z}
class NarrativesController < ApplicationController

  http_basic_authenticate_with name: "admin", password: ENV['ROLE_PW'], except: :show
  def show
    #1. validate code
    tracking_id = params[:id]
    if is_valid?(tracking_id)
      @resource= Resource.where(["tracking_id = ?", params[:id]]).first
      if @resource == nil
        res = Resource.create(title: '',
                          description: '',
                          image_url: nil,
                          tracking_id: tracking_id,
                          shop_id: nil,
                          ros_id: nil,
                          owner: nil) 
        Story.create(resource_id: res.id,
                 content: "")

        @resource = res
      end
    else
      not_found
    end
  end

  def edit
    @resource= Resource.where(["tracking_id = ?", params[:id]]).first or not_found
  end

  def update
    @resource= Resource.where(["tracking_id = ?", params[:id]]).first or not_found
    
    if @resource.update(resource_params)
      @resource.story.update(story_params)
      flash[:notice] = "Resource successfully updated"
    end
    redirect_to action: :edit 
  end

  def list
    @resources = Resource.all
  end

  private
    def resource_params
          params.require(:resource).permit(:title, :description)
    end

    def story_params
          params.require(:story).permit(:content)
    end

    def is_valid?(tracking_id)
      valid_id = false
      if tracking_id.match(SKU_REGEX)
        tracking_nr = tracking_id.match(SKU_REGEX)[:nr].to_i 
        valid_id = tracking_nr > 0 and tracking_nr <= 2500
      end
      valid_id
  end

end

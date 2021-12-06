require 'dotenv/load'
class NarrativesController < ApplicationController

  http_basic_authenticate_with name: "admin", password: ENV['ROLE_PW'], except: :show
  def show
    @resource= Resource.where(["tracking_id = ?", params[:id]]).first or not_found
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
end

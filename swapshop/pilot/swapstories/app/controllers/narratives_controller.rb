class NarrativesController < ApplicationController
  def show
    @resource= Resource.where(["tracking_id = ?", params[:id]]).first or not_found
  end
end

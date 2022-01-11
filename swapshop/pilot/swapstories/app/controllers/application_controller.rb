class ApplicationController < ActionController::Base
  skip_forgery_protection
  def render_not_found
    render :file => "#{Rails.root}/public/404.html",  :status => 404
  end

  def not_found
      raise ActionController::RoutingError.new('Not Found') rescue render_not_found
  end

end

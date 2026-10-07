class ApplicationController < ActionController::Base
  include Pagy::Backend

  before_action :authenticate_user!
  # skip_forgery_protection

  def after_sign_in_path_for(_resource)
    # iOS app + phone browsers: land on Future list, not Plan (matches native Future tab).
    helpers.mobile_browser? ? root_path(anchor: "future") : root_path
  end

end

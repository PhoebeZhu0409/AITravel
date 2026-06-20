class ApplicationController < ActionController::Base
  include Pagy::Backend

  before_action :authenticate_user!
  # skip_forgery_protection

  def after_sign_in_path_for(resource)
  root_path
end

end

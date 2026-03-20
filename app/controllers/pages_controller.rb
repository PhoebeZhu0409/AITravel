# frozen_string_literal: true

# Public marketing / legal pages (no login required).
class PagesController < ApplicationController
  skip_before_action :authenticate_user!

  def legal_notices
   render({ :template => "trip_templates/legal_notices" })
  end

  def terms_of_use
    render({ :template => "trip_templates/terms_of_use" })
  end
  
  def privacy_policy
    render({ :template => "trip_templates/privacy_policy" })
  end
end

# frozen_string_literal: true

# Lightweight auth probe for native apps (WKWebView). Does not redirect to HTML sign-in.
class SessionStatusController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    if user_signed_in?
      render json: { authenticated: true }
    else
      render json: { authenticated: false }, status: :unauthorized
    end
  end
end

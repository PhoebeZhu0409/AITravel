# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_account_update_params, only: [:update]

  protected

  def after_update_path_for(_resource)
    edit_registration_path
  end

  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, keys: %i[username avatar])
  end
end

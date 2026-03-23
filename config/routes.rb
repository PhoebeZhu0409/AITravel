Rails.application.routes.draw do
  devise_for :users

  # Public pages (no sign-in)
  get("/legal-notices", { :controller => "pages", :action => "legal_notices" })
  get("/terms-of-use", { :controller => "pages", :action => "terms_of_use" })
  get("/privacy-policy", { :controller => "pages", :action => "privacy_policy", :as => :privacy_policy })
  # Routes for the Trip resource:

  # CREATE
  post("/insert_trip", { :controller => "trips", :action => "create" })

  # READ
  get("/trips", { :controller => "trips", :action => "index" })
  #get("/", { :controller => "trips", :action => "index" })
  root to: "trips#index"

  get("/trips/:path_id", { :controller => "trips", :action => "show" })

  # UPDATE
  post("/trip_name_update/:path_id", { :controller => "trips", :action => "trip_name_update" })
  get("/modify/:path_id", { :controller => "trips", :action => "rebuild_form" })
  post("/modify_trip/:path_id", { :controller => "trips", :action => "update" })

  # DELETE
  get("/delete_trip/:path_id", { :controller => "trips", :action => "destroy" })

  # ------------------------------

  # Routes for the Trip plan resource:

  # # CREATE
  # post("/insert_trip_plan", { :controller => "trip_plans", :action => "create" })

  # # READ
  # get("/trip_plans", { :controller => "trip_plans", :action => "index" })

  # get("/trip_plans/:path_id", { :controller => "trip_plans", :action => "show" })

  # # UPDATE

  # post("/modify_trip_plan/:path_id", { :controller => "trip_plans", :action => "update" })

  # # DELETE
  # get("/delete_trip_plan/:path_id", { :controller => "trip_plans", :action => "destroy" })

  # #------------------------------

  
  # This is a blank app! Pick your first screen, build out the RCAV, and go from there. E.g.:
  # get("/your_first_screen", { :controller => "pages", :action => "first" })


  # forget password, reset email 
mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

end

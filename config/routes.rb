Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }

  # Public pages (no sign-in)
  get("/legal-notices", { :controller => "pages", :action => "legal_notices" })
  get("/terms-of-use", { :controller => "pages", :action => "terms_of_use" })
  get("/privacy-policy", { :controller => "pages", :action => "privacy_policy", :as => :privacy_policy })
  get("/who-am-i", { :controller => "pages", :action => "who_am_i", :as => :who_am_i })
  get("/showcase/madrid", { :controller => "pages", :action => "showcase_madrid", :as => :showcase_madrid })
  get("/showcase/new-york", { :controller => "pages", :action => "showcase_new_york", :as => :showcase_new_york })
  get("/showcase/madrid/download_agenda", { :controller => "pages", :action => "showcase_madrid_pdf", :as => :showcase_madrid_pdf })
  get("/showcase/new-york/download_agenda", { :controller => "pages", :action => "showcase_new_york_pdf", :as => :showcase_new_york_pdf })
  # Routes for the Trip resource:

  # CREATE
  post("/insert_trip", { :controller => "trips", :action => "create" })

  # READ
  get("/trips", { :controller => "trips", :action => "index" })
  get("/plan-a-day", { :controller => "trips", :action => "plan_a_day", :as => :plan_a_day })
  #get("/", { :controller => "trips", :action => "index" })
  root to: "trips#index"

  # No ".pdf" in the path — some hosts/proxies try to serve it as a static file and never hit Rails.
  get("/trips/:path_id/download_agenda", { :controller => "trips", :action => "agenda_pdf", :as => :trip_agenda_pdf })
  get("/trips/:path_id/agenda.pdf", { :controller => "trips", :action => "agenda_pdf" })

  get("/trips/:path_id", { :controller => "trips", :action => "show" })
  get("/trips/:path_id/generation_status", { :controller => "trips", :action => "generation_status" })

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

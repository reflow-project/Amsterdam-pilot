Rails.application.routes.draw do
  get "/code/:id", to: "narratives#show"
  get "/edit/:id", to: "narratives#edit"
  get "/cms", to: "narratives#list"
  put "/update/:id", to: "narratives#update"
  patch "/update/:id", to: "narratives#update"
end

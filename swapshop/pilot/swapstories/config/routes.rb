Rails.application.routes.draw do
  get "/code/:id", to: "narratives#show"
  get "/edit/:id", to: "narratives#edit"
  put "/update/:id", to: "narratives#update"
  patch "/update/:id", to: "narratives#update"
end

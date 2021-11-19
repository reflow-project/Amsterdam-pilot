Rails.application.routes.draw do
  get "/code/:id", to: "narratives#show"
end

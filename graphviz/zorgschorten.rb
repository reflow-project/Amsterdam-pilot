require_relative 'dsl.rb'

graph("Zorgschorten") {

  agent :A1, "Hospital"
  agent :A2, "Laundry Service"
  agent :A3, "Textile Service Company"

  resource :R1, "Gown Lot (dirty)"
  resource :R2, "Gown Lot (dirty)"
  resource :R3, "Gown Lot (clean)"
  resource :R4, "Gown Lot (clean)"
  resource :R5, "Gown Vol (inv up)"
  resource :R6, "Gown Vol (inv down)"

  event :E1, "Transfer (pickup)" 
  event :E2, "Work (laundry)" 
  event :E3, "Transfer" 
  event :E4, "Modify (QI)" 
  event :E5, "Transfer (Delivery)" 
  event :E6, "Use (Wear)"

  role :E1, :A1, "provider"
  role :E1, :A2, "receiver"
  role :E2, :A2, "performer"
  role :E3, :A2, "provider"
  role :E4, :A3, "inspector"
  role :E5, :A3, "provider"
  role :E5, :A1, "receiver"
  role :E6, :A1, "user"

  flow [:R1,:E1,:R2,:E2,:R3,:E3,:R4,:E4,:R5,:E5,:R6,:E6,:R1]
}

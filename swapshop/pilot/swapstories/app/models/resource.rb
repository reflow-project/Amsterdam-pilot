class Resource < ApplicationRecord
  has_many :events
  has_many :transcripts
  has_one :story
  accepts_nested_attributes_for :story

  #returns last chat transcript or self
  def last_activity
    return self.transcripts.last.created_at rescue self.updated_at 
  end

  def current_state
    return Agent.find(self.owner).dialog_state rescue ''
  end

  def participant 
    return Agent.find(self.owner).label rescue ''
  end

  def impact_co2_string
    co2_kg = {
      "Blouse" => 0.87, 
      "Jeans" => 4.21,
      "Dress" => 1.20,
      "T-shirt" => 0.72,
      "Pants" => 1.78,
      "Top (sleeveless)" => 0.43,
      "Sweater" => 3.81,
      "Skirt" => 1.47,
      "Other" => 1.81
    } 

    co2_cups = {
      "Blouse" => 24, 
      "Jeans" => 117,
      "Dress" => 33,
      "T-shirt" => 20,
      "Pants" => 49,
      "Top (sleeveless)" => 12,
      "Sweater" => 106,
      "Skirt" => 41,
      "Other" => 50 
    } 
 
    garment_type = self.transcripts.where(:dialog_key => :new_kind).first.dialog_value rescue nil
    nr_of_swaps = self.events.select{|event|
      event.event_type == 0 || 
      event.event_type == 1 || 
      event.event_type == 2 || 
      event.event_type == 5
    }.count 

    if(garment_type != nil)
      co2_impact_kg = co2_kg[garment_type] ||= 0 
      co2_impact_cups = co2_cups[garment_type] ||= 0 
      if(co2_impact_kg > 0 && co2_impact_cups > 0 && nr_of_swaps > 0)
        return "You saved the equivalent of #{nr_of_swaps * co2_impact_cups} cups of coffee! (#{nr_of_swaps * co2_impact_kg} kg of CO2) by swapping this item"       
      end
    end

    return "" #we werent' able to calculate anything meaningful
  end

  # same as above
  #0,29    6    Wasbeurten 
  #2,99    60    Wasbeurten 
  #0,24    5    Wasbeurten 
  #0,31    6    Wasbeurten 
  #0,23    5    Wasbeurten 
  #0,16    3    Wasbeurten 
  #0,75    15    Wasbeurten 
  #0,33    7    Wasbeurten 
  #0,66    13    Wasbeurten 
  def impact_water_string
    water_kg = {
      "Blouse" => 0.29, 
      "Jeans" => 2.99,
      "Dress" => 0.24,
      "T-shirt" => 0.31,
      "Pants" => 0.23,
      "Top (sleeveless)" => 0.16,
      "Sweater" => 0.75,
      "Skirt" => 0.33,
      "Other" => 0.66 
    } 

    water_cups = {
      "Blouse" => 6, 
      "Jeans" => 60,
      "Dress" => 5,
      "T-shirt" => 6,
      "Pants" => 5,
      "Top (sleeveless)" => 3,
      "Sweater" => 15,
      "Skirt" => 7,
      "Other" => 13 
    } 
 
    garment_type = self.transcripts.where(:dialog_key => :new_kind).first.dialog_value rescue nil
    nr_of_swaps = self.events.select{|event|
      event.event_type == 0 || 
      event.event_type == 1 || 
      event.event_type == 2 || 
      event.event_type == 5
    }.count 

    if(garment_type != nil)
      water_impact_kg = water_kg[garment_type] ||= 0 
      water_impact_cups = water_cups[garment_type] ||= 0 
      if(water_impact_kg > 0 && water_impact_cups > 0 && nr_of_swaps > 0)
        return "You saved the equivalent of #{nr_of_swaps * water_impact_cups} laundry cycles (#{(nr_of_swaps * water_impact_kg * 1000).to_i} liters of water) by swapping this item"       
      end
    end

    return "" #we werent' able to calculate anything meaningful

  end

end

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)
require 'dotenv/load'
telegram_id = ENV['TELEGRAM_SEED_ID'] #for telegram id for dev purposes

Resource.create(title: 'Groen roze bloemenprint maxi rok',
                description: 'Groen roze bloemenprint maxi rok, gemaakt van 100% polyester, maat onbekend (waarschijnlijk S), geplooid aan de voor- en achterkant en ritssluiting aan de linker zijkant',
                image_url: 'https://cdn.webshopapp.com/shops/314295/files/384536825/750x1000x1/groen-roze-bloemenprint-maxi-rok.jpg',
                tracking_id: 'RP00017',
                shop_id: '998',
                ros_id: nil)

Resource.create(title: 'Blauw rode geruitte rok',
                description: 'Blauw rode klokkende rok, maat onbekend (M), materiaal onbekend, klokkend model, ritssluiting met knoop',
                image_url: 'https://cdn.webshopapp.com/shops/314295/files/384542229/image.jpg',
                tracking_id: 'RP00018',
                shop_id: '999',
                ros_id: nil)

Resource.create(title: 'Wit spetter print trainingsjack',
                description: ' Witte spetter print trainingsjack, maat S (valt ruim), materiaal onbekend, gevoerd en heeft 2 zakken met ritsen',
                image_url: 'https://cdn.webshopapp.com/shops/314295/files/384536080/image.jpg',
                tracking_id: 'RP00019',
                shop_id: '1000',
                ros_id: nil)

Agent.create(label: 'Swapshop',
             agent_type: 'swapshop',
             telegram_id: telegram_id,
             ros_id: nil) ##todo create once through makefile

Agent.create(label: 'Anonymous Participant 1',
             agent_type: 'participant',
             telegram_id: telegram_id,
             ros_id: nil) ##todo create once through makefile

Agent.create(label: 'Anonymous Participant 2',
             agent_type: 'participant',
             telegram_id: telegram_id,
             ros_id: nil) ##todo create once through makefile

Event.create(event_type: 1, #swap in
             source_agent_id: 2, #deelnmer 1
             target_agent_id: 1, #swap shop
             resource_id: 1, #maxi rok
             location: "Amsterdam")

Event.create(event_type: 2, #swap out 
             source_agent_id: 1, #swap shop
             target_agent_id: 2, #deelnemer 1
             resource_id: 2, #geruitte rok
             location: "Amsterdam")

Event.create(event_type: 3, #wear 
             source_agent_id: 2, #deelnemer 1
             target_agent_id: nil, 
             resource_id: 2, #geruitte rok
             location: "Amsterdam")

Event.create(event_type: 1, #swap in
             source_agent_id: 3, #deelnmer 2
             target_agent_id: 1, #swap shop
             resource_id: 3, # trainings jack
             location: "Amsterdam")

Event.create(event_type: 2, #swap out 
             source_agent_id: 1, #swap shop
             target_agent_id: 3, #deelnemer 2
             resource_id: 1, #maxi rok
             location: "Amsterdam")

Event.create(event_type: 3, #wear 
             source_agent_id: 3, #deelnemer 2
             target_agent_id: nil, 
             resource_id: 1, #maxi rok
             location: "Amsterdam")

Story.create(resource_id: 1,
             content: "i don't really like new stuff. But i like this skirt!")

Story.create(resource_id: 2,
             content: "i always wear this when working from home!")

Story.create(resource_id: 3,
             content: "this was my perfect 90's look!")

Transcript.create(resource_id: 1,
                  agent_id: 2,
                  log: "@bot: Waarom koos je dit item? \n@joe: Daarom!\n")

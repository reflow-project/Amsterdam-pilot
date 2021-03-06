## What is this?
This folder contains software to 'simulate' value flows in in Reflow OS, without having to write GraphQL queries by hand.
It is is an extension on the dsl used to create Value Flow diagrams in the same repository. The idea is to declaratively describe a scenario on a high level, but with control over duration, amounts of resources, frequencies of and dependencies between events for a scenario.

## Running the Amsterdam scenarios
There are two scenario's for Amsterdam each in their own subdirectory, 'swapshop' and 'zorgschorten'.
Steps to run a scenario:

- 0. make sure that you have all ruby dependencies installed (bundle install, or see the Gemfile)
- 1. make sure that you are working with a fresh reflow-os instance that is set up locally on port 4000, see ``reset_db.sh``, double check that the reflow os installation directory is defined in an .env file: e.g. ``REFLOW_OS_PATH=~/Projects/reflow_os``
- 2. run ``ruby swapshop/simulation.rb`` or similar to start the simulation, all necessary units, locations and agents will be set up in the simulation

## Features supported so far 
The simulation software at the moment aims to support the two scenario's in the Amsterdam pilot. 
Right now only the ValueFlow features that are necessary for the 'medical gowns' (zorgschorten) scenario have been developed. A scenario for the 'Swap shop' scenario will follow. We expect big overlap between the two scenario's.

### Simulation period 

In the top level simulation directive you can specify a name, start date and an end date of the scenario, e.g.

``` 
simulation("Zorgschorten", Date.today, Date.today + 30) do 
... 
end
```

### Units
First you declare units used in the simulation.
```
unit :u_piece, "om2:one", "#"
```

### Resources

You can then declare identifiable *resource* types, with a unit, and attach a generator block to create fake instances of the resource, e.g.

``` 
resource :gown, "Gown", :u_piece do
    rid = SecureRandom.uuid
    {:tracking_id => "http://cleanlease.nl/zs/#{rid}", :description => "Clean Lease Schort: #{rid}"}
  end
```

You can declare *containers* (named container resources used for transfers) that can be used to bundle identifiable resources of a certain type, e.g.

```
container :gown_dirty_container, "Gown Container (dirty)", :gown 
```

### Agents

The *agent* directive is used to declare agents that take part in the scenario. User accounts are made on demand. For each agent you can specify the credentials that should be used to login Reflow OS. You can specify the default location of the agent, and declare *pools* or *inventories* (container resource used for stocks) of identifiable resources that are owned by this agent at the start of the simulation. You can quantify the number of resources in the pool/inventory, they will be generated according to the generator block in the resource directive e.g.

```
agent :a_hospital, "OLVG" do
      location 52.35871773455108, 4.916762398221842,
	 	"Oosterpark 9, 1091 AC Amsterdam",
		"OLVG locatie oost",
        "olvg.nl"
      pool :gown_in_use, "Gowns (in use)", :gown, 10 
  end

```
In the above example 10 gowns will be generated in the :gown_in_use pool at the beginning of the simulation.

### Events

The *event* directive is used to declare economic event types. Each event should contain a *schedule* directive that specifies when and how often the event is triggered during the simulated period. In the *cron* argument you can specify a frequency number in days. 1 means that the event is triggered every simulated day. 2 every other day, 7 every week etc. e.g.

```
 event :e_transfer_pickup, "pickup" do 
    schedule cron: 7  
    process do
    ...
    end
  end 
```

With the *on_event* you can specify the key of the event type that will trigger this event type, effectively chaining one event type to another. In combination with *on_event* argumet you can use the *with_delay* argument to can specify a delay on the trigger in days, for example 1 would delay the event by one day after the trigger event. e.g.

```
 event :e_laundry, "Modify (clean)" do
    schedule on_event: :e_transfer_pickup, with_delay: 1 
    process do
    ...
    end
  end 
```

In the *process* block you can specify what actions happen in the event, who performs them, and what resources are affected. 

```
event :e_transfer_pickup, "pickup" do 
    schedule cron: 7  
    process do
      as_performer :a_hospital
      pool_take :gown_dirty_pool
      pack_container :gown_dirty_container
      transfer_container :gown_dirty_container, :a_hospital, :a_launderer 
    end
  end 
```
In above example all actions below *as_performer* are executed while logged in as the agent ':a_hospital'. 
*pool_take* (without an amount specified) takes all items from the pool and puts them in the 'context batch'
*pack_container* bundles all items in the 'context batch' into a new container, saved under the key ':gown_dirty_container'
*transfer_container* transfers the container saved under key ':gown_dirty_container' from agent ':a_hospital' to agent ':a_launderer'.

### Commands  
The following command directives are available for chaining together in a process block:

- __as_performer__: set the active agent, all commands will be executed in this context until changed
- __pool_take__: take an amount or all items from a pool to put in the *context batch* for other actions 
- __pool_put__: put all items in the *context batch* in the pool 
- __inventory_take__: take an amount or all items from an inventory and put in the *context batch* for other actions
- __inventory_put__: put all items in the context batch in the inventory
- __container_take__: take all items from the container and put in the *context batch* for other actions
- __container_put__: put all items from the *context batch* in the container 
- __pack_container__: pack all items from the *context batch* in a container resource. In reflow os this works by vf:consuming all contained items, and vf:producing a container resource that contains a manifest note of all tracking identifiers of the contained items
- __unpack_container__: unpack all items from the container and place them into the *context batch*. In reflow os this works by vf:consuming the container resource and vf:producing (resurrecting) all the contained items in the manifest again.
- __transfer_container__: perform a vf:transfer economic event on a container from a providing agent to a receiving agent. The providing agent should be the active agent specified with *as_performer*
- __use_batch__: perform a vf:use economic event on each item in the *context batch*
- __modify_batch__: perform a vf:modify economic event on each item in the *context batch*
- __pass_batch__: remove 'amount' items from the *context batch* and place them in the *failed context batch*. the 'passed' items remain in the default *context batch*. this can be used for quality inspection / failure scenarios etc.

## Example scenario output

This is the output for the really short [zorgschorten_simple.rb](zorgschorten_simple.rb) scenario. It has only one day and one event and one medical gown, but it does include two agents and a few command directives including a pack, transfer and unpack.

```
2021-09-26 -> 2021-09-27
--- SETUP ---
AGENTS
a_hospital: {:label=>"OLVG", :token=>"QTEyOEdDTQ.j9O0lgZqeX29Kia36TsmzxcBy5D_2dyr0Ka0m0ltZYuXjzNZaJlikYJDYC4.m1CqEa7_f_3dSYKN.W-ZOb4H_Sb98RoIUS0Uj0UOKRZjDAVWU1LayBjve9i8uy1742vfl74V1pb8A11xK.NE3v7weeBBTZmVsfLuw2mg", :agent_id=>"01FF84K296NSPKGQ39QD5EY30C", :location=>"01FF84V8MWSEKNQ3ZQCRT8CPM8"}
a_launderer: {:label=>"Clean Lease Laundry Service", :token=>"QTEyOEdDTQ.lWMNkUgQKzSx3a9h3fHE3O8ctbhsyLD9Qc5jngBeN9VY298x23yyl-eEuns.DgCh-PuGTNvoGBOu.98qSJ-JDlP7Ogep9KQUgQQ9fP5rZv_BVjV-P1f25ZAJDlgkjmpcLJMqdSbo3ZwDq.TyhZ7yBYgP5gMiQFwbnxiA", :agent_id=>"01FF84PJFC845FTTP59B3SBS6P", :location=>"01FF853TGK8GZBF0FE46NT7CM4"}
LOTS
a_container: 0
POOLS
gowns: 1 (a_hospital)
INVENTORIES
--- RUN SIMULATION ---
2021-09-26: processing event: test
graphql USE by a_hospital on 1 items
Created Reflow OS Use event: 01FGKD4ZA3SAZ42ZEXHDDE6P0W
graphql CONSUME 1 items by a_hospital
Created Reflow OS Consume event: 01FGKD50K534EPDK9AHM80HHVA
graphql PRODUCE a_container with 1 items by a_hospital
manifest: http://cleanlease.nl/zs/a447dd73-88d9-4927-a334-2fa259d5cb9a
Created Reflow OS Contaienr event: 01FGKD51T706X1890Y29A4Z9TK
graphql TRANSFER of gown Container from OLVG to Clean Lease Laundry Service
Created Reflow OS TRANSFER event: 01FGKD534C6W8ZMY6PGD8M0GZR
graphql MODIFY by a_launderer on 1 items
Created Reflow OS Modify event: 01FGKD55N94JKEPW99QNQZJKZJ
--- AFTER ---
AGENTS
a_hospital: {:label=>"OLVG", :token=>"QTEyOEdDTQ.j9O0lgZqeX29Kia36TsmzxcBy5D_2dyr0Ka0m0ltZYuXjzNZaJlikYJDYC4.m1CqEa7_f_3dSYKN.W-ZOb4H_Sb98RoIUS0Uj0UOKRZjDAVWU1LayBjve9i8uy1742vfl74V1pb8A11xK.NE3v7weeBBTZmVsfLuw2mg", :agent_id=>"01FF84K296NSPKGQ39QD5EY30C", :location=>"01FF84V8MWSEKNQ3ZQCRT8CPM8"}
a_launderer: {:label=>"Clean Lease Laundry Service", :token=>"QTEyOEdDTQ.lWMNkUgQKzSx3a9h3fHE3O8ctbhsyLD9Qc5jngBeN9VY298x23yyl-eEuns.DgCh-PuGTNvoGBOu.98qSJ-JDlP7Ogep9KQUgQQ9fP5rZv_BVjV-P1f25ZAJDlgkjmpcLJMqdSbo3ZwDq.TyhZ7yBYgP5gMiQFwbnxiA", :agent_id=>"01FF84PJFC845FTTP59B3SBS6P", :location=>"01FF853TGK8GZBF0FE46NT7CM4"}
CONTAINERS
a_container: 0
POOLS
gowns: 0 (a_hospital)
INVENTORIES
```

 

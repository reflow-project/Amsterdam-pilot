# Swapshop graphql calls

## Create a Resource (EconomicResource)

Api call for creating the resource through an economic event.
The idea here is to create an 'on hand' inventory count of swappable clothing pieces.

```
mutation doCreateEconomicEvent($event:EconomicEventCreateParams!, $newInventoriedResource:EconomicResourceCreateParams) {
  createEconomicEvent(event:$event, newInventoriedResource:$newInventoriedResource) {
        economicEvent {
      id
      note
      receiver {
        id
        name
        note
      }
      provider {
        id
        name
        note
      }
      resourceQuantity {
        hasNumericalValue
        hasUnit {
          label
          symbol
        }
      }
      resourceInventoriedAs { # the newly created resource
        id
        name
        onhandQuantity {
          hasNumericalValue
          hasUnit {
            label
            symbol
          }
        }
        accountingQuantity {
          hasNumericalValue
          hasUnit {
            label
            symbol
          }
        }
      }
    }
  }
}
```

You don't have to ask for all the data, the important part is the resource id.
So if you're only interested in this you could do with:

``` 
mutation doCreateEconomicEvent($event:EconomicEventCreateParams!, $newInventoriedResource:EconomicResourceCreateParams) {
  createEconomicEvent(event:$event, newInventoriedResource:$newInventoriedResource) {
        economicEvent {
			resourceInventoriedAs { 
        		id
			}
		}
	}
}
```

Passed in variables: 

- (01F9VN1M42RTS4JDCK278VZCMT is the id of my user account)
- (01F9X1XCVD7KPF0X21EDQPKCHY is the id of a previously created Unit)

```
{
  "event": {
      "note": "genesis event",
      "action": "produce",
      "provider": "01F9VN1M42RTS4JDCK278VZCMT",
      "receiver": "01F9VN1M42RTS4JDCK278VZCMT",
      "resourceQuantity": {
        "hasUnit": "01F9X1XCVD7KPF0X21EDQPKCHY", 
        "hasNumericalValue": 0.0
      }
    },
    "newInventoriedResource": { 
      "name": "TotalItemsInShop"
    }
}
```

## View a resource
Api call for the resource we have just created.
The 'id' here is the one we got back in the previous call.

```
query {
	economicResource(id:"01FAEV113XMG6KEE91GTAM52GX") {
   		onhandQuantity {
      		hasNumericalValue
    	}
	}
}
```

## Update a resource
Api call

```
mutation doResourceUpdateEvent($event:EconomicEventCreateParams!) {
  createEconomicEvent(event:$event){
    economicEvent {
      id
    }
  }       
}
```

Variables.
provider/receiver again the id of my user.
resourceInventoriedAs is the id of the resource we created in the first step
action 'raise' will add the numerical value (666) to the current value.
action 'lower' will subtract the numerical value (666) from the current value. 
If you view the resource again you will see this...

```
{
  "event": {
      "note": "update event",
      "action": "raise",
      "provider": "01F9VN1M42RTS4JDCK278VZCMT",
      "receiver": "01F9VN1M42RTS4JDCK278VZCMT",
    	"resourceInventoriedAs": "01FAEV113XMG6KEE91GTAM52GX",
      "resourceQuantity": {
        "hasUnit": "01F9X1XCVD7KPF0X21EDQPKCHY", 
        "hasNumericalValue": 666
      }
    }
}
```
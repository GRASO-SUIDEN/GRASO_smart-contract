module sui_den::real_estate_ido{
    use std::string::String;
    use sui::clock::{Clock};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};

    // Error codes 
    const EINVALID: u64 = 0;
  




public struct Contributor has store, drop, copy {
        wallet_address: address,
        amount: u64,
        timestamp: u64,
    }

    public struct PropertyIDOManager has key {
        id: UID,
        properties: vector<address>
    }

    public struct PropertyIDO has key {
        id:UID,
        title: String,
        description: String,
        property_type: String,
        image: String,
        creator: address,
        price: u64,
        current_amount: u64,
        deadline: u64,
        longitude: String,
        latitude: String,
        contributors: vector<Contributor>,
        funds: Balance<SUI>,
        is_active: bool,
        is_successful: bool
    }

    fun init(ctx: &mut TxContext) {
        let manager = PropertyIDOManager {
            id: object::new(ctx),
            properties: vector::empty<address>(),
        };
        transfer::share_object(manager);
    }

 public fun create_property(manager: &mut PropertyIDOManager, title: String, description: String, property_type: String,  image: String,  price: u64, deadline: u64, longitude: String, latitude: String, ctx: &mut TxContext){
        let sender = tx_context::sender(ctx);

        let property = PropertyIDO{
            id: object::new(ctx),
            title,
            description,
            property_type,
            image,
            creator: sender,
            price,
            current_amount: 0,
            deadline,
            longitude,
            latitude,
            contributors: vector::empty<Contributor>(),
            funds: balance::zero(),
            is_active: true,
            is_successful: false
        };

        let property_id = object::id_address(&property);
        vector::push_back(&mut manager.properties, property_id);

        transfer::share_object(property);


    }

        public fun contribute(property: &mut PropertyIDO,   payment: Coin<SUI>,
        clock: &Clock, ctx: &mut TxContext ){
        
        let sender = tx_context::sender(ctx);
        let amount = coin::value(&payment);
        
        assert!(property.is_active, EINVALID);
        let contributor = Contributor {
            wallet_address: sender,
            amount,
            timestamp: clock.timestamp_ms()
        };

        vector::push_back(&mut property.contributors, contributor);


        let payment_balance = coin::into_balance(payment);
        property.current_amount = property.current_amount + amount;
        balance::join(&mut property.funds, payment_balance);
        }

        
        public fun withdraw (property: &mut PropertyIDO, clock: &Clock, ctx: &mut TxContext) {
            assert!(clock.timestamp_ms() > property.deadline, EINVALID);
            assert!(property.is_active, EINVALID);

            property.is_active = false;

            let available_funds = balance::value(&property.funds);

            if (available_funds > 0 ) {
                let withdraw_coin = coin::from_balance(balance::split(&mut property.funds, available_funds), ctx);

                transfer::public_transfer(withdraw_coin, property.creator)
            }

         }

        public fun finalize_property_campaign(
        property: &mut PropertyIDO,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(clock.timestamp_ms() > property.deadline, EINVALID);
        assert!(property.is_active, EINVALID);

        property.is_active = false;
        property.is_successful = property.current_amount >= property.price;

        if (property.is_successful) {
            // If successful, transfer funds to creator
            let funds_to_transfer = balance::value(&property.funds);
            let creator_coin = coin::from_balance(balance::split(&mut property.funds, funds_to_transfer), ctx);
            transfer::public_transfer(creator_coin, property.creator);
        }
    }

      public fun get_property_info(property: &PropertyIDO): (
        String,    // name
        String,    // description
        String,  //Image
        String, //Category
        String, //longitude
        String, //latitude
        address,   // creator
        u64,      // target amount
        u64,      // current amount
        u64,      // deadline
        bool,     // is active
        bool      // is successful
    ) {
        (
            property.title,
            property.description,
            property.image,
            property.property_type,
            property.longitude,
            property.latitude,
            property.creator,
            property.price,
            property.current_amount,
            property.deadline,
            property.is_active,
            property.is_successful
        )
    }


    public fun get_contributors(property: &PropertyIDO): vector<Contributor> {
        property.contributors
    }

    public fun get_all_properties(manager: &PropertyIDOManager): vector<address> {
        manager.properties
    }

      public fun is_contributor(property: &PropertyIDO, addr: address): (bool, u64) {
        let mut i = 0;
        let len = vector::length(&property.contributors);
        
        while (i < len) {
            let contributor = vector::borrow(&property.contributors, i);
            if (contributor.wallet_address == addr) {
                return (true, contributor.amount)
            };
            i = i + 1;
        };
        (false, 0)
    }


}
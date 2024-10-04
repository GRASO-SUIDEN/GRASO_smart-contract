module sui_den::real_estate_ido{
    use sui::table::{Self, Table};
    use std::string::{String, utf8};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    use sui::event;
    use sui::vec_set::{Self, VecSet};
    use std::vector;

    // Error codes 
    const EInsufficientFunds: u64 = 0;
    const EIDONotActive: u64 = 1;
    const EIDOExpired: u64 = 2;
    const EAlreadySold: u64 = 3;
    const ENotAuthorized: u64 = 4;
    const EIDONotCompleted: u64 = 5;
    const ENotDeveloper: u64 = 6;
    const EFractionalNotAllowed: u64 = 7;
    const EAlreadyOwner: u64= 8;



    // Struct to hold user details 
    public struct UserProfile has key, store {
        id: UID,
        first_name: String,
        last_name: String,
        email: String,
        occupation: String,
        description: String,
        is_developer: bool,
        // Remaining details

    }

    public struct UserContactInfo has key, store {
        id: UID,
        phone_number: String,
        website: String,
    }

    // Struct to manage all user profiles 
    public struct UserProfileManager has key {
        id: UID,
        profiles: Table<address, UserProfile>,
    }

    public struct UserContactInfoManager has key {
        id: UID,
        contacts: Table<address, UserContactInfo>,
    }
   
    public struct PropertyIDO has key {
    id: UID,
    title: String,
    image: String,
    property_type: String,
    developer: address,
    balance: Balance<SUI>,
    total_value: u64,
    total_contributors: u64,
    contributions: Table<address, u64>,
    contributors: vector<address>,  
    end_time: u64,
    start_time: u64,
    is_fractional: bool,
    description: String,
    location: String,

}
    public struct IDORegistry has key {
        id: UID,
        idos: VecSet<ID>
    }
    
    public struct PropertyNFT has key, store {
        id: UID,
        name: String,
        contribution_amount: u64,
        ido_id: ID,
    }

    // Event emitted when a new profile is created
    public struct ProfileCreated has copy, drop {
        user: address,
        name: String,
    }

    public struct ContactAdded has copy, drop {
        phone_number: String,
        website: String,
    }

    public struct ICOCreated has copy, drop {
        ido_id: ID,
        name: String,
        total_value: u64,
    }

    public struct Contributed has copy, drop {
        ido_id: ID,
        contributor: address,
        amount: u64,
    }

    public struct IDOComplted has copy, drop {
        ido_id: ID,
        total_raised: u64,
        total_contributors: u64,
    }
    public struct PropertySold has copy, drop {
    ido_id: ID,
    old_owner: address,
    new_owner: address,
    sale_price: u64,
}



    // Initialize the UserProfileManager
    fun init (ctx: &mut TxContext){
        transfer::share_object(UserProfileManager { id: object::new(ctx), profiles: table::new(ctx) });
        transfer::share_object(UserContactInfoManager { id: object::new(ctx), contacts: table::new(ctx) });
        transfer::share_object(IDORegistry {id: object::new(ctx),idos: vec_set::empty(),});
    }


 

    public entry fun create_profile(
        manager: &mut UserProfileManager,
        first_name: vector<u8>,
        last_name: vector<u8>,
        email: vector<u8>,
        occupation: vector<u8>,
        description: vector<u8>,
        is_developer: bool,
        ctx: &mut TxContext
    ) {

        let sender = tx_context::sender(ctx);
        let profile = UserProfile {
            id: object::new(ctx),
            first_name: utf8(first_name),
            last_name: utf8(last_name),
            email: utf8(email),
            occupation: utf8(occupation),
            description: utf8(description),
            is_developer,
        };
        
        event::emit(ProfileCreated{
            user: sender,
            name: profile.first_name,
        });

        table::add(&mut manager.profiles, sender, profile)

        
    }

   public entry fun add_contact (
        manager: &mut UserContactInfoManager,
        phone_number: String,
        website: String,
        ctx: &mut TxContext
    ){
        let sender = tx_context::sender(ctx);
        let contact = UserContactInfo {
            id: object::new(ctx),
            phone_number,
            website,
        };

        event::emit(ContactAdded { phone_number: contact.phone_number, website: contact.website });

        table::add(&mut manager.contacts, sender, contact);
    }

    public entry fun create_ido(
        manager: &mut UserProfileManager,
        registry: &mut IDORegistry,
        title: String,
        image: String,
        property_type: String,
        total_value: u64,
        start_time: u64,
        end_time: u64,
        is_fractional: bool,
        description: String,
        location: String,
        ctx: &mut TxContext

    ){
        let sender = tx_context::sender(ctx);
        let userProfile = table::borrow(&manager.profiles, sender);
        
        assert!(userProfile.is_developer == true, ENotDeveloper);



        let ido = PropertyIDO {
            id: object::new(ctx),
            title,
            image,
            property_type,
            total_value,
            total_contributors: 0,
            contributions: table::new(ctx),
            start_time,
            end_time,
            contributors: vector::empty(),
            balance: balance::zero(),
            developer: sender,
            is_fractional,
            description,
            location,
        };

        let ido_id = object::id(&ido);


        event::emit(ICOCreated {
            ido_id: object::id(&ido),
            name: ido.title,
            total_value,
        });

        vec_set::insert(&mut registry.idos, ido_id);
        transfer::share_object(ido);
    }

    public entry fun contribute(ido: &mut PropertyIDO, payment: &mut Coin<SUI>, mut amount: u64, clock: &Clock, ctx: &mut TxContext){
        assert!(ido.is_fractional, EFractionalNotAllowed);
        let sender = tx_context::sender(ctx);
        let current_time = clock::timestamp_ms(clock);

        assert!(current_time >= ido.start_time, EIDONotActive);
        assert!(current_time <= ido.end_time, EIDOExpired);
        assert!(coin::value(payment) >= amount, EInsufficientFunds);

        let paid = coin::split(payment, amount, ctx);
        balance::join(&mut ido.balance, coin::into_balance(paid));

        if(!table::contains(&ido.contributions, sender)) {
            ido.total_contributors = ido.total_contributors + 1;
        };

        

        if (table::contains(&ido.contributions, sender)) {
            let existing = table::remove(&mut ido.contributions, sender);

            amount = amount + existing;
        };
        table::add(&mut ido.contributions, sender, amount);

        event::emit(Contributed {
            ido_id: object::id(ido),
            contributor: sender,
            amount,
        });

         // Create and transfer NFT
        let nft = PropertyNFT {
            id: object::new(ctx),
            name: ido.title,
            contribution_amount: amount,
            ido_id: object::id(ido),
        };
        transfer::transfer(nft, sender);

        

        
    }

    public entry fun buy_non_fractional(ido: &mut PropertyIDO, payment: &mut Coin<SUI>, clock: &Clock, ctx: &mut TxContext){
        assert!(!ido.is_fractional, EFractionalNotAllowed);
        assert!(ido.total_contributors == 0, EAlreadySold);

        let sender = tx_context::sender(ctx);
        let current_time = clock::timestamp_ms(clock);

        assert!(current_time >= ido.start_time, EIDONotActive);
        assert!(current_time <= ido.end_time, EIDOExpired);
        assert!(coin::value(payment) >= ido.total_value, EInsufficientFunds);

        let paid = coin::split(payment, ido.total_value, ctx);
        balance::join(&mut ido.balance, coin::into_balance(paid));

        ido.total_contributors = 1;
        table::add(&mut ido.contributions, sender, ido.total_value);

            event::emit(Contributed {
            ido_id: object::id(ido),
            contributor: sender,
            amount: ido.total_value,
        });

        // Create and transfer NFT
        let nft = PropertyNFT {
            id: object::new(ctx),
            name: ido.title,
            contribution_amount: ido.total_value,
            ido_id: object::id(ido),
        };
        transfer::transfer(nft, sender);

    }


    public entry fun complete_ico(ido: &mut PropertyIDO, ctx: &mut TxContext){
            assert!(tx_context::sender(ctx) == ido.developer, ENotAuthorized);
            let total_raised = balance::value(&ido.balance);
            let funds = coin::from_balance(balance::withdraw_all(&mut ido.balance), ctx);

            transfer::public_transfer(funds, ido.developer);

            event::emit(IDOComplted {
                ido_id: object::id(ido),
                total_raised,
                total_contributors: ido.total_contributors,
            });
    }

public entry fun buy_property(ido: &mut PropertyIDO, payment: &mut Coin<SUI>, clock: &Clock, ctx: &mut TxContext) {
    let buyer = tx_context::sender(ctx);
    let current_time = clock::timestamp_ms(clock);

    assert!(current_time > ido.end_time, EIDONotCompleted);
    assert!(buyer != ido.developer, EAlreadyOwner);

    let total_raised = balance::value(&ido.balance);
    let new_value = coin::value(payment);

    assert!(new_value > total_raised, EInsufficientFunds);

    let paid = coin::split(payment, new_value, ctx);
    balance::join(&mut ido.balance, coin::into_balance(paid));

    // Distribute returns to contributors
    let mut i = 0;
    let len = vector::length(&ido.contributors);
    while (i < len) {
        let contributor = *vector::borrow(&ido.contributors, i);
        if (contributor != buyer) {
            let return_amount = calculate_returns(ido, new_value, contributor);
            let return_coin = coin::take(&mut ido.balance, return_amount, ctx);
            transfer::public_transfer(return_coin, contributor);
            table::remove(&mut ido.contributions, contributor);
        };
        i = i + 1;
    };

    // Transfer remaining balance to the original developer
  
    let balance_value = balance::value(&ido.balance);

// Then, perform the mutable borrow
    let developer_return = coin::take(&mut ido.balance, balance_value, ctx);

// Continue with the rest of your logic
    let old_developer = ido.developer;
    transfer::public_transfer(developer_return, old_developer);


    // Transfer ownership and reset ICO state
    ido.developer = buyer;
    ido.total_value = new_value;
    ido.total_contributors = 1;

    // Clear contributions and add new buyer
    while (!vector::is_empty(&ido.contributors)) {
        let contributor = vector::pop_back(&mut ido.contributors);
        if (table::contains(&ido.contributions, contributor)) {
            table::remove(&mut ido.contributions, contributor);
        };
    };
    table::add(&mut ido.contributions, buyer, new_value);

    // Reset contributors vector
    vector::push_back(&mut ido.contributors, buyer);

    // Emit an event for the property sale
    event::emit(PropertySold {
        ido_id: object::uid_to_inner(&ido.id),
        old_owner: old_developer,
        new_owner: buyer,
        sale_price: new_value,
    });
}
    // View functions

    public fun calculate_returns(ido: &PropertyIDO, new_value: u64, investor: address): u64 {
        let contribution = get_contribution(ido, investor);

        let total_raised = balance::value(&ido.balance);
        let appreciation = new_value - ido.total_value;
        let investor_share = (contribution as u128) * ((appreciation as u128) / (total_raised as u128));

        (investor_share as u64) + contribution

    }
    public fun get_ido_info(ido: &PropertyIDO): (String, String, String, String, u64){
        (
            ido.title,
            ido.image,
            ido.location,
            ido.description,
            ido.total_value,

        )
    }

    public fun get_contribution(ido: &PropertyIDO, investor: address): u64 {
        if(table::contains(&ido.contributions, investor)) {
            *table::borrow(&ido.contributions, investor)
        } else {
            0
        }
    }

    public fun get_all_idos(registry: &IDORegistry): vector<ID> {
        vec_set::into_keys(registry.idos)
    }

}


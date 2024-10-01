module sui_den::real_estate_ico{
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
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
    const EICONotActive: u64 = 1;
    const EICOExpired: u64 = 2;
    const EAlreadySold: u64 = 3;
    const ENotAuthorized: u64 = 4;
    const EICONotCompleted: u64 = 5;
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
   
    public struct PropertyICO has key {
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
    public struct ICORegistry has key {
        id: UID,
        icos: VecSet<ID>
    }
    
    public struct PropertyNFT has key, store {
        id: UID,
        name: String,
        contribution_amount: u64,
        ico_id: ID,
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
        ico_id: ID,
        name: String,
        total_value: u64,
    }

    public struct Contributed has copy, drop {
        ico_id: ID,
        contributor: address,
        amount: u64,
    }

    public struct ICOComplted has copy, drop {
        ico_id: ID,
        total_raised: u64,
        total_contributors: u64,
    }
    public struct PropertySold has copy, drop {
    ico_id: ID,
    old_owner: address,
    new_owner: address,
    sale_price: u64,
}



    // Initialize the UserProfileManager
    fun init (ctx: &mut TxContext){
        transfer::share_object(UserProfileManager { id: object::new(ctx), profiles: table::new(ctx) });
        transfer::share_object(UserContactInfoManager { id: object::new(ctx), contacts: table::new(ctx) });
        transfer::share_object(ICORegistry {id: object::new(ctx),icos: vec_set::empty(),});
    }


 

    public entry fun create_profile(
        manager: &mut UserProfileManager,
        first_name: String,
        last_name: String,
        email: String,
        occupation: String,
        description: String,
        is_developer: bool,
        ctx: &mut TxContext
    ) {

        let sender = tx_context::sender(ctx);
        let profile = UserProfile {
            id: object::new(ctx),
            first_name,
            last_name,
            email,
            occupation,
            description,
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

    public entry fun create_ico(
        manager: &mut UserProfileManager,
        registry: &mut ICORegistry,
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



        let ico = PropertyICO {
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

        let ico_id = object::id(&ico);


        event::emit(ICOCreated {
            ico_id: object::id(&ico),
            name: ico.title,
            total_value,
        });

        vec_set::insert(&mut registry.icos, ico_id);
        transfer::share_object(ico);
    }

    public entry fun contribute(ico: &mut PropertyICO, payment: &mut Coin<SUI>, mut amount: u64, clock: &Clock, ctx: &mut TxContext){
        assert!(ico.is_fractional, EFractionalNotAllowed);
        let sender = tx_context::sender(ctx);
        let current_time = clock::timestamp_ms(clock);

        assert!(current_time >= ico.start_time, EICONotActive);
        assert!(current_time <= ico.end_time, EICOExpired);
        assert!(coin::value(payment) >= amount, EInsufficientFunds);

        let paid = coin::split(payment, amount, ctx);
        balance::join(&mut ico.balance, coin::into_balance(paid));

        if(!table::contains(&ico.contributions, sender)) {
            ico.total_contributors = ico.total_contributors + 1;
        };

        

        if (table::contains(&ico.contributions, sender)) {
            let existing = table::remove(&mut ico.contributions, sender);

            amount = amount + existing;
        };
        table::add(&mut ico.contributions, sender, amount);

        event::emit(Contributed {
            ico_id: object::id(ico),
            contributor: sender,
            amount,
        });

         // Create and transfer NFT
        let nft = PropertyNFT {
            id: object::new(ctx),
            name: ico.title,
            contribution_amount: amount,
            ico_id: object::id(ico),
        };
        transfer::transfer(nft, sender);

        

        
    }

    public entry fun buy_non_fractional(ico: &mut PropertyICO, payment: &mut Coin<SUI>, clock: &Clock, ctx: &mut TxContext){
        assert!(!ico.is_fractional, EFractionalNotAllowed);
        assert!(ico.total_contributors == 0, EAlreadySold);

        let sender = tx_context::sender(ctx);
        let current_time = clock::timestamp_ms(clock);

        assert!(current_time >= ico.start_time, EICONotActive);
        assert!(current_time <= ico.end_time, EICOExpired);
        assert!(coin::value(payment) >= ico.total_value, EInsufficientFunds);

        let paid = coin::split(payment, ico.total_value, ctx);
        balance::join(&mut ico.balance, coin::into_balance(paid));

        ico.total_contributors = 1;
        table::add(&mut ico.contributions, sender, ico.total_value);

             event::emit(Contributed {
            ico_id: object::id(ico),
            contributor: sender,
            amount: ico.total_value,
        });

        // Create and transfer NFT
        let nft = PropertyNFT {
            id: object::new(ctx),
            name: ico.title,
            contribution_amount: ico.total_value,
            ico_id: object::id(ico),
        };
        transfer::transfer(nft, sender);

    }


    public entry fun complete_ico(ico: &mut PropertyICO, ctx: &mut TxContext){
            assert!(tx_context::sender(ctx) == ico.developer, ENotAuthorized);
            let total_raised = balance::value(&ico.balance);
            let funds = coin::from_balance(balance::withdraw_all(&mut ico.balance), ctx);

            transfer::public_transfer(funds, ico.developer);

            event::emit(ICOComplted {
                ico_id: object::id(ico),
                total_raised,
                total_contributors: ico.total_contributors,
            });
    }

public entry fun buy_property(ico: &mut PropertyICO, payment: &mut Coin<SUI>, clock: &Clock, ctx: &mut TxContext) {
    let buyer = tx_context::sender(ctx);
    let current_time = clock::timestamp_ms(clock);

    assert!(current_time > ico.end_time, EICONotCompleted);
    assert!(buyer != ico.developer, EAlreadyOwner);

    let total_raised = balance::value(&ico.balance);
    let new_value = coin::value(payment);

    assert!(new_value > total_raised, EInsufficientFunds);

    let paid = coin::split(payment, new_value, ctx);
    balance::join(&mut ico.balance, coin::into_balance(paid));

    // Distribute returns to contributors
    let mut i = 0;
    let len = vector::length(&ico.contributors);
    while (i < len) {
        let contributor = *vector::borrow(&ico.contributors, i);
        if (contributor != buyer) {
            let contribution = *table::borrow(&ico.contributions, contributor);
            let return_amount = calculate_returns(ico, new_value, contributor);
            let return_coin = coin::take(&mut ico.balance, return_amount, ctx);
            transfer::public_transfer(return_coin, contributor);
            table::remove(&mut ico.contributions, contributor);
        };
        i = i + 1;
    };

    // Transfer remaining balance to the original developer
  
    let balance_value = balance::value(&ico.balance);

// Then, perform the mutable borrow
    let developer_return = coin::take(&mut ico.balance, balance_value, ctx);

// Continue with the rest of your logic
    let old_developer = ico.developer;
    transfer::public_transfer(developer_return, old_developer);


    // Transfer ownership and reset ICO state
    ico.developer = buyer;
    ico.total_value = new_value;
    ico.total_contributors = 1;

    // Clear contributions and add new buyer
    while (!vector::is_empty(&ico.contributors)) {
        let contributor = vector::pop_back(&mut ico.contributors);
        if (table::contains(&ico.contributions, contributor)) {
            table::remove(&mut ico.contributions, contributor);
        };
    };
    table::add(&mut ico.contributions, buyer, new_value);

    // Reset contributors vector
    vector::push_back(&mut ico.contributors, buyer);

    // Emit an event for the property sale
    event::emit(PropertySold {
        ico_id: object::uid_to_inner(&ico.id),
        old_owner: old_developer,
        new_owner: buyer,
        sale_price: new_value,
    });
}
    // View functions

    public fun calculate_returns(ico: &PropertyICO, new_value: u64, investor: address): u64 {
        let contribution = get_contribution(ico, investor);

        let total_raised = balance::value(&ico.balance);
        let appreciation = new_value - ico.total_value;
        let investor_share = (contribution as u128) * ((appreciation as u128) / (total_raised as u128));

        (investor_share as u64) + contribution

    }
    public fun get_ico_info(ico: &PropertyICO): (String, String, String, String, u64){
        (
            ico.title,
            ico.image,
            ico.location,
            ico.description,
            ico.total_value,

        )
    }

    public fun get_contribution(ico: &PropertyICO, investor: address): u64 {
        if(table::contains(&ico.contributions, investor)) {
            *table::borrow(&ico.contributions, investor)
        } else {
            0
        }
    }

    public fun get_all_icos(registry: &ICORegistry): vector<ID> {
        vec_set::into_keys(registry.icos)
    }

}


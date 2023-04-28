module suipstakes::lottery {
    // use std::string;
    // use std::ascii;
    use std::option::{Self, Option};
    use std::vector;
    use sui::table::{Self, Table};
    // use sui::url::{Self, Url};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    // use sui::event;

    struct Lottery has key, store {
        id: UID,
        game_count: u64, 
        active_game_ids: vector<UID>,
        games: Table<u64, UID>
    }

    struct Game has key, store {
        id: UID, 
        end_round: u64, 
        ticket_supply: u64, 
        bank: Coin<0x2::sui::SUI>,
        status: u64, 
        winner: Option<u64>
    }

    struct Ticket has key, store {
        id: UID, 
        game_id: u64,
        ticket_id: u64
    }
    
    struct AdminCap has key, store {
        id: UID
    }

    fun init(ctx: &mut TxContext) {
        transfer::public_transfer<AdminCap>(
            AdminCap {
                id: object::new(ctx)
            },
            tx_context::sender(ctx)
        );
        transfer::public_transfer<Lottery>(
            Lottery {
                id: object::new(ctx),
                game_count: 0, 
                active_game_ids: vector<UID>[],
                games: table::new<u64, UID>(ctx)
            },
            tx_context::sender(ctx)
        );
    }

    fun add_admins(admins: vector<address>, ctx: &mut TxContext) {
        let i: u64 = 0;
        while(i < vector::length<address>(&admins)){
            transfer::transfer<AdminCap>(
                AdminCap {
                    id: object::new(ctx)
                },
                *vector::borrow<address>(&admins, i)
            );
            i = i + 1;
        };
    }

    // //Need to add check that only the contract owner can run this function.
    // public entry fun issue(
    //     treasury_cap: &mut TreasuryCap<LOTTERY>,
    //     amount: u64,
    //     recipient: address,
    //     ctx: &mut TxContext
    // ){
    //     coin::mint_and_transfer(treasury_cap, amount, recipient, ctx)
    // }

    
}
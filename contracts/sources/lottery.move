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
    use sui::object::{Self, ID, UID};
    use sui::balance::{Self, Supply, Balance};
    use sui::sui::SUI;
    // use sui::event;

    struct Lottery has key, store {
        id: UID,
        game_count: u64, 
        active_game_ids: vector<u64>,
        games: vector<Game>
    }

    struct Game has store {
        id: u64, 
        end_round: u64, 
        ticket_supply: u64, 
        sui_balance: Balance<SUI>,
        status: u64, 
        winner: Option<u64>
    }

    struct Ticket has key, store {
        id: UID, 
        game_id: u64,
        ticket_id: u64
    }
    
    struct AdminCap has key {
        id: UID
    }

    const STATUS_GAME_ACTIVE: u64 = 1;

    fun init(ctx: &mut TxContext) {
        transfer::transfer<AdminCap>(
            AdminCap {
                id: object::new(ctx)
            },
            tx_context::sender(ctx)
        );
        transfer::transfer<Lottery>(
            Lottery {
                id: object::new(ctx),
                game_count: 0, 
                active_game_ids: vector<u64>[],
                games: vector<Game>[]
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

    public entry fun create_game(_admin_cap: &mut AdminCap, lottery: &mut Lottery, round: u64) {
        let new_game = Game {
            id: lottery.game_count + 1,
            end_round: round, 
            ticket_supply: 0, 
            sui_balance: balance::zero<SUI>(),
            status: STATUS_GAME_ACTIVE,
            winner: option::none<u64>()
        };

        lottery.game_count = lottery.game_count + 1;

        vector::push_back<u64>(&mut lottery.active_game_ids, lottery.game_count);

        vector::push_back<Game>(&mut lottery.games, new_game);
    }
    
}
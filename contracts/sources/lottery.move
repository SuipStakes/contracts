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

    const GAME_STATUS_ACTIVE: u64 = 1;

    const TICKET_PRICE_SUI: u64 = 100;

    fun init(ctx: &mut TxContext) {
        transfer::transfer<AdminCap>(
            AdminCap {
                id: object::new(ctx)
            },
            tx_context::sender(ctx)
        );
        transfer::share_object<Lottery>(
            Lottery {
                id: object::new(ctx),
                game_count: 0, 
                active_game_ids: vector<u64>[],
                games: vector<Game>[]
            }
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
            id: lottery.game_count,
            end_round: round, 
            ticket_supply: 0, 
            sui_balance: balance::zero<SUI>(),
            status: GAME_STATUS_ACTIVE,
            winner: option::none<u64>()
        };

        vector::push_back<u64>(&mut lottery.active_game_ids, lottery.game_count);

        vector::push_back<Game>(&mut lottery.games, new_game);

        lottery.game_count = lottery.game_count + 1;
    }

    public entry fun purchase_tickets(lottery: &mut Lottery, game_id: u64, ticket_amount: u64, sui: Coin<SUI>, ctx:  &mut TxContext) {
        
        let game_mut_ref = vector::borrow_mut<Game>(&mut lottery.games, game_id);
        
        // Make sure game is active
        let game_status = game_mut_ref.status;
        assert!(game_status == GAME_STATUS_ACTIVE, 0);

        // make sure user has balance
        let sui_amount = coin::value(&sui);
        let purchase_amount = TICKET_PRICE_SUI * ticket_amount;
        assert!(sui_amount >= purchase_amount, 0);

        let sui_purchase_coin = coin::split<SUI>(&mut sui, purchase_amount, ctx);
        
        let game_balance_mut_ref = &mut game_mut_ref.sui_balance;

        coin::put<SUI>(game_balance_mut_ref, sui_purchase_coin);

        while (ticket_amount > 0) {
            transfer::transfer<Ticket>(
                Ticket {
                    id: object::new(ctx),
                    game_id,
                    ticket_id: game_mut_ref.ticket_supply
                },
                tx_context::sender(ctx)
            );
            game_mut_ref.ticket_supply = game_mut_ref.ticket_supply + 1;
            ticket_amount = ticket_amount - 1;
        };

        transfer::public_transfer<Coin<SUI>>(sui, tx_context::sender(ctx))

    }
    
}
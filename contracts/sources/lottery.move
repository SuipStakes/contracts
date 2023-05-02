module suipstakes::lottery {
    // use std::string;
    // use std::ascii;
    use std::option::{Self, Option};
    use std::vector;
    // use sui::url::{Self, Url};
    use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use suipstakes::drand_lib::{derive_randomness, verify_drand_signature, safe_selection};
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

    const EGameNotActive: u64 = 1;
    const EGameAlreadyCompleted: u64 = 2;
    const EInvalidTicket: u64 = 3;

    const GAME_STATUS_ACTIVE: u64 = 1;
    const GAME_STATUS_CLOSED: u64 = 2;
    const GAME_STATUS_COMPLETED: u64 = 3;

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

    //======================================= Admin functions ======================================

    public entry fun add_admins(_admin_cap: &mut AdminCap, admins: vector<address>, ctx: &mut TxContext) {
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

    //This doesn't work either, my assert is failing.

    // public entry fun add_admin(_admin_cap: &mut AdminCap, new_admin: address, ctx: &mut TxContext) {
    //     transfer::transfer<AdminCap>(
    //         AdminCap {
    //             id: object::new(ctx)
    //         },
    //         new_admin
    //     );
    // }

    public entry fun create_game(_admin_cap: &mut AdminCap, lottery: &mut Lottery, end_round: u64) {
        let new_game = Game {
            id: lottery.game_count,
            end_round: end_round, 
            ticket_supply: 0, 
            sui_balance: balance::zero<SUI>(),
            status: GAME_STATUS_ACTIVE,
            winner: option::none<u64>()
        };

        vector::push_back<u64>(&mut lottery.active_game_ids, lottery.game_count);

        vector::push_back<Game>(&mut lottery.games, new_game);

        lottery.game_count = lottery.game_count + 1;
    }

    //======================================= User functions =======================================

    public entry fun close_game(lottery: &mut Lottery, game_id: u64, drand_sig: vector<u8>, drand_prev_sig: vector<u8>) {
        
        let game_mut_ref = fetch_game_mut_ref(lottery, game_id);

        assert!(game_mut_ref.status == GAME_STATUS_ACTIVE, EGameNotActive);
        verify_drand_signature(drand_sig, drand_prev_sig, closing_round(game_mut_ref.end_round));
        game_mut_ref.status = GAME_STATUS_CLOSED;
    }

    public entry fun complete_game(lottery: &mut Lottery, game_id: u64, drand_sig: vector<u8>, drand_prev_sig: vector<u8>) {
        let game_mut_ref = fetch_game_mut_ref(lottery, game_id);

        assert!(game_mut_ref.status != GAME_STATUS_COMPLETED, EGameAlreadyCompleted);
        verify_drand_signature(drand_sig, drand_prev_sig, game_mut_ref.end_round);
        game_mut_ref.status = GAME_STATUS_COMPLETED;
        // The randomness is derived from drand_sig by passing it through sha2_256 to make it uniform.
        let digest = derive_randomness(drand_sig);
        game_mut_ref.winner = option::some(safe_selection(game_mut_ref.ticket_supply, &digest));
    }

    public fun purchase_tickets(lottery: &mut Lottery, game_id: u64, ticket_amount: u64, sui: Coin<SUI>, ctx: &mut TxContext) {
        
        let game_mut_ref = fetch_game_mut_ref(lottery, game_id);
        
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

    public entry fun redeem(ticket: &Ticket, game_id: u64, lottery: &mut Lottery, winner_sui_coin: Coin<SUI>, ctx: &mut TxContext) {
        assert!(game_id == ticket.game_id, EInvalidTicket);

        let game_mut_ref = fetch_game_mut_ref(lottery, game_id);

        assert!(option::contains(&game_mut_ref.winner, &ticket.ticket_id), EInvalidTicket);

        
        let game_balance_mut_ref = &mut game_mut_ref.sui_balance;
        let game_balance_amount = balance::value<SUI>(game_balance_mut_ref);
        let game_winning_coin = coin::take<SUI>(game_balance_mut_ref, game_balance_amount, ctx);
        coin::join<SUI>(&mut winner_sui_coin, game_winning_coin);

        transfer::public_transfer(winner_sui_coin, tx_context::sender(ctx));

        // let winner = GameWinner {
        //     id: object::new(ctx),
        //     game_id: ticket.game_id,
        // };
        // transfer::public_transfer(winner, tx_context::sender(ctx));
    }

    //====================================== Helper functions ======================================

    fun fetch_game_mut_ref(lottery: &mut Lottery, game_id: u64): &mut Game {
        vector::borrow_mut<Game>(&mut lottery.games, game_id)
    }

    fun closing_round(round: u64): u64 {
        round - 2
    }
    
    //====================================== Lottery Helper functions ======================================
    public fun get_game_count(lottery: &Lottery): u64 {
        lottery.game_count
    }

    public fun get_active_game_ids(lottery: &Lottery): vector<u64> {
        lottery.active_game_ids
    }

    public fun get_games(lottery: &Lottery): &vector<Game> {
        &lottery.games
    }

    //====================================== Game Helper functions ======================================
    public fun get_game_end_round(game: &Game): u64 {
        game.end_round
    }

    public fun get_game_ticket_supply(game: &Game): u64 {
        game.ticket_supply
    }

    public fun get_game_status(game: &Game): u64 {
        game.status
    }

    public fun get_game_winner(game: &Game): Option<u64> {
        game.winner
    }


    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx)
    }
}
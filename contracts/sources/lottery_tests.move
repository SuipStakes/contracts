#[test_only]
module suipstakes::lottery_tests {
    
    use suipstakes::lottery::{Self, AdminCap, Lottery, Game};
    use sui::test_scenario::{Self, next_tx, ctx, take_from_sender, return_to_sender, take_shared, return_shared, has_most_recent_for_address};
    use std::vector;
    use std::option::{Self};


    #[test]
    public fun add_admins() {
        let owner = @0xA;
        let new_admin = @0xB;

        // Begins a multi transaction scenario with owner as the sender
        let scenario = test_scenario::begin(owner);
        {
            lottery::test_init(ctx(&mut scenario));
        };

        // Add Admin
        next_tx(&mut scenario, owner);
        {   
            //new_admin does NOT have Admin Cap
            assert!(!has_most_recent_for_address<AdminCap>(new_admin), 0);

            let adminCap = take_from_sender<AdminCap>(&mut scenario);
            lottery::add_admins(&mut adminCap, vector<address>[new_admin], ctx(&mut scenario));

            //new_admin HAS Admin Cap
            assert!(has_most_recent_for_address<AdminCap>(new_admin), 0);

            return_to_sender<AdminCap>(&mut scenario, adminCap);
        };

        test_scenario::end(scenario);
    }

    // #[test]
    // public fun add_admin() {
    //     let owner = @0xA;
    //     let new_admin = @0xB;

    //     // Begins a multi transaction scenario with owner as the sender
    //     let scenario = test_scenario::begin(owner);
    //     {
    //         lottery::test_init(ctx(&mut scenario));
    //         assert!(has_most_recent_for_address<AdminCap>(owner), 0);
    //     };

    //     // Add Admin
    //     next_tx(&mut scenario, owner);
    //     {   
    //         //new_admin does NOT have Admin Cap
    //         assert!(!has_most_recent_for_address<AdminCap>(new_admin), 0);

    //         let adminCap = take_from_sender<AdminCap>(&mut scenario);
    //         lottery::add_admin(&mut adminCap, new_admin, ctx(&mut scenario));

    //         //new_admin HAS Admin Cap
    //         assert!(has_most_recent_for_address<AdminCap>(new_admin), 0);

    //         return_to_sender<AdminCap>(&mut scenario, adminCap);
    //     };

    //     test_scenario::end(scenario);
    // }

    #[test]
    public fun create_game() {
        let owner = @0xA;

        // Begins a multi transaction scenario with owner as the sender
        let scenario = test_scenario::begin(owner);
        {
            lottery::test_init(ctx(&mut scenario));
        };

        // Create Game
        next_tx(&mut scenario, owner);
        {   
            let adminCap = take_from_sender<AdminCap>(&mut scenario);
            let lottery = take_shared<Lottery>(&mut scenario);

            let end_round = 100;

            lottery::create_game(&mut adminCap, &mut lottery, end_round);

            //Game Count == 1
            let count = lottery::get_game_count(&lottery);
            assert!(count == 1, 0);

            //Active Ids Length == 1
            let active_ids = lottery::get_active_game_ids(&lottery);
            assert!(vector::length<u64>(&active_ids) == 1, 0);

            let games = lottery::get_games(&lottery);
            assert!(vector::length<Game>(games) == count, 0);
            
            let game = vector::borrow<Game>(games, count-1);
            //Unfortunetly we can't do this
            // assert!(game.end_round == end_round, 1);

            assert!(lottery::get_game_end_round(game) == end_round, 0);
            assert!(lottery::get_game_ticket_supply(game) == 0, 0);
            assert!(lottery::get_game_status(game) == 1, 0);
            assert!(lottery::get_game_winner(game) == option::none<u64>(), 0);

            return_to_sender<AdminCap>(&mut scenario, adminCap);
            return_shared<Lottery>(lottery);
        };

        test_scenario::end(scenario);
    }
}
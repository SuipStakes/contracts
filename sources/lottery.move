module suipstakes::lottery {
    // use std::string;
    // use std::ascii;
    use std::option::{Self};
    // use sui::url::{Self, Url};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    // use sui::object::{Self, UID};
    // use sui::event;

    struct LOTTERY has drop {}

    fun init(witness: LOTTERY, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency<LOTTERY>(witness, 6, b"SUIP", b"SuipStakes", b"The SuipStakes lottery entry token!", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        transfer::share_object(treasury, tx_context::sender(ctx));
    }

    //Need to add check that only the contract owner can run this function.
    public entry fun issue(
        treasury_cap: &mut TreasuryCap<LOTTERY>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ){
        coin::mint_and_transfer(treasury_cap, amount, recipient, ctx)
    }

    public entry fun enter_with_lotto_token(
        lotto_coin: Coin<LOTTERY>,
        ctx: &mut TxContext
    ){
        let coin_balance = coin::into_balance(lotto_coin);
        coin::take(&mut coin_balance, 1, ctx)
    }

    
}
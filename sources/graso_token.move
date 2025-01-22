
module sui_den::graso_token{

use sui::url::{Self};
use sui::coin::{Self, TreasuryCap};

public struct GRASO_TOKEN has drop {}

fun init(witness: GRASO_TOKEN, ctx: &mut TxContext) {
		let (treasury, metadata) = coin::create_currency(
				witness,
				6,
				b"GRS",
				b"Graso",
				b"Token for investing",
				option::some(url::new_unsafe_from_bytes(b"https://gateway.pinata.cloud/ipfs/bafkreif5h7ct7wy57qdejrt6skrvrkznngtz743rdswvfumvhnblwzmevm")),
				ctx,
		);
		transfer::public_freeze_object(metadata);
		transfer::public_share_object(treasury);
}

public fun mint(
		treasury_cap: &mut TreasuryCap<GRASO_TOKEN>,
		amount: u64,
		recipient: address,
		ctx: &mut TxContext,
) {
		let coin = coin::mint(treasury_cap, amount, ctx);
		transfer::public_transfer(coin, recipient)
}


}

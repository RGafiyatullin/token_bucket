-module (token_bucket_pure_test).
-include_lib("eunit/include/eunit.hrl").

t001_test() ->
	B0 = token_bucket_pure:new( 3, {2, 10} ),

	?assert( 3 == token_bucket_pure:bucket_size( B0 ) ),
	?assert( 3 == token_bucket_pure:tokens_available( B0 ) ),
	?assert( {2, 10} == token_bucket_pure:replenish_rate( B0 ) ),

	{ok, B1} = token_bucket_pure:consume( 3, B0 ),

	?assert( {deficite, 1} == token_bucket_pure:consume( 1, B1 ) ),
	?assert( 0 == token_bucket_pure:tokens_available( B1 ) ),
	?assert( 10 == token_bucket_pure:cooldown_advice( 1, B1 ) ),

	B2 = token_bucket_pure:tick( {rel, 12}, B1 ),
	?assert( 2 == token_bucket_pure:tokens_available( B2 ) ),
	B3 = token_bucket_pure:tick( {rel, 10}, B2 ),
	?assert( 3 == token_bucket_pure:tokens_available( B3 ) ),
	?assert( 10 == token_bucket_pure:cooldown_advice( 1, B3 ) ),
	?assert( 10 == token_bucket_pure:cooldown_advice( 2, B3 ) ),
	?assert( 20 == token_bucket_pure:cooldown_advice( 3, B3 ) ),
	ok.







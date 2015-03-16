-module (token_bucket_pure).
-export ([
		new/2,
		bucket_size/1,
		replenish_rate/1,
		tokens_available/1
	]).
-export([
		tick/2,
		consume/2,
		cooldown_advice/2
	]).

-define(s, ?MODULE).

-record(?s, {
		last_tick = 1 :: pos_integer(),
		ticks_proficite = 0 :: non_neg_integer(),
		rate_n :: pos_integer(),
		rate_d :: pos_integer(),
		bucket_size :: pos_integer(),
		tokens_available :: non_neg_integer()
	}).

-type bucket() :: #?s{}.
-type tick_notification() :: {abs, pos_integer()} | {rel, non_neg_integer()}.
-type replenish_rate() :: {Tokens :: pos_integer(), PerTicks :: pos_integer()}.


-spec new( BucketSize :: pos_integer(), ReplenishRate :: replenish_rate() ) -> bucket().
-spec tick( Ticks :: tick_notification(), bucket() ) -> bucket().
-spec consume( TokensToConsume :: non_neg_integer(), bucket() ) -> {ok, bucket()} | {deficite, TokensDeficite :: pos_integer()}.
-spec cooldown_advice( TokensDeficite :: non_neg_integer(), bucket() ) -> TicksToWait :: non_neg_integer().

-spec bucket_size( bucket() ) -> pos_integer().
-spec replenish_rate( bucket() ) -> replenish_rate().
-spec tokens_available( bucket() ) -> non_neg_integer().

new( BucketSize, ReplenishRate ) ->
	ok = validate( bucket_size, BucketSize ),
	ok = validate( replenish_rate, ReplenishRate ),
	{RateN, RateD} = ReplenishRate,
	#?s{
			rate_n = RateN,
			rate_d = RateD,
			bucket_size = BucketSize,
			tokens_available = BucketSize
		}.

bucket_size( #?s{ bucket_size = BS } ) -> BS.
replenish_rate( #?s{ rate_n = N, rate_d = D } ) -> {N, D}.
tokens_available( #?s{ tokens_available = A } ) -> A.

tick( Ticks, Bucket0 = #?s{
					last_tick = LastTick0, ticks_proficite = TicksProficite0,
					rate_n = RateN, rate_d = RateD,
					bucket_size = BucketSize, tokens_available = Available0
} ) ->
	ok = validate( ticks, Ticks ),
	{TicksPassed, LastTick1} = update_last_tick( Ticks, TicksProficite0, LastTick0 ),
	{TicksProficite1, TokensAdded} = calculate_replenish( TicksPassed, RateN, RateD ),
	Available1 = Available0 + TokensAdded,
	case Available1 > BucketSize of
		false ->
			Bucket0 #?s{
					last_tick = LastTick1,
					ticks_proficite = TicksProficite1,
					tokens_available = Available1
				};
		true ->
			Bucket0 #?s{
					last_tick = LastTick1,
					ticks_proficite = 0,
					tokens_available = BucketSize
				}
	end.

consume( TokensToConsume, Bucket0 = #?s{ tokens_available = Available, bucket_size = BucketSize } ) ->
	ok = validate( tokens_to_consume, TokensToConsume ),
	case TokensToConsume > BucketSize of
		false ->
			case TokensToConsume > Available of
				true -> {deficite, TokensToConsume - Available};
				false -> {ok, Bucket0 #?s{ tokens_available = Available - TokensToConsume }}
			end;

		true ->
			error({badarg, tokens_to_consume_larger_than_bucket_size})
	end.

cooldown_advice( TokensDeficite, #?s{ rate_n = RateN, rate_d = RateD } ) ->
	ok = validate( tokens_deficite, TokensDeficite ),
	ReplenishIntervals = TokensDeficite div RateN,
	TokensToAddRemaining = TokensDeficite rem RateN,
	case TokensToAddRemaining of
		0 -> ReplenishIntervals * RateD;
		_ -> ( ReplenishIntervals + 1 ) * RateD
	end.



%%% Internal %%%

update_last_tick( {rel, T}, Proficite, Last0 ) ->
	Last1 = Last0 - Proficite,
	{T + Proficite, Last1 + T};
update_last_tick( {abs, Next}, Proficite, Last0 ) ->
	Last1 = Last0 - Proficite,
	Passed = Next - Last1 + Proficite,
	case Passed of
		LtZero when LtZero < 0 -> error({badarg, abs_ticks, Next, Last1});
		GtEZero -> { GtEZero, Next }
	end.

calculate_replenish( 0, _, _ ) -> {0, 0};
calculate_replenish( T, N, D ) ->
	Proficite = T rem D,
	ReplenishIntervalsPassed = T div D,
	TokensAdded = ReplenishIntervalsPassed * N,
	{Proficite, TokensAdded}.






validate( bucket_size, I ) when is_integer( I ) andalso I > 0 -> ok;
validate( replenish_rate, { N, D } ) when is_integer( N ) andalso is_integer( D ) andalso N > 0 andalso D > 0 -> ok;
validate( ticks, {abs, T} ) when is_integer( T ) andalso T > 0 -> ok;
validate( ticks, {rel, T} ) when is_integer( T ) andalso T >= 0 -> ok;
validate( tokens_to_consume, T ) when is_integer( T ) andalso T >= 0 -> ok;
validate( tokens_deficite, D ) when is_integer( D ) andalso D > 0 -> ok;

validate( Type, InvalidValue ) -> error({badarg, Type, InvalidValue}).

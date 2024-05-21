### Coinbase for voter rewards

Validators can reward voters for their vote, and have full freedom to set that up however they want (as long as it works with the Election.sol interface for it, i.e., users vote via a contract the validator set up and has registered as their voter reward manager contract. ) The system is very flexible and modular. The two most basic categories of voter reward schemes is to send voter reward to the voter who elected validator, or, distribute the reward on all voters during a period. Here, a version of each of these cateogies is provided. The validator sets what share of the reward should go to the voters. There is also a third contract, where the full reward goes to the voter. Note that validators do not have to use the contracts provided here, they can use whatever they want, write their own, or use no contract (although then the block reward will go to the validator and voter rewards are not possible unless done manually. )

### Elected event

Emits events for each slot, when a validator is elected, and also includes the coinbase. Can be used to track coinbase payouts. Emits events even for slots that were not used (if a validator was offline or the slot was skipped for some other reason. ) The contract is not launched with genesis block and is optional.

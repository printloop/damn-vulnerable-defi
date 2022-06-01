![](cover.png)

**A set of challenges to hack implementations of DeFi in Ethereum.**

Featuring flash loans, price oracles, governance, NFTs, lending pools, smart contract wallets, timelocks, and more!

Created by [@tinchoabbate](https://twitter.com/tinchoabbate)

Solved by [@printloop_](https://twitter.com/printloop_)

## Play

Visit [damnvulnerabledefi.xyz](https://damnvulnerabledefi.xyz)

## Disclaimer

All Solidity code, practices and patterns in this repository are DAMN VULNERABLE and for educational purposes only.

DO NOT USE IN PRODUCTION.

## Explanations
### Unstoppable
The objective is to stop the lender from issuing flash loans. 

The Lender contract keeps track of how many DVT tokens it has available to lend via poolBalance.

The contract make the assumption that all of its DVT tokens come from a call to its depositTokens function, which it uses to update poolBalance.

Issuing flashLoan requires that this poolBalance and the contract's DVT token balance be equal. Our exploit will take advtantage of this.

Once we know that the poolBalance and DVT token balance must be equal for flashLoans to work, the exploit is fairly straightforward. All we need to do is end the smart contract some DVT (directly, not via the depositTokens function). 

This will make the contract's DVT token balance greater than poolBalance. 
```js
await this.token.approve(attacker.address, 1);
this.token.connect(attacker).transfer(this.pool.address, 1);
```

This is a good first problem to start understanding flash loans and how smart contracts interact with each other. 

### Naive receiver
### Truster
### Side entrance
### The rewarder
### Selfie
### Compromised
### Puppet
### Puppet v2
### Free rider
### Backdoor
### Climber

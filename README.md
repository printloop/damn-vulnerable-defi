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

This is a good first problem to start understanding flash loans and how smart contracts interact with each other. One simple fix would be to change the DVT balance check so that the token balance must be greater than or equal to the poolBalance.

### Naive receiver
The objective is to grief another user (contact) of a flash loan contract.

Flash loans are issued with a call to flashLoan providing the borrow address and the amount to borrow. The borrowing contact must implement receiveEther and that function must repay the loan plus a specified fee. 

flashLoan can be called by anyone and specify any borrower address. We can exploit this to force the user contract to take out a flash loan and also pay the loan fee. 
```js
await this.pool.flashLoan(this.receiver.address, 1); // The second argument here doesn't matter as long as it's less than ETHER_IN_POOL.
```

The fee is 1 eth and the user holds 10 eth so we can drain their wallet by simply calling flashLoan on them 10 times. 

The challenge specifies doing this in one transaction. We could do this by deploying our own smart contract and bundling all the flashLoan calls into a single transaction. 

One fix for this is a requirement that flashLoan can only be issued to msg.sender. 

### Truster
Another flash loan problem but this time we actually get to profit from our exploit. We're going to drain the flash loan protocol's pool. 

Flash loans work via callback. Some contract wants a flash loan and must either specify the callback function that the loaner should call or implement an expected call from the loaner. In this case, the caller gets to specify the contract call. The caller also gets to specify the address of this callback. 

Our exploit takes advantage of the fact thay any target address can be specified and any function can be called. 

```js
let ABI = ["function approve(address, uint)"];
let iface = new ethers.utils.Interface(ABI);

await this.pool.flashLoan(
  0,
  attacker.address,
  this.token.address,
  iface.encodeFunctionData("approve", [attacker.address, TOKENS_IN_POOL])
);
```
Let's go over what's happening with this call to flashLoan.
borrowAmount is 0, we don't actually need to borrow anything and this let's us bypass all the requirements of paying back the loan. 
borrower doesn't actually matter since borrowAmount is 0. It just needs to be a valid address. 
target, this is the address of the DVT token that the pool is composed of.
data, this is the function call. To exploit this contract we're making this function call "approve" and providing the attacker address plus the number of tokens in the pool.

When we make this call to flashLoan there won't actually be any loan issued. However, the pool contract will make a call to the DVT token's approve function giving the attacker address approval to transfer all the DVD tokens it holds. 

After that the attacker can call transferFrom on the DVT token contract and drain everything. 

Any time your contract uses functionCall should be seen as a huge window for exploits. Use it only as a last resort. 

It would be much safer to require the user contract to implement some function that the loaner contract can then call by name. 


### Side entrance
### The rewarder
### Selfie
### Compromised
### Puppet
### Puppet v2
### Free rider
### Backdoor
### Climber

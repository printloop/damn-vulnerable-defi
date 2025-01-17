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
The attack setup can be found in the respective test files and all the challenges that required custom smart contracts can be found in contracts/attack-contracts. 

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

The fee is 1 ETH and the user holds 10 ETH so we can drain their wallet by simply calling flashLoan on them 10 times. 

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

Another flash loan challenge. Our objective this time is to take all the ETH in the lending pool.

This is the first challenge I actually ended up deploying a smart contract for, since we needed an implementation of IFlashLoanEtherReceiver to run the exploit. 

The flash loan contract has three functions: deposit, withdraw, and flashLoan. Anyone can call any function. Presumably people would deposit ETH for some kind of reward (not relevant) and withdraw their ETH when they want it back. The ETH deposited is used for flash loans.

Since users can withdraw and deposit ETH the contract has to keep track of how much each user has deposited so it knows how much can be withdrawn. Seems reasonable. 

Calls to flashLoan have a few requirements:
1. The pool must contain enough ETH to be able to fulfill the loan.
2. The borrower must implement IFlashLoanReceiver.
3. The total amount of ETH in the contract after the loan is complement must be greater than or equal to the amount before the loan was issued.

Our exploit takes out a flash loan and immediately deposits the borrowed ETH back into loaner contract with a call to deposit. 
In the end, the pool balance is the same as before the loan, but the attacker is credited with having desposited the ETH. From here the attacker can withdraw all of the pool's ETH. 

```solidity
function execute() external payable {
  pool.deposit{value: msg.value}();
}

function attack(uint256 amount) external {
  pool.flashLoan(amount);
  pool.withdraw();
}
```

One solution is to instead of doing a balance check at the end, have the loaner contract transfer the amount from the borrower to the loaner itself. This would require the borrower to approve the amount first (which is how AAVE flash loans work). 

### The rewarder
The objective here is to steal all the rewards a pool contract is issuing to it users. 

For our exploit we wait for a rewards round to start and then take out a flash loan equal to the size of the whole pool. Then we deposit it into the reward pool, which triggers a reward distribution. Since our borrower holds all of the tokens it gets nearly all the rewards. 

Once the rewards are distributed we can withdraw our borrowed tokens and return them. 

```solidity
function receiveFlashLoan(uint256 amount) external {
  token.approve(address(rewardPool), amount);
  rewardPool.deposit(amount);
  rewardPool.withdraw(amount);
  token.transfer(loaner, amount);
}

function attack(uint256 amount) external {
  ILoaner(loaner).flashLoan(amount);
  uint256 rewards = rewardToken.balanceOf(address(this));
  rewardToken.transfer(owner, rewards);
}
```
A simple fix here would be to take the snapshot after distributing rewards instead of before. 

### Selfie
The exploit here is very similar to the previous one. We can use a flash loan to get a majority of the tokens and from their queue up an action to drain funds. Once the action is enqueued we just need to wait until it can be executed.

```solidity
function receiveTokens(address tokenAddress, uint256 amount) external{
  ISnapshot(token).snapshot();
  actionId = governance.queueAction(
    selfie,
    abi.encodeWithSignature("drainAllFunds(address)", owner),
    0);

   IERC20(tokenAddress).transfer(selfie, amount);

}

function attack() external {
  uint256 loanAmount = IERC20(token).balanceOf(address(selfie));
  IFlashLoan(selfie).flashLoan(loanAmount);

}

function drain() external {
  require(actionId  != 0);
  governance.executeAction(actionId);
}
```

A fix here would be to have a separate government token, maybe one that requires locking the original token for a set period of time. 


### Compromised
The is the only challenge I wasn't able to solve. 

### Puppet
The objective here is drain a lending pool.

I liked this challenge because it was finally a break from flash loan exploits and required understanding actual uniswap code (v1 so it's no longer used). Getting experience with actual third party code instead of a theoretical/simplified version is extremely valuable. 

There is actually a rounding error in \_computeOraclePrice() that I didn't notice until after I solved the challenge. If you catch it, it makes the overall exploit much easier to understand and pull off. 

The idea here is that the lending pool issues loans required collateral depended on the price of the DVT token. We can manipulate the price of via the uniswap LP. First we sell off as much DVT as we can in order to tank the price. After that we can get a loan of all the DVT tokens in the lending pool while providing essentially no ETH as collateral. 

We can do all of this without a smart contract if we don't mind it taking a few transactions. 
```js
const swapAmount = ethers.utils.parseEther('999');
const deadline = (await ethers.provider.getBlock('latest')).timestamp * 2;   // deadline

await this.token.connect(attacker).approve(
    this.uniswapExchange.address,
    swapAmount
);

const val = await this.uniswapExchange.getTokenToEthInputPrice(
  swapAmount,
  { gasLimit: 1e6 }
);

const amount = await this.uniswapExchange.connect(attacker).tokenToEthSwapInput(
  swapAmount,
  val,
  deadline,
);

const steal = await this.token.balanceOf(this.lendingPool.address);
const deposit =  await this.lendingPool.calculateDepositRequired(steal);

await this.lendingPool.connect(attacker).borrow(steal, { value: deposit });
```
One tricky part was remembering to provide a gasLimit to the getTokenToEthInputPrice call. 

Fixing the rounding error and not using Uniswap v1 are obvious fixes. 

However, if a whale has a signifant number of tokens relative to the size of an LP this kind of manipulation is still possible. 

### Puppet v2
Same objective as the previous challenge with some of the bugs removed.

The strategy is pretty much the same but we need to adjust to using Uniswap v2. 

Still no additional smart contract required unless you want to do it all in one transaction.

### Free rider
The objective here is to steal some NFTs from a marketplace. 

The NFTs cost more ETH than we have so we can split this into two problems.
1) How to exploit the marketplace.
2) How to get the ETH necessary. 

The first problem didn't take too long to solve. There's a pretty serious bug here in FreeRiderNFTMarketplace.__buyOne.

```solidity
// transfer from seller to buyer
token.safeTransferFrom(token.ownerOf(tokenId), msg.sender, tokenId);

// pay seller
payable(token.ownerOf(tokenId)).sendValue(priceToPay);
```
First the token is transfered from the seller to the buyer, then the seller is sent payment. 

The error is that the owner of the tokenId to determine the seller. The token has already been transferred so the buyer is the now the owner and will get both the NFT and their payment returned. 

A fix for this would be to either send the payement first or store the seller address before transferring the NFT.

The next part of the problem wasn't conceptualy difficult but it took some time to get it right. 

We need a flash loan from Uniswap v2. I was surprised that there wasn't much example code for this available online (at least I couldn't find it). 

This required a smart contract. The attack function gets a flash loan from Uniswap. uniswapV2Call is called by uniswap after they issue the loan.

```solidity
function attack(uint256 price, uint256[] calldata tokenIds) external {
  bytes memory data = abi.encode(price, tokenIds);
  IUniswapV2Pair(pair).swap(price, 0, address(this), data);
}
function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external override{
  require(msg.sender == pair);
  require(sender == address(this));

  uint amount = amount0; //amount0 is WETH
  uint fee = ((amount * 3) / 997) + 1;
  uint repayAmount = amount + fee;

  (uint256 price, uint256[] memory tokenIds) = abi.decode(data, (uint256, uint256[]));

  // Turn it into ETH so we can buy from marketplace
  WETH.withdraw(amount);

  // Buy all the NFTs and get paid out as the seller.
  marketplace.buyMany{value: price}(tokenIds);

  // Send them all to the buyer for bounty.
  for(uint i=0; i < tokenIds.length; i++){
    nft.safeTransferFrom(address(this), buyer, tokenIds[i]);
  }

  // Repay the loan.
  // Turn it back into WETH0
  WETH.deposit{value: repayAmount}();
  WETH.transfer(pair, repayAmount);

  // Send remaining ETH back to attacker.
  payable(owner).transfer(address(this).balance);
}
```
Conceptually this wasn't too difficult but there was a lot of boilerplate code to get right (fee calculation, convering between WETH/ETH, etc). 

### Backdoor

The objective of this challenge to exploit a registry of Gnosis wallets and steal its funds. 

There's a lot going on here and the hint came when looking at the WalletRegistry.proxyCreated function. This is where the reward tokens are distributed to wallets that register. 

There is a comment that says
```solidity
 @notice Function executed when user creates a Gnosis Safe wallet via GnosisSafeProxyFactory::createProxyWithCallback
             setting the registry's address as the callback.
 ```

Now we know we are going to need to call this createProxyWithCallback in order to register the beneficiaries. Then we need find a way to take their reward tokens. 

The exploit takes advantage of how the proxy is set up. In the setup call we can specify an address for a fallbackHandler.

Any calls to the contract that don't match an existing function will be called on this address by the contract. 

For our fallbackHander we used the DVT token address. Now we can call approve/transfer on our newly created proxy and it will be as if the contract called token.approve/transfer. 

```solidity
for (uint i = 0; i < users.length; i++){
  owners[0] = users[i];
  bytes memory setup = abi.encodeWithSignature(
    "setup(address[],uint256,address,bytes,address,address,uint256,address)",
    owners, 1, address(0), "", token, address(0), 0, address(0)
  );
  proxy = ISafe(safe).createProxyWithCallback(
    master,
    setup,
    0,
    registry
  );
  uint256 amount = IERC20(token).balanceOf(address(proxy));
  proxy.approve(msg.sender, amount);
  proxy.transfer(msg.sender, amount);
}
```

The takeaway here is that proxy calls have the potential to be very dangerous and should be treated accordingly. 

It's important to note that if the registry wallets had already been safely setup this exploit would not be possible. There is no issue at all with the Gnosis code, it's just how we've used it. 


### Climber

The objective here is to drain all the funds in a vault. 

The vault contract is upgradeable and owned by a timelock contract that only allows an address with the Proposer role to schedule function execution. 

The vault contains an emergency sweepFunds function that only an address with the Sweeper role can execute. 

This heist will occur in multiple stages
1) First we will use an exploit to gain the Proposer role 
2) We will use this role to execute an upgrade to the vault contract. This updgraded contract will have additionaly functionality that lets use reassign the Sweeper role.
3) Assign the Sweeper role to our attacker's address and sweep the funds.

The upgraded contract functionality is pretty simple. We just need to provide this additional function.
```solidity
function setSweeper(address sweeper) external {
  _setSweeper(sweeper);
}
```
Everything else is inherited from the original vault contract. 

To gain the Proposer role we have to be a bit clever. 

The Timelock contract uses a schedule and execute function to let users run functions on the smart contract.

The Timelock.schedule function can only be run by Proposers but the Timelock.execute function can be run by anyone. 

The Timelock.schedule and Timelock.execute functions both take the same arguments. These arguments are used to calculate the operation ID.  

The execute function checks to make sure this operation ID has been previously scheduled, but only after running the operations requested.

This is considered "safe" because any operations it attempts to run will be reverted unless the operation ID check passes.

To performed the exploit, we're first going to make a call to execute with three instructions.
1) A call on the timelock contract to updateDelay, setting it to 0.
2) A call on the timelock contract to grantRole, giving the Proposer role to another smart contract we've already deployed.
3) A call to "schedule" on our newly made Proposer contract that will complete our exploit.

In this call we in turn make a call to the timelock contract's schedule function. Sine we have the Proposer role this is allowed. 

We can construct our arguments to this call to schedule so that the operation ID saved here is exactly the same as the ID that the original call to execute would have produced. When execute later checks for a matching ID, it will find a match and allow the entire operation to proceed. 

Now we are in control of a smart contract with the Proposer role. 

With this role we can freely schedule an upgrade to the vault contract. The timelock contract is the owner of the vault so it has permission to upgrade the contract at any time. We've also already set the timeDelay to 0 so we can immediately execute the upgrade after scheduling it. 

With the newly upgraded contract available we now have access to the setSweeper function. 

From there we set the sweeper to our attacker's address and can steal the funds.








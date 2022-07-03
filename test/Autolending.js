const { expect } = require("chai");
const { ethers } = require("hardhat");

/* global vars */
let accounts = [];
let staking, diamond, ghst;
const ghstDonorAddress = "0xf3678737dc45092dbb3fc1f49d89e3950abb866d";
const maticDonorAddress = "0x7Ba7f4773fa7890BaD57879F0a1Faa0eDffB3520";
const impersonateAddress = async (address) => {
  const hre = require("hardhat");
  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [address],
  });
  const signer = await ethers.provider.getSigner(address);
  signer.address = signer._address;
  return signer;
};

function eth(amount) {
  amount = amount.toString();
  return ethers.utils.parseEther(amount);
}

async function generateUser() {
  // Create random user
  const wallet = ethers.Wallet.createRandom();
  userAddress = wallet.address;

  // impersonate users
  const user = await impersonateAddress(userAddress);
  const ghstDonor = await impersonateAddress(ghstDonorAddress);
  const maticDonor = await impersonateAddress(maticDonorAddress);

  // Transfer GHST
  await ghst.connect(ghstDonor).transfer(user.address, eth(49));

  // Transfer matic
  await maticDonor.sendTransaction({
    to: user.address,
    value: ethers.utils.parseEther("10.0"),
  });

  // User approve GHST for staking
  await ghst.connect(user).approve(staking.address, eth(100));

  accounts.push(user);

  return user;
}

describe("Deployement", function () {
  let owner, u1, u2, u3, u4, u5;

  const erc20abi = require("./erc20abi.json");
  const diamondabi = require("./diamondabi.json");

  before(async function () {
    [owner] = await ethers.getSigners();

    // Deploy the staking contract
    const stakingFactory = await ethers.getContractFactory("Staking");
    staking = await stakingFactory.deploy();

    // Connect to the ghst contract
    ghst = new ethers.Contract(
      "0x385Eeac5cB85A38A9a07A70c73e0a3271CfB54A7",
      erc20abi,
      owner
    );

    // Connect to diamond
    diamond = new ethers.Contract(
      "0x86935F11C86623deC8a25696E1C19a8659CbF95d",
      diamondabi,
      owner
    );
    u1 = await generateUser();
    u2 = await generateUser();
    u3 = await generateUser();
    u4 = await generateUser();
    u5 = await generateUser();
  });

  before(async function () {
    await network.provider.send("evm_increaseTime", [86400]);
    await network.provider.send("evm_mine");
  });

  // Check initial state
  it("u1 should have allowed 100 GHST", async function () {
    expect(await ghst.allowance(u1.address, staking.address)).to.equal(
      eth(100)
    );
  });

  describe("Signing up", function () {
    before(async function () {
      accounts.forEach(async (u) => {
        await staking.connect(u).signUp();
      });
    });

    beforeEach(async function () {
      const users = await staking.getUsers();
      let success = true;
      for (let i = 0; i < users.length; i++) {
        u = users[i];
        index = await staking.usersToIndex(u);
        console.log(`u=${u} index=${index} i=${i}`);
        if (index != i) {
          console.log(`u=${index} i=${i}`);
          success = false;
          break;
        }
      }
      console.log("*** " + success);
      expect(success).to.be.true;
    });

    it("u1 Index should be 1", async function () {
      expect(await staking.usersToIndex(u1.address)).to.equal(1);
    });

    it("u1 shouldn't be able to signUp twice", async function () {
      await expect(staking.connect(u1).signUp()).to.be.reverted;
    });

    it("u1 should be signedUp after staking 49 GHST", async function () {
      expect(await staking.getIsSignedUp(u1.address)).to.be.true;
    });

    it("u2 should be signedUp after staking 49 GHST", async function () {
      expect(await staking.getIsSignedUp(u2.address)).to.be.true;
    });

    it("u1 should have 0 Balance & shares", async function () {
      const allUsers = await staking.getUsers();
      console.log(allUsers);
      await staking.connect(u1).leave();
      expect(await staking.connect(u1).getUserShares(u1.address)).to.equal(0);
    });

    it("u3 should be able to leave", async function () {
      await staking.connect(u3).leave();

      const allUsers = await staking.getUsers();
      expect(allUsers.length).to.equal(4);
    });

    it("u3 should have index == 0", async function () {
      expect(await staking.usersToIndex(u3.address)).to.equal(0);
    });
  });
});

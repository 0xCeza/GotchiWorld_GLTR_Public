const { expect } = require("chai");
const { ethers } = require("hardhat");

// todo check if all function and var are tested

/* global vars */
let accounts = [];
let staking, ghst, gltr;
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
  await ghst.connect(ghstDonor).transfer(user.address, eth(99));

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

describe("Deployement => SignUp => Leaving", function () {
  let owner, u1, u2, u3, u4, u5;

  const erc20abi = require("./erc20abi.json");

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

    // Connect to the gltr contract
    gltr = new ethers.Contract(
      "0x3801C3B3B5c98F88a9c9005966AA96aa440B9Afc",
      erc20abi,
      owner
    );

    // Generate new users and provide them GHST and Matic
    u1 = await generateUser();
    u2 = await generateUser();
    u3 = await generateUser();
    u4 = await generateUser();
    u5 = await generateUser();

    // All users signUp
    accounts.forEach(async (u) => {
      await staking.connect(u).signUp();
    });
  });

  beforeEach(async function () {
    // One day passes between each test
    await network.provider.send("evm_increaseTime", [86400]);
    await network.provider.send("evm_mine");

    // Display contract ghst balance
    // const contractGhstBalance = await ghst.balanceOf(staking.address);
    // console.log(ethers.utils.formatUnits(contractGhstBalance, 18));

    // At each test, check if index of user array is still correct
    const users = await staking.getUsers();
    let success = true;
    for (let i = 0; i < users.length; i++) {
      u = users[i];
      index = await staking.getUsersToIndex(u);
      // console.log(`u=${u} index=${index} i=${i}`);
      if (index != i) {
        console.log(`u=${index} i=${i}`);
        success = false;
        break;
      }
    }
    // console.log("*** " + success);
    expect(success).to.be.true;
  });

  it("Owner should be approved", async function () {
    expect(await staking.getIsApproved(owner.address)).to.be.true;
  });

  it("U1 to U5 shouldn't be able to signUp twice", async function () {
    await expect(staking.connect(u1).signUp()).to.be.reverted;
    await expect(staking.connect(u2).signUp()).to.be.reverted;
    await expect(staking.connect(u3).signUp()).to.be.reverted;
    await expect(staking.connect(u4).signUp()).to.be.reverted;
    await expect(staking.connect(u5).signUp()).to.be.reverted;
  });

  it("U1 to U5 should be signedUp after staking 99 GHST", async function () {
    expect(await staking.getIsSignedUp(u1.address)).to.be.true;
    expect(await staking.getIsSignedUp(u2.address)).to.be.true;
    expect(await staking.getIsSignedUp(u3.address)).to.be.true;
    expect(await staking.getIsSignedUp(u4.address)).to.be.true;
    expect(await staking.getIsSignedUp(u5.address)).to.be.true;
  });

  it("After leaving, U1 should have 0 Balance & shares & index", async function () {
    await staking.connect(u1).leave();
    expect(await staking.getUsersToIndex(u1.address)).to.equal(0);
    expect(await staking.connect(u1).getUserShares(u1.address)).to.equal(0);
    expect(await staking.connect(u1).getUserGhstBalance(u1.address)).to.equal(
      0
    );
  });

  it("U3 should be able to leave and users.length should be 4", async function () {
    await staking.connect(u3).leave();
    const allUsers = await staking.getUsers();
    expect(allUsers.length).to.equal(4);
  });

  it("After leaving, U3 should have 0 Balance & shares & index", async function () {
    expect(await staking.getUsersToIndex(u3.address)).to.equal(0);
    expect(await staking.connect(u1).getUserShares(u1.address)).to.equal(0);
    expect(await staking.connect(u1).getUserGhstBalance(u1.address)).to.equal(
      0
    );
  });

  it("U1 and U3 should have 98 GHST", async function () {
    expect(await ghst.balanceOf(u1.address)).to.equal(eth(98));
    expect(await ghst.balanceOf(u3.address)).to.equal(eth(98));
  });

  it("U1 to U5 shouldn't be able to withdraw admin funds", async function () {
    await expect(staking.connect(u1).withdrawGltrAndGhst(u1.address)).to.be
      .reverted;
    await expect(staking.connect(u2).withdrawGltrAndGhst(u2.address)).to.be
      .reverted;
    await expect(staking.connect(u3).withdrawGltrAndGhst(u3.address)).to.be
      .reverted;
    await expect(staking.connect(u4).withdrawGltrAndGhst(u4.address)).to.be
      .reverted;
    await expect(staking.connect(u5).withdrawGltrAndGhst(u5.address)).to.be
      .reverted;
  });

  it("Owner should be able to withdraw GLTR + Fees", async function () {
    const contractGhstBalance = await ghst.balanceOf(staking.address);
    const contractGltrBalance = await gltr.balanceOf(staking.address);
    // console.log(ethers.utils.formatUnits(contractGhstBalance, 18));
    // console.log(ethers.utils.formatUnits(contractGltrBalance, 18));

    // let balGhst = await ghst.balanceOf(owner.address);
    // let balGltr = await gltr.balanceOf(owner.address);
    // console.log(ethers.utils.formatUnits(balGhst, 18));
    // console.log(ethers.utils.formatUnits(balGltr, 18));

    await staking.connect(owner).withdrawGltrAndGhst(owner.address);

    // balGhst = await ghst.balanceOf(owner.address);
    // balGltr = await gltr.balanceOf(owner.address);
    // console.log(ethers.utils.formatUnits(balGhst, 18));
    // console.log(ethers.utils.formatUnits(balGltr, 18));

    expect(await ghst.balanceOf(owner.address)).to.equal(contractGhstBalance);
    expect((await gltr.balanceOf(owner.address)) > contractGltrBalance).to.be
      .true;
    expect((await ghst.balanceOf(owner.address)) > 0).to.be.true;
    expect((await gltr.balanceOf(owner.address)) > 0).to.be.true;
    // balGhst = await ghst.balanceOf(owner.address);
    // balGltr = await gltr.balanceOf(owner.address);
    // console.log(ethers.utils.formatUnits(balGhst, 18));
    // console.log(ethers.utils.formatUnits(balGltr, 18));
  });
});

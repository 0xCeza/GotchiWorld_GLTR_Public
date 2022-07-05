// Command to deploy :
// npx hardhat run scripts/deploy.js --network <your-network>
// Command to verify :
// npx hardhat verify --network <your-network> CONTRACT_ADDRESS "Constructor argument 1"

async function main() {
  // We get the contract to deploy
  const Staking = await ethers.getContractFactory("Staking");
  const staking = await Staking.deploy();

  await staking.deployed();

  console.log("Staking deployed to:", staking.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

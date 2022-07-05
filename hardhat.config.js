/**
 * @type import('hardhat/config').HardhatUserConfig
 */

require("dotenv").config();
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");

module.exports = {
  solidity: "0.8.7",
  networks: {
    hardhat: {
      forking: {
        url: "https://polygon-rpc.com",
      },
    },
    polygon: {
      url: "https://polygon-rpc.com",
      accounts: [process.env.PRIVATE_KEY_GW],
    },
  },
  etherscan: {
    apiKey: process.env.POLYGONSCAN,
  },
};

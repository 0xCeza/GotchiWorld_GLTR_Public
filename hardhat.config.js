/**
 * @type import('hardhat/config').HardhatUserConfig
 */

require("@nomiclabs/hardhat-waffle");

module.exports = {
  solidity: "0.8.13",
  networks: {
    hardhat: {
      forking: {
        url: "https://polygon-rpc.com",
      },
    },
  },
};

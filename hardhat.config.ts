import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv"; // see https://github.com/motdotla/dotenv#how-do-i-use-dotenv-with-import
import "@nomiclabs/hardhat-etherscan";
import '@openzeppelin/hardhat-upgrades';


dotenv.config();

const config: HardhatUserConfig = {
  solidity: "0.8.17",
  networks: {
    gnosis: {
      url: process.env.GNOSIS_RPC!,
      accounts: [process.env.PRIVATE_KEY!],
    },
  },
  etherscan: {
    customChains: [
      {
        network: "gnosis",
        chainId: 100,
        urls: {
          apiURL: "https://api.gnosisscan.io/api",
          browserURL: "https://gnosisscan.io/",
        },
      },
    ],
    apiKey: {
      gnosis: process.env.GNOSISSCAN_APIKEY!
    }
  },
};

export default config;

require('dotenv').config()
require('@nomiclabs/hardhat-ethers')
require('@nomiclabs/hardhat-waffle')
require('@nomiclabs/hardhat-etherscan')
require('solidity-coverage')

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  networks: {
    hardhat: {
      accounts: {
        mnemonic: process.env.MNEMONIC || '',
      },
    },
    rinkeby: {
      url: 'https://rinkeby.infura.io/v3/' + process.env.INFURA_API_KEY,
      accounts: {
        mnemonic: process.env.MNEMONIC || '',
      },
      timeout: 1000000,
    },
    mainnet: {
      url: 'https://mainnet.infura.io/v3/' + process.env.INFURA_API_KEY,
      gasPrice: 50e9,
      accounts: {
        mnemonic: process.env.MNEMONIC || '',
      },
      timeout: 1000000,
    },
  },
  solidity: {
    compilers: [
      {
        version: '0.8.7',
        settings: {
          optimizer: {
            enabled: true,
            runs: 999999,
          },
        },
      },
    ],
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  paths: {
    artifacts: './build',
  },
}

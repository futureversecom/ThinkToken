# Token and TokenPeg Contracts

## Overview

This repository contains smart contracts for a token system with bridging capabilities between Ethereum and The Root Network.

## Key Components

- `Token.sol`: ERC20 token with access control and pausable features
- `ERC20Peg.sol`: Bridge contract for cross-chain token operations
- `Bridge.sol`: Core bridge contract for cross-chain messaging
- `Roles.sol` - Role definitions for access control

### Token Contract

Uses OpenZeppelin's AccessControl with roles:

- `DEFAULT_ADMIN_ROLE`: Can grant/revoke roles
- `MANAGER_ROLE`: Can initialize token and pause
- `MULTISIG_ROLE`: Can mint/burn tokens and unpause

### ERC20Peg Contract

Uses OpenZeppelin's Ownable pattern:

- Owner can:
  - Set deposits active/inactive
  - Set withdrawals active/inactive
  - Update bridge address
  - Set pallet address
  - Perform emergency withdrawals

## Features

- ERC20 token with 18 decimals
- Total supply capped at 1B tokens
- Cross-chain token bridging
- Pausable transfers
- Secure deposit/withdrawal mechanisms
- Bridge integration for cross-chain operations

## Development

### Prerequisites

- Node.js 16+
- Foundry
- Git

### Setup

```bash
git clone <repository-url>
cd <repository-name>
forge install
npm install
cp .env.example .env
```

### Testing

```bash
# Run all tests
forge test

# Run with gas reporting
forge test --gas-report
```

## Deployment

### Environment Setup

1. Copy `.env.example` to `.env`
2. Fill in required variables:
   - RPC URLs
   - Private keys
   - Contract addresses

### Deploy

```bash
# Using Foundry
forge script scripts/Deploy.s.sol:Mainnet --rpc-url $MAIN_RPC_URL --broadcast

# Testnet deployment
forge script scripts/Deploy.s.sol:Testnet --rpc-url $TEST_RPC_URL --broadcast
```

#### Using Hardhat

```bash
# Deploy to mainnet
npx hardhat run scripts/deploy.ts --network mainnet

# Deploy to testnet
npx hardhat run scripts/deploy.ts --network testnet
```

### Contract Verification

After deployment, verify contracts on Etherscan:

```bash
# Verify Token contract
npx hardhat verify --network <network> <token-address> \
  "<roles-manager>" \
  "<token-contract-manager>" \
  "<token-recovery-manager>" \
  "<multisig>"

# Verify TokenPeg contract
npx hardhat verify --network <network> <peg-address> \
  "<bridge>" \
  "<token-address>" \
  "<roles-manager>" \
  "<peg-manager>"
```

## Security Considerations

- Owner privileges in ERC20Peg should be managed via multisig
- Private keys must never be committed to version control
- Regular security audits recommended
- Test coverage should be maintained at 100%

## Deployments

### Sepolia

```

Token deployed to: 0x7A462Cc5F03D8B9f0dDa83BFf6f5C65974228950
  The Roles manager is: 0x7D2713d17C88d08daa7fE5f437B4205deA977ade
  The manager of the Token is: 0x1Fb0E85b7Ba55F0384d0E06D81DF915aeb3baca3
  The multisig of the Token is: 0xd0eEdbe42BFB9d3082e4AB16F2925962233e2C36

```

### Porcini

<!-- - Token deployed to: [0x2fE0890D74e68e3A61213213Fb7F3221D50979F3](https://porcini.rootscan.io/addresses/0x2fE0890D74e68e3A61213213Fb7F3221D50979F3/contract/read)
- TokenPeg deployed to: [0x9153442a8AD734334424d39FDfF8524525529a7d](https://porcini.rootscan.io/addresses/0x9153442a8AD734334424d39FDfF8524525529a7d/contract/read)

Log:

```
Bridge deployed to: 0xe800b81c76Af4D3a81802DE47c46dA1E8507d034
The owner of the Bridge is: 0xeb24a849E6C908D4166D34D7E3133B452CB627D2

Token deployed to: 0x2fE0890D74e68e3A61213213Fb7F3221D50979F3
The Roles manager is: 0x7D2713d17C88d08daa7fE5f437B4205deA977ade
The manager of the Token is: 0x1Fb0E85b7Ba55F0384d0E06D81DF915aeb3baca3
The recovery manager is: 0xd0eEdbe42BFB9d3082e4AB16F2925962233e2C36
The multisig of the Token is: 0xd0eEdbe42BFB9d3082e4AB16F2925962233e2C36

TokenPeg deployed to: 0x9153442a8AD734334424d39FDfF8524525529a7d
The Roles manager of the TokenPeg is: 0x7D2713d17C88d08daa7fE5f437B4205deA977ade
The peg manager of the TokenPeg is: 0xbecb053527Bf428C7A44743B8b00b30e42B0e418
Token role set (to store refunds): 0x2fE0890D74e68e3A61213213Fb7F3221D50979F3

Starting setup phase...
Bridge activated
Token initialized with peg address: 0x9153442a8AD734334424d39FDfF8524525529a7d
TokenPeg deposits/withdrawals activated
Pallet address set to: 0x0000000000000000000000000000000000000000
``` -->

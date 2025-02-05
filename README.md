# Token and TokenPeg Contracts

## Overview

This repository contains smart contracts for a token system with bridging capabilities and refund mechanisms.

## Scope

Core contracts:

- `contracts/Token.sol` - Main ERC20 token implementation with refund mechanism
- `contracts/TokenPeg.sol` - Bridge peg contract for cross-chain operations
- `contracts/Roles.sol` - Role definitions for access control

Test contracts:

- `test/TokenPegRefund.t.sol` - Tests for token refund functionality
- `test/Token.t.sol` - Core token functionality tests

## Features

- ERC20 token with 6 decimals
- Total supply capped at 1B tokens
- Pausable transfers
- Token refund mechanism
- Role-based access control
- Bridge integration for cross-chain operations
- Fee collection system

## Roles

The system uses the following roles:

- `DEFAULT_ADMIN_ROLE` - Can grant/revoke other roles
- `MANAGER_ROLE` - Can initialize token and pause contract
- `MULTISIG_ROLE` - Can mint/burn tokens and unpause contract
- `TOKEN_RECOVERY_ROLE` - Can withdraw fees and manage fees
- `PEG_MANAGER_ROLE` - Can manage peg operations. !! ATTN: it can withdraw Peg's funds.
- `TOKEN_ROLE` - Token contract's role to call TokenPeg contract to record refunds

## Development

### Prerequisites

- Node.js 16+
- Foundry
- Git

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd <repository-name>

# Install dependencies
forge install
npm install

# Copy environment file
cp .env.example .env
```

### Testing

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-contract TokenPegRefund

# Run with gas reporting
forge test --gas-report
```

## Deployment

### Environment Setup

1. Copy `.env.example` to `.env`
2. Configure environment variables:

### Deployment Scripts

#### Using Foundry

```bash
# Mainnet deployment
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

## Contract Interaction

### Key Functions

#### Token Contract

- `init(address peg)` - Initialize token with peg address (token contract manager only)
- `pause()` - Pause token transfers (manager only)
- `unpause()` - Unpause token transfers (multisig only)
- `setReimbursementFee(uint256)` - Set refund fee percentage (token recovery role only)

#### TokenPeg Contract

- `withdraw()` - Withdraw available refund
- `adminFeesWithdrawal(address)` - Withdraw collected fees (token recovery role only)
- `setWithdrawalsActive(bool)` - Enable/disable withdrawals (peg manager only)

### Refund Mechanism

When tokens are sent to the peg contract:

1. A fee percentage is taken (default 10%)
2. The remaining amount is stored as a refund
3. The sender can withdraw their refund using `withdraw()`
4. Collected fees can be withdrawn by token recovery role

## Security Considerations

- All private keys should be kept secure and never committed to version control
- Production deployments should use multisig wallets for critical roles
- Regular security audits are recommended
- Test thoroughly before mainnet deployment

## Deployments

### Sepolia

```
Bridge deployed to: 0x1a4232995e2C8F67ef7bD94EACD7Dd9C67160Ff8
  The owner of the Bridge is: 0xeb24a849E6C908D4166D34D7E3133B452CB627D2

Token deployed to: 0xd9088A9f07ac390BC0E80D1D412638bFFe6a8bc7
  The Roles manager is: 0x7D2713d17C88d08daa7fE5f437B4205deA977ade
  The manager of the Token is: 0x1Fb0E85b7Ba55F0384d0E06D81DF915aeb3baca3
  The recovery manager is: 0xd0eEdbe42BFB9d3082e4AB16F2925962233e2C36
  The multisig of the Token is: 0xd0eEdbe42BFB9d3082e4AB16F2925962233e2C36

TokenPeg deployed to: 0x8556A532Bf8E1F0c46FAb8a3ec2Ee5ac9d58169b
  The Roles manager of the TokenPeg is: 0x7D2713d17C88d08daa7fE5f437B4205deA977ade
  The peg manager of the TokenPeg is: 0xbecb053527Bf428C7A44743B8b00b30e42B0e418
  Token role set (to store refunds): 0xd9088A9f07ac390BC0E80D1D412638bFFe6a8bc7
  Bridge activated
  Token initialized with peg address: 0x8556A532Bf8E1F0c46FAb8a3ec2Ee5ac9d58169b
  TokenPeg deposits/withdrawals activated
  Pallet address set to: 0x0000000000000000000000000000000000000000

Deployment Complete
  Bridge: 0x1a4232995e2C8F67ef7bD94EACD7Dd9C67160Ff8
  Token: 0xd9088A9f07ac390BC0E80D1D412638bFFe6a8bc7
  TokenPeg: 0x8556A532Bf8E1F0c46FAb8a3ec2Ee5ac9d58169b
```

### Porcini

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
```

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
- `PEG_MANAGER_ROLE` - Can manage peg operations
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

#### Mainnet Deployment

```
MAIN_DEPLOYER_PK=        # Deployer private key
MAIN_DEPLOYER=           # Deployer address
MAIN_ROLES_MANAGER=      # Roles manager address
MAIN_ROLES_MANAGER_PK=   # Roles manager private key
MAIN_TOKEN_CONTRACT_MANAGER=
MAIN_TOKEN_RECOVERY_MANAGER=
MAIN_MULTISIG=
MAIN_PEG_MANAGER=
MAIN_BRIDGE_ADDRESS=
```

#### Testnet Deployment

```
TEST_DEPLOYER_PK=
TEST_DEPLOYER=
TEST_ROLES_MANAGER=
TEST_ROLES_MANAGER_PK=
TEST_TOKEN_CONTRACT_MANAGER=
TEST_TOKEN_RECOVERY_MANAGER=
TEST_MULTISIG=
TEST_PEG_MANAGER=
TEST_BRIDGE_ADDRESS=
```

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

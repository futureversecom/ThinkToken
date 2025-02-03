# ThinkTokenAudit

## Scope

Core contracts:

- contracts/ThinkToken.sol - Main ERC20 token implementation
- contracts/TokenRecovery.sol - Token recovery functionality
- contracts/Roles.sol - Role definitions

There are some tests to help to understand the process flow:

- test/ThinkToken.t.sol - Main token functionality tests
- test/TokenRecovery.t.sol - Recovery mechanism tests

## Features

- ERC20 token with 6 decimals
- Pausable transfers
- Token recovery mechanism
- Role-based access control
- Capped supply (1B tokens)

## Roles

The contract uses a role-based access control system with the following roles:

- DEFAULT_ADMIN_ROLE - Can manage other roles
- MANAGER_ROLE - Can pause the token and manage recovery settings
- MULTISIG_ROLE - Can unpause, burn, and mint tokens

## Deployment

### Prerequisites

- Node.js 14+
- Foundry installed
- Environment variables configured (see .env.example)

### Sepolia

#### Manually

```
export RPC_URL=https://rpc.ankr.com/eth_sepolia
export MANAGER=0x1Fb0E85b7Ba55F0384d0E06D81DF915aeb3baca3
export MULTISIG=0x1Fb0E85b7Ba55F0384d0E06D81DF915aeb3baca3
export PEG=<peg_address>
export MANAGER_PK=e49dcc90004a6788dcf67b74878c755d61502d686f76f1714f3ed91629fd4d52

forge create ./contracts/Bridge.sol:Bridge \
  --private-key $PK --rpc-url $RPC_URL --verify

forge create --legacy ./contracts/ThinkToken.sol:ThinkToken \
  --private-key $PK --rpc-url $RPC_URL --verify \
  --constructor-args $MANAGER $MULTISIG
```

export the deployed tokens:

- ThinkToken as `export RT=0x...`
- Bridge as `export BRIDGE=0x...`

```
forge create ./contracts/ThinkTokenPeg.sol:ThinkTokenPeg \
  --private-key $PK --rpc-url $RPC_URL --verify \
  --constructor-args $BRIDGE $RT
```

Export Peg contract as `export PEG=0x...`

Finally, initialize Root Token (call from manager address):

```
cast send --private-key $MANAGER_PK --rpc-url $RPC_URL \
  $TOKEN "init(address)" $PEG
```

#### Automatically

Using Foundry:

- To simulate: `forge script scripts/Deploy.s.sol:Testnet --rpc-url $RPC_URL`
- To actually deploy: `forge script scripts/Deploy.s.sol:Testnet --rpc-url $RPC_URL --broadcast`

Using Hardhat:

```bash
# Set up environment variables first
cp .env.example .env
# Edit .env with your configuration

# Deploy
npx hardhat run scripts/deploy.ts --network <network_name>
```

### Existing Deployments

### Ethereum mainnet

- [Bridge](https://etherscan.io/address/0x110fd9a44a056cb418D07F7d9957D0303F0020e4)
- [ThinkTokenPeg](https://etherscan.io/address/0x7556085e8e6a1dabbc528fbca2c7699fa5ee6e11)
- [ThinkToken](https://etherscan.io/address/0x69b2d8beef1aac40a7192195d726b5ffbb5a8cb8)

#### Sepolia

- [Bridge](https://sepolia.etherscan.io/address/0x3f27c938507874829b33db354d40d32db8756b01)
- [ThinkTokenPeg](https://sepolia.etherscan.io/address/0x5c752e9d3ecc8db4b4b5a84052399f3618c332bf)
- [ThinkToken](https://sepolia.etherscan.io/address/0x2e3b1351f37c8e5a97706297302e287a93ff4986)

#### GOERLI

- [Bridge](https://goerli.etherscan.io/address/BRIDGE=0xf11DAfE58eff2EaeD0fC9413489e139fA15D2C43)
- [ThinkTokenPeg](https://goerli.etherscan.io/address/0xc863d1f57e601f23836148022fc6ba21644c7c32)
- [ThinkToken](https://goerli.etherscan.io/address/0x0Bf14298882cCE87a774DB1d0cD1D0B6db2d02b8)

## Contract Interaction

### Key Functions

- `init(address peg)` - Initialize token with peg address (manager only)
- `pause()` - Pause token transfers (manager only)
- `unpause()` - Unpause token transfers (multisig only)
- `burn(uint256 amount)` - Burn tokens (multisig only)
- `mint(address to, uint256 amount)` - Mint new tokens (multisig only)

### Token Recovery

If tokens are accidentally sent to the contract:

1. A fee percentage is taken (default 10%)
2. The sender can withdraw their remaining tokens
3. Fees can be withdrawn by the manager

## Testing

```bash
# Run all tests
forge test

# Run specific test
forge test --match-test test_name

# Run with gas reporting
forge test --gas-report
```

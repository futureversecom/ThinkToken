# ThinkTokenAudit

## Scope

- contracts/ThinkToken.sol
- contracts/Bridge.sol
- contracts/IBridge.sol
- contracts/ERC20Peg.sol

There are some tests to help to understand the process flow:

- test/\*

## Roles

We use three roles:

- Owner - for the ThinkTokenPeg. It MUST be a multisig wallet.
- Manager - for emergency pausing token contract
- Multisig - to unpause token contract, burn or mint tokens.

## Deployment

### Sepolia

#### Manually

```
export RPC_URL=https://rpc.ankr.com/eth_sepolia
export MANAGER=0x1Fb0E85b7Ba55F0384d0E06D81DF915aeb3baca3
export MULTISIG=0x1Fb0E85b7Ba55F0384d0E06D81DF915aeb3baca3
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
  $RT "init(address)" $PEG
```

#### Automatically

- To simulate: `forge script scripts/Deploy.s.sol:Testnet --rpc-url $RPC_URL`
- To actually deploy: `forge script scripts/Deploy.s.sol:Testnet --rpc-url $RPC_URL --broadcast`

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

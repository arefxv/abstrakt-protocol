# Abstrakt Protocol Ecosystem 🚀

**Abstrakt Protocol** is a comprehensive, modular DeFi ecosystem designed to provide a full-stack Web3 experience. Built with **Solidity 0.8.22** and leveraging **Foundry** for development, the protocol integrates cutting-edge technologies like **ERC-4337 Account Abstraction, Chainlink VRF/Automation, and OpenZeppelin's governance frameworks**.
This ecosystem is designed to be secure, scalable, and user-friendly, offering a suite of tools for decentralized finance, governance, NFTs, and cross-chain interoperability.

## Table of Contents
1. Overview

2. Contracts

3. Features

4. Getting Started

5. Architecture

6. Security

7. Contributing

8. License

## Contracts Overview

| Contract | Description | Tech Stack |
|----------|-------------|------------|
| `XVFi` | Core protocol entry point | Solidity 0.8.22 |
| `AbstraktWalletEngine` | ERC-4337 Smart Account Engine | Foundry, Chainlink |
| `AirStrakt` | Merkle Airdrop System | EIP-712, OZ Merkle |
| `AbstraktDAO` | Governance & Proposals | OZ Governor, UUPS |
| `AbstraktGenesisNFT` | NFT Marketplace Protocol | ERC721, Royalties |
| `AbstraktGovernToken` | Governance Token | ERC20Votes, Permit |
| `AbstraktSmartToken` | Utility Token | ERC20, Burnable |
| `AbstraktTokenPool` | Cross-Chain Bridge | CCIP, Token Pools |
| `LuckyStrakt` | Decentralized Lottery | Chainlink VRF/Automation |

Abstrakt Protocol is a **modular DeFi stack** that combines **smart contract wallets**, **on-chain governance**, **NFT infrastructure**, and **cross-chain interoperability** into a single, cohesive ecosystem. It is designed to address key challenges in Web3, such as user experience, security, and scalability, while providing developers with a robust framework to build decentralized applications.

The protocol is built with **Foundry**, a fast and efficient development framework for Ethereum smart contracts, ensuring high-quality code and comprehensive testing. It integrates **Chainlink VRF** for provable fairness, **ERC-4337** for account abstraction, and **OpenZeppelin** for secure, audited smart contract components

## Contracts 
The Abstrakt Protocol ecosystem consists of the following core contracts:

1. ### XVFi

* **Description**: The core entry point for the protocol, managing interactions between different components.

* **Key Features**:

    * Protocol-wide configuration management

2. ### AbstraktWalletEngine

* **Description**: An ERC-4337-compliant smart contract wallet engine.

* **Key Features**:

  * Social recovery with guardians

  * WebAuthn integration

  * Batched transactions

  * Anti-freeze mechanism

3. ### AirStrakt

* **Description**: A Merkle-based airdrop system for fair token distribution.

* **Key Features**:

  * EIP-712 signed claims

  * Replay attack protection

  * Non-reentrant claims

4. ### AbstraktDAO

* **Description**: A governance system for decentralized decision-making.

* **Key Features**:

  * Token-weighted voting

  * Timelock-controlled proposals

  * UUPS upgrade pattern

  * Quorum management

5. ### AbstraktGenesisNFT

* **Description**: An ERC721 NFT collection with built-in marketplace functionality.

* **Key Features**:

  * Fixed supply of 888 NFTs

  * 5% royalty enforcement

  * Floor price protection

  * Owner-controlled metadata

6. ### AbstraktGovernToken

* **Description**: A governance token with voting power and interest rate mechanisms.

* **Key Features**:

  * ERC20Votes for governance

  * ERC20Permit for gasless approvals

  * Interest rate system for token holders

7. ### AbstraktSmartToken

* **Description**: A utility token with minting and burning capabilities.

* **Key Features**:

   * Owner-controlled minting

   * Burnable tokens

   * Access control for future extensions

8. ### AbstraktTokenPool

* **Description**: A cross-chain token pool for seamless asset transfers.

* **Key Features**:

  * CCIP-compatible

  * Interest rate preservation

  * Secure lock/burn and release/mint mechanisms

9. ### LuckyStrakt

* **Description**: A decentralized lottery system with provable fairness.

* **Key Features**:

  * Chainlink VRF for randomness

  * Two-tier participation (paid and NFT-based)

  * Automated draws with Chainlink Automation

## Features

### Core Features
  * ERC-4337 Smart Accounts: Gasless transactions and social recovery.

  * On-Chain Governance: Transparent, token-weighted voting.

  * NFT Ecosystem: Royalty enforcement and marketplace functionality.

  * Cross-Chain Interoperability: CCIP-enabled token transfers.

  * Provably Fair Systems: Chainlink VRF for randomness.

### Security Features

  * Reentrancy Guards: Protection against reentrancy attacks.

  * Role-Based Access Control: Secure permission management.

  * Timelock Proposals: Safe execution of governance decisions.

  * Upgradeable Contracts: UUPS pattern for future-proofing.

### Developer Features

  * Foundry Integration: Fast and efficient development.

  * Comprehensive Testing: 100% test coverage.

  * Modular Design: Easy integration with other protocols.

## Getting Started

### Requirements
- Foundry (v0.8.22+)
- Git

### Installation
```bash
git clone https://github.com/arefxv/abstrakt-protocol.git
cd abstrakt-protocol
forge install
```


## Architecture 

The Abstrakt Protocol ecosystem is designed as a modular stack, with each component interacting seamlessly with others. Below is a high-level architecture diagram:

```
graph TD
    A[XVFi] --> B[AbstraktWalletEngine]
    A --> C[AbstraktDAO]
    B --> D[AirStrakt]
    C --> E[AbstraktGovernToken]
    D --> F[AbstraktGenesisNFT]
    E --> G[AbstraktTokenPool]
    F --> H[LuckyStrakt]
```


## License 
This project is licensed under the **MIT License**. See LICENSE for details.

# THANKS!
## ArefXV
# Uniswap V2 Clone

This repository contains a re-implementation of the **Uniswap V2** decentralized exchange protocol, designed with modern Solidity practices and improved gas efficiency. The contracts follow the original Uniswap V2 architecture but introduce optimizations, enhanced security, and compliance with the latest Ethereum standards.

### Key Features

- **Solidity 0.8.0+**: The codebase uses Solidity version 0.8.0 or higher, which introduces built-in overflow protection, eliminating the need for SafeMath. Special consideration is given to areas where the original implementation relied on overflow behavior (e.g., in the oracle).
  
- **Solady ERC20 Library**: The LP tokens are implemented using the **Solady ERC20** library for gas efficiency. The Solady library is also used to compute square roots more efficiently.

- **Re-entrancy Protection**: The traditional Uniswap V2 re-entrancy lock has been replaced, as it is no longer gas efficient due to changes in the EVM. This implementation includes a more optimized safeguard against re-entrancy attacks.

- **Swap, Mint, and Burn Safety**: Built-in safety checks are enforced for all key functions (swap, mint, and burn) to prevent unexpected behaviors or malicious usage. Users can directly interface with the contracts without relying on an external router.

- **No Flash Swaps**: Flash swaps are **not** supported within the swap function. Instead, a separate **ERC-3156 compliant flashloan function** has been implemented for executing flash loans.

- **Factory and Pair Only**: This implementation includes only the essential **Factory** and **Pair** contracts. The **Pair** contract inherits from ERC20 and handles all LP token logic. Other components, such as routers or additional contracts, are intentionally omitted for simplicity.

### Technical Details

- **Solidity Version**: 0.8.0 or higher, utilizing modern features like overflow protection.
- **Optimizations**: Gas-efficient mechanisms for re-entrancy protection, ERC20 token management, and square root calculations.
- **Flash Loan Compliance**: Separate **ERC-3156** flashloan functionality, improving modularity and security.
- **No SafeMath**: With Solidity 0.8.0+, SafeMath is no longer required, reducing gas usage.

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

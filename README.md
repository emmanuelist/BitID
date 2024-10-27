# Stacks Digital Identity Contract

## Overview

This smart contract implements a decentralized digital identity system on the Stacks blockchain. It allows users to create and manage their digital identities, delegate permissions to other addresses, manage NFT associations, and implement recovery mechanisms.

## Features

- **Identity Management**

  - Create unique digital identities with usernames and public keys
  - Update identity information
  - Disable/deactivate identities
  - Identity recovery mechanism

- **Delegation System**

  - Add and remove delegates with expiration timestamps
  - Maximum of 10 delegates per identity
  - Delegate authorization checks

- **NFT Integration**

  - Associate NFTs with identities (max 10 NFTs per contract)
  - SIP009 NFT standard compliance
  - Ownership verification

- **Access Control**
  - Owner-only functions
  - Delegate permissions
  - Contract owner administrative functions

## Functions

### Identity Creation and Management

```clarity
(create-identity (username (string-ascii 50)) (pubkey (buff 33)))
(update-identity (id uint) (new-username (string-ascii 50)) (new-pubkey (buff 33)))
(disable-identity (id uint))
```

### Delegation Management

```clarity
(add-delegate (id uint) (delegate principal) (expires-in uint))
(remove-delegate (id uint) (delegate principal))
```

### Recovery System

```clarity
(set-recovery-address (id uint) (recovery principal))
(recover-identity (id uint) (new-owner principal))
```

### NFT Management

```clarity
(add-nft (id uint) (nft-contract <sip009-nft-trait>) (token-id uint))
```

### Read-Only Functions

```clarity
(get-identity (id uint))
(get-identity-by-owner (owner principal))
(get-delegates (id uint))
(get-nfts (id uint) (nft-contract principal))
```

## Technical Specifications

### Username Requirements

- Length: 3-50 characters
- Allowed characters: alphanumeric (0-9, a-z, A-Z), hyphen (-), underscore (\_)
- Case-sensitive

### Public Key Requirements

- 33-byte compressed public key format
- Must be provided as a buffer

### Delegation Limits

- Maximum 10 delegates per identity
- Expiration period: 1 year maximum (based on block height)
- Cannot delegate to identity owner or zero address

### NFT Integration

- Supports SIP009-compliant NFTs
- Maximum 10 NFTs per contract per identity
- Requires ownership verification

## Error Codes

- `u100`: Owner-only operation
- `u101`: Entity not found
- `u102`: Unauthorized operation
- `u103`: Entity already exists
- `u104`: Operation expired
- `u105`: Invalid input

## Security Considerations

1. Delegate permissions expire based on block height
2. Recovery address system for identity recovery
3. Owner and delegate authorization checks
4. Input validation for all public functions
5. Protection against duplicate delegates and NFTs

## Contract Deployment

The contract requires initialization of the contract owner during deployment. The contract owner has administrative privileges and can:

- Set a new contract owner
- Disable identities (along with identity owners)

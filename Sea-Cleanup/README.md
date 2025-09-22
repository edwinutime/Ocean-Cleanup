# Ocean Cleanup Incentive System Smart Contract

A decentralized blockchain-based system that incentivizes ocean plastic cleanup by rewarding participants with tokens based on their verified cleanup contributions.

## Overview

This smart contract creates a transparent, verifiable system for tracking ocean cleanup efforts and distributing rewards to participants. The system uses a validator network to verify cleanup claims and prevent fraud while maintaining decentralization.

## Features

- **Cleanup Submission**: Participants can submit cleanup records with location, plastic amount, and photo evidence
- **Validator Network**: Staked validators verify cleanup submissions to ensure authenticity  
- **Token Rewards**: Automatic token distribution based on verified plastic removal amounts
- **Reputation System**: Track participant and validator reputation scores over time
- **Location Analytics**: Monitor cleanup activities by geographic location
- **Emergency Controls**: Administrative functions for contract management

## System Architecture

### Core Components

1. **Cleanup Records**: Store detailed information about each cleanup event
2. **Participant Stats**: Track individual performance and reputation
3. **Validator Registry**: Manage the network of cleanup verifiers
4. **Location Stats**: Aggregate cleanup data by location
5. **Token System**: Handle reward distribution and balances

### Reward Mechanism

- Base reward: 100 tokens per kilogram of plastic removed
- Verified cleanup bonus: 150% of base reward (50% bonus)
- Minimum cleanup amount: 1kg plastic
- Maximum cleanup amount: 10,000kg plastic per submission

## Getting Started

### For Participants

1. **Submit Cleanup**: Call `submit-cleanup` with location, plastic amount, and photo hash
2. **Wait for Verification**: Validators have 24 hours to verify your submission
3. **Receive Rewards**: Approved cleanups automatically receive token rewards
4. **Track Progress**: Use read-only functions to monitor your statistics

### For Validators

1. **Stake Tokens**: Call `register-validator` with minimum stake (10,000 tokens)
2. **Verify Cleanups**: Review submissions and call `verify-cleanup` 
3. **Earn Reputation**: Successful verifications increase your reputation score
4. **Withdraw Stake**: Call `withdraw-validator-stake` to leave the system

## Contract Functions

### Public Functions

#### Participant Functions
```clarity
(submit-cleanup (location (string-ascii 100)) (plastic-amount uint) (photo-hash (string-ascii 64)))
```
Submit a new cleanup record for verification.

#### Validator Functions
```clarity
(register-validator (stake-amount uint))
```
Register as a validator by staking tokens.

```clarity
(verify-cleanup (cleanup-id uint) (approved bool))
```
Verify a submitted cleanup as approved or rejected.

```clarity
(withdraw-validator-stake)
```
Withdraw staked tokens and deactivate validator status.

#### Administrative Functions
```clarity
(toggle-contract-status)
```
Pause or unpause the contract (owner only).

```clarity
(update-reward-pool (new-amount uint))
```
Adjust the reward pool amount (owner only).

```clarity
(emergency-withdraw)
```
Withdraw remaining reward pool (owner only, emergency use).

### Read-Only Functions

```clarity
(get-cleanup-details (cleanup-id uint))
```
Retrieve complete information about a specific cleanup.

```clarity
(get-participant-stats (participant principal))
```
Get statistics for a specific participant.

```clarity
(get-validator-info (validator principal))
```
Get information about a registered validator.

```clarity
(get-location-stats (location (string-ascii 100)))
```
Get cleanup statistics for a specific location.

```clarity
(get-token-balance (participant principal))
```
Check token balance for any address.

```clarity
(get-global-stats)
```
Get overall contract statistics including total plastic removed and rewards distributed.

```clarity
(estimate-reward (plastic-amount uint) (will-be-verified bool))
```
Calculate potential reward for a given cleanup amount.

## Data Structures

### Cleanup Record
- `participant`: Address of person who performed cleanup
- `location`: Geographic location of cleanup
- `plastic-amount`: Kilograms of plastic removed
- `timestamp`: Block height when submitted
- `verified`: Whether cleanup has been verified
- `verifier`: Validator who verified the cleanup
- `reward-amount`: Tokens earned from cleanup
- `photo-hash`: IPFS hash of cleanup photo evidence

### Participant Stats
- `total-cleanups`: Number of cleanups performed
- `total-plastic`: Total plastic removed in kg
- `total-rewards`: Total tokens earned
- `reputation-score`: Calculated based on activity
- `joined-at`: Block height of first participation

### Validator Info
- `stake-amount`: Tokens staked by validator
- `verifications-count`: Number of cleanups verified
- `reputation`: Validator reputation score
- `active`: Current validator status

## Constants and Limits

- **Minimum plastic amount**: 1kg per cleanup
- **Maximum plastic amount**: 10,000kg per cleanup
- **Reward rate**: 100 tokens per kg
- **Verification bonus**: 50% additional reward
- **Verification deadline**: 144 blocks (approximately 24 hours)
- **Minimum validator stake**: 10,000 tokens
- **Maximum reputation score**: 1,000 points
- **Photo hash length**: 32-64 characters

## Error Codes

- `u100`: Not authorized
- `u101`: Invalid amount
- `u102`: Insufficient funds
- `u103`: User not found
- `u104`: Cleanup not found
- `u105`: Already verified
- `u106`: Invalid location
- `u107`: Reward calculation error
- `u108`: Transfer failed
- `u109`: Invalid validator
- `u110`: Cleanup expired

## Security Features

- **Validator Staking**: Validators must stake tokens to participate
- **Time Limits**: Cleanups expire if not verified within 24 hours
- **Authorization Checks**: Admin functions restricted to contract owner
- **Input Validation**: All inputs validated for proper format and ranges
- **Emergency Controls**: Contract can be paused in case of issues

## Deployment Requirements

- Clarity smart contract runtime
- Initial reward pool funding
- Contract owner private key for administration
- IPFS infrastructure for photo storage (off-chain)

## Usage Examples

### Submit a Cleanup
```clarity
(contract-call? .ocean-cleanup submit-cleanup 
    "Pacific Ocean, 34.0522N 118.2437W" 
    u25 
    "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG")
```

### Verify a Cleanup
```clarity
(contract-call? .ocean-cleanup verify-cleanup u1 true)
```

### Check Your Balance
```clarity
(contract-call? .ocean-cleanup get-token-balance tx-sender)
```
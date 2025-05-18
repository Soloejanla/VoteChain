# VoteChain

A decentralized governance and voting platform where users can create and participate in transparent, tamper-proof voting processes.

## Overview

VoteChain is a Clarity smart contract that enables decentralized governance on the Stacks blockchain. It allows users to create proposals and vote on topics they care about, with transparent vote counting and direct incentives for participation.

## Features

- **Interest-Based Voting**: Users vote on proposals matching their interests
- **Vote Power**: Users earn voting power for participation
- **No Intermediaries**: Proposal creators connect directly with voters
- **Transparent Fee Structure**: Small system fee to sustain the ecosystem
- **Proposal Management**: Creators can create, close, and manage proposals

## Contract Functions

### User Functions

- `register-voter`: Register as a new voter with topic interests
- `update-interests`: Update your topic interests
- `deactivate-voter`: Temporarily deactivate your voting status
- `reactivate-voter`: Re-enable voting after deactivation
- `cast-vote`: Vote on a proposal and receive voting power
- `claim-vote-power`: Withdraw your earned STX tokens

### Proposal Creator Functions

- `create-proposal`: Create a new proposal for voting
- `close-proposal`: Temporarily close an active proposal
- `reopen-proposal`: Reopen a closed proposal
- `increase-threshold`: Add more threshold to an existing proposal

### Admin Functions

- `set-contract-owner`: Update the contract administrator
- `set-system-fee`: Adjust the system fee percentage
- `add-topic`: Add a new voting topic
- `withdraw-system-fees`: Withdraw accumulated system fees

### Read-Only Functions

- `get-voter-profile`: View a voter's profile and interests
- `get-proposal`: Get details about a proposal
- `get-topic`: Get information about a voting topic
- `get-system-fee`: Check the current system fee percentage
- `get-system-balance`: View the accumulated system fees
- `get-vote-record`: Check if a user has voted on a specific proposal

## How It Works

1. **For Voters**:
   - Register with your topic interests
   - Vote on proposals that match your interests
   - Earn voting power for participation
   - Claim your voting power as STX tokens anytime

2. **For Proposal Creators**:
   - Create proposals with a threshold and vote weight
   - Target specific topic areas
   - Get votes from interested participants
   - Manage proposals with close/reopen functionality

## Governance Features

- Users only vote on proposals matching their stated interests
- All votes are recorded on-chain for transparency
- Users can opt-out at any time
- All interactions are pseudonymous via blockchain addresses

## Development

This contract is developed using Clarity and can be tested with Clarinet.
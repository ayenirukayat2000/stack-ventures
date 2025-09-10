# Stack Ventures Smart Contract

A comprehensive Clarity smart contract that combines freelance marketplace, crowdfunding, and DAO governance functionality on the Stacks blockchain.

## Features

- **Job Management**
  - Post jobs with budget and milestones
  - Apply for jobs as freelancers
  - Fund jobs with STX tokens

- **Milestone System**
  - Milestone-based payment structure
  - Backer voting on milestone completion
  - Secure payment releases

- **DAO Governance**
  - Create proposals
  - Democratic voting system
  - Proposal execution based on majority

- **Reputation System**
  - Track user reputation scores
  - Update reputation based on performance

## Contract Functions

### Job Functions
- `post-job`: Create a new job listing
- `apply-job`: Apply for an open job
- `fund-job`: Fund a job with STX

### Milestone Functions
- `vote-milestone`: Vote on milestone completion
- `release-milestone`: Release payment for approved milestone

### DAO Functions
- `create-proposal`: Create new governance proposal
- `vote-proposal`: Vote on existing proposals
- `execute-proposal`: Execute approved proposals

### Reputation Functions
- `update-reputation`: Update user reputation scores

## Error Handling

The contract includes comprehensive error handling:
- Invalid job/proposal IDs
- Unauthorized actions
- Double voting prevention
- Invalid budget/milestone validation

## Data Structure

```clarity
jobs: {
  client: principal,
  freelancer: optional(principal),
  budget: uint,
  milestone: uint,
  funded: bool,
  status: string-ascii
}

milestones: {
  amount: uint,
  approved: bool,
  released: bool
}

proposals: {
  proposer: principal,
  description: string-ascii,
  votes-for: uint,
  votes-against: uint,
  executed: bool
}
```

## Getting Started

1. Deploy the contract to Stacks blockchain
2. Initialize with appropriate test cases
3. Interact through contract calls

## Security

- Protected function calls
- Proper validation checks
- Safe STX transfers
- Anti-manipulation safeguards

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

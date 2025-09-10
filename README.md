# Interoperability Bridge Contract

A secure Clarity smart contract that enables cross-chain asset transfers between Stacks and other supported blockchain networks (Ethereum, BSC, Polygon).

## Features

### Core Functionality
- **Cross-chain Asset Transfers**: Lock STX on Stacks and unlock equivalent assets on target chains
- **Multi-signature Validation**: Requires multiple validator approvals for enhanced security
- **Bidirectional Transfers**: Support for both outgoing and incoming transfers
- **Fee Collection**: Configurable bridge fees to sustain operations

### Security Features
- **Pause Mechanism**: Emergency pause functionality for security incidents
- **Transfer Limits**: Configurable minimum and maximum transfer amounts
- **Duplicate Protection**: Prevents replay attacks and duplicate transactions
- **Validator Management**: Owner-controlled validator addition/removal
- **Input Validation**: Comprehensive bounds checking for all parameters

## Contract Architecture

### Key Components
- **Validators**: Trusted entities that validate cross-chain transactions
- **Pending Transfers**: Queue system for outgoing transfers awaiting validation
- **Signature Tracking**: Multi-signature validation with configurable thresholds
- **Chain Support**: Whitelist of supported destination chains

### Supported Chains
- Ethereum (Chain ID: 1)
- BSC (Chain ID: 56) 
- Polygon (Chain ID: 137)

## Usage

### For Users

#### Initiate Cross-chain Transfer
```clarity
(contract-call? .bridge initiate-transfer amount target-chain-id recipient-address)
```
- `amount`: STX amount to transfer (in microSTX)
- `target-chain-id`: Destination blockchain ID
- `recipient-address`: 32-byte recipient address on target chain

### For Validators

#### Validate Outgoing Transfer
```clarity
(contract-call? .bridge validate-transfer transfer-id)
```

#### Complete Incoming Transfer
```clarity
(contract-call? .bridge complete-incoming-transfer amount recipient source-chain tx-hash)
```

### For Contract Owner

#### Add/Remove Validators
```clarity
(contract-call? .bridge add-validator validator-principal)
(contract-call? .bridge remove-validator validator-principal)
```

#### Configure Bridge Settings
```clarity
(contract-call? .bridge set-transfer-limits min-amount max-amount)
(contract-call? .bridge set-bridge-fee fee-amount)
(contract-call? .bridge set-required-signatures signature-count)
```

## Configuration

### Default Settings
- **Minimum Transfer**: 1 STX (1,000,000 microSTX)
- **Maximum Transfer**: 1,000 STX (100,000,000,000 microSTX)
- **Bridge Fee**: 0.01 STX (10,000 microSTX)
- **Required Signatures**: 3 validators
- **Initial Validator**: Contract deployer

### Limits
- **Maximum Fee**: 1 STX
- **Maximum Transfer**: 10,000 STX
- **Signature Range**: 1-10 validators
- **Chain ID Range**: 1-1,000,000

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 100  | ERR_UNAUTHORIZED | Only contract owner can perform this action |
| 101  | ERR_INVALID_AMOUNT | Transfer amount outside allowed limits |
| 102  | ERR_BRIDGE_PAUSED | Bridge is currently paused |
| 103  | ERR_INSUFFICIENT_BALANCE | Insufficient STX balance |
| 104  | ERR_INVALID_CHAIN | Unsupported target chain |
| 105  | ERR_DUPLICATE_TX | Transaction already processed |
| 106  | ERR_VALIDATOR_EXISTS | Validator already exists |
| 107  | ERR_NOT_VALIDATOR | Address is not a validator |
| 108  | ERR_INSUFFICIENT_SIGNATURES | Not enough validator signatures |
| 109  | ERR_INVALID_INPUT | Invalid input parameter |

## Events

### Transfer Events
- `transfer-initiated`: New transfer request created
- `signature-added`: Validator signature added to transfer
- `transfer-validated`: Transfer approved by validators
- `incoming-transfer-completed`: Incoming transfer processed

### Administrative Events  
- `bridge-deployed`: Contract successfully deployed

## Read-Only Functions

- `get-transfer-info(transfer-id)`: Get pending transfer details
- `get-signature-count(transfer-id)`: Get current signature count
- `is-validator(address)`: Check if address is validator
- `is-chain-supported(chain-id)`: Check if chain is supported
- `get-bridge-config()`: Get current bridge configuration
- `is-transaction-processed(chain-id, tx-hash)`: Check if transaction processed
- `get-contract-balance()`: Get contract STX balance

## Security Considerations

### Best Practices
- Always verify transaction details before validation
- Monitor for unusual transfer patterns
- Regularly review validator set
- Keep minimum required signatures ≥ 3
- Use pause mechanism during security incidents

### Risk Mitigation
- Multi-signature validation prevents single points of failure
- Transfer limits reduce exposure to large losses
- Duplicate protection prevents replay attacks
- Input validation prevents malformed data exploitation

## Deployment

1. Deploy contract to Stacks blockchain
2. Add initial validators using `add-validator`
3. Configure transfer limits and fees
4. Add supported chains if needed
5. Test with small amounts before production use


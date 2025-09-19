# Decentralized Nutrition Coaching Smart Contract

A Clarity smart contract for decentralized nutrition coaching that combines AI-powered recommendations with professional dietitian verification on the Stacks blockchain.

## Overview

This smart contract enables a decentralized platform where users can receive personalized nutrition advice through two pathways:
1. **AI-Powered Recommendations**: Free, instant nutrition guidance based on user profiles
2. **Verified Dietitian Consultations**: Professional, personalized consultations with certified nutrition experts

## Key Features

### User Management
- Comprehensive health profiles with metrics tracking
- Dynamic profile updates for changing health goals
- Secure balance management for consultation payments

### Dietitian Ecosystem
- Professional registration with credential verification
- Flexible hourly rate setting
- Performance tracking with automatic rating aggregation

### Consultation System
- Multiple consultation types: ai-only, verified, custom
- Secure escrow payment system
- Complete status lifecycle management

### Quality Assurance
- 5-star rating system with detailed reviews
- Automatic dietitian performance calculation
- Comprehensive nutrition plan creation
- Time-bound plan validity tracking

## Contract Architecture

### Data Structures

#### User Profiles
```clarity
{
  name: (string-ascii 50),
  age: uint,
  height: uint,        // in cm
  weight: uint,        // in kg
  activity-level: (string-ascii 20),
  dietary-restrictions: (string-ascii 100),
  health-goals: (string-ascii 100),
  created-at: uint
}
```

#### Dietitian Profiles
```clarity
{
  name: (string-ascii 50),
  credentials: (string-ascii 100),
  specialization: (string-ascii 50),
  hourly-rate: uint,
  total-consultations: uint,
  average-rating: uint,
  is-verified: bool,
  is-active: bool
}
```

#### Consultations
```clarity
{
  client: principal,
  dietitian: principal,
  ai-recommendation: (string-ascii 500),
  dietitian-feedback: (string-ascii 500),
  consultation-type: (string-ascii 20),
  amount-paid: uint,
  status: (string-ascii 20),
  created-at: uint,
  completed-at: (optional uint),
  rating: (optional uint)
}
```

## Core Functions

### User Functions

#### Profile Management
- `create-user-profile`: Initialize user health profile
- `update-user-profile`: Modify existing profile data
- `get-user-profile`: Retrieve user profile information

#### Balance Management  
- `deposit-funds`: Add STX to user balance for consultations
- `withdraw-funds`: Withdraw unused balance
- `get-user-balance`: Check current balance

#### Consultation Requests
- `request-ai-consultation`: Get free AI-powered nutrition advice
- `request-verified-consultation`: Book paid consultation with verified dietitian
- `rate-consultation`: Provide feedback and rating after consultation

### Dietitian Functions

#### Registration & Management
- `register-dietitian`: Create professional profile
- `update-dietitian-rate`: Modify consultation pricing
- `complete-consultation`: Provide professional feedback and complete consultation

#### Nutrition Planning
- `create-nutrition-plan`: Develop comprehensive nutrition plans with meal details, calorie targets, and validity periods

### Admin Functions

#### Quality Control
- `verify-dietitian`: Approve professional credentials
- `deactivate-dietitian`: Remove dietitians from active status
- `set-platform-fee-rate`: Adjust platform commission (max 10%)

## Economic Model

### Fee Structure
- **Platform Fee**: Default 5% (500 basis points) of consultation fees
- **AI Consultations**: Completely free to encourage platform adoption
- **Verified Consultations**: Dietitian-set hourly rates plus platform fee

### Payment Flow
1. User deposits STX into contract balance
2. Consultation request locks required payment in escrow
3. Upon completion, payment is distributed:
   - Dietitian receives consultation fee minus platform fee
   - Platform retains fee for operational costs
4. Unused funds remain withdrawable by users

## Security Features

### Access Control
- **User Authorization**: Profile and balance management restricted to account owners
- **Dietitian Authorization**: Only registered dietitians can complete consultations
- **Admin Authorization**: Critical functions limited to contract owner

### Validation Systems
- **Balance Verification**: Sufficient funds checked before consultation booking
- **Status Validation**: Consultation state transitions properly managed
- **Rating Integrity**: Prevents duplicate ratings and invalid scores
- **Input Sanitization**: String length limits prevent overflow attacks

### Error Handling
```clarity
ERR_UNAUTHORIZED (u100)           // Access denied
ERR_NOT_FOUND (u101)             // Resource doesn't exist  
ERR_ALREADY_EXISTS (u102)        // Duplicate creation attempt
ERR_INVALID_AMOUNT (u103)        // Invalid payment amount
ERR_INSUFFICIENT_BALANCE (u104)   // Insufficient user funds
ERR_CONSULTATION_NOT_PENDING (u105) // Invalid consultation state
ERR_INVALID_RATING (u106)        // Rating outside 1-5 range
ERR_ALREADY_RATED (u107)         // Duplicate rating attempt
```

## Deployment Guide

### Prerequisites
- Stacks blockchain testnet/mainnet access
- Clarity CLI or compatible deployment tool
- STX tokens for deployment transaction fees

### Deployment Steps

1. **Contract Deployment**
```bash
clarity-cli deploy --contract-name nutrition-coaching --contract-file nutrition-coaching.clar
```

2. **Initial Configuration**
```bash
# Set platform fee (5%)
(contract-call? .nutrition-coaching set-platform-fee-rate u500)
```

## Integration Examples

### User Registration
```javascript
const createProfile = async (profileData) => {
  const tx = await stacksTransaction({
    contractAddress: CONTRACT_ADDRESS,
    contractName: 'nutrition-coaching',
    functionName: 'create-user-profile',
    functionArgs: [
      stringAsciiCV(profileData.name),
      uintCV(profileData.age),
      uintCV(profileData.height),
      uintCV(profileData.weight),
      stringAsciiCV(profileData.activityLevel),
      stringAsciiCV(profileData.dietaryRestrictions),
      stringAsciiCV(profileData.healthGoals)
    ]
  });
  return await broadcastTransaction(tx);
};
```

### Consultation Booking
```javascript
const bookConsultation = async (dietitianAddress, aiRecommendation) => {
  const tx = await stacksTransaction({
    contractAddress: CONTRACT_ADDRESS,
    contractName: 'nutrition-coaching', 
    functionName: 'request-verified-consultation',
    functionArgs: [
      principalCV(dietitianAddress),
      stringAsciiCV(aiRecommendation)
    ]
  });
  return await broadcastTransaction(tx);
};
```

## Testing

### Unit Tests
```clarity
;; Test user profile creation
(define-public (test-create-profile)
  (let ((result (create-user-profile "John Doe" u30 u175 u70 "moderate" "no gluten" "weight loss")))
    (asserts! (is-ok result) (err "Profile creation failed"))))
```

## License

This project is licensed under the MIT License.
# 🎯 Ad Slot Auction DApp

> A decentralized marketplace for advertising slots on the Stacks blockchain

## 🌟 Overview

The Ad Slot Auction DApp revolutionizes digital advertising by creating a **decentralized marketplace** where creators can auction advertising slots and advertisers can bid using STX tokens. This eliminates the need for centralized platforms and creates fair market pricing.

### ✨ Key Features

- 🏗️ **Create Ad Slots**: Creators can create advertising spaces with custom parameters
- 💰 **STX Bidding**: Advertisers bid using STX tokens in real-time auctions
- ⏰ **Time-based Auctions**: Automatic auction ending based on block height
- 🎨 **Flexible Slots**: Support for websites, apps, NFTs, and any digital space
- 🔒 **Secure Payments**: All funds are held in smart contract escrow
- 📊 **Transparent**: All bids and transactions are on-chain and verifiable
- 💸 **Commission System**: 5% platform fee for sustainable ecosystem

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://docs.hiro.so/clarinet) installed
- [Node.js](https://nodejs.org/) for testing
- STX wallet (Hiro Wallet, Xverse, etc.)

### Installation

```bash
git clone <your-repo-url>
cd Ad-Slot-Auction-DApp
clarinet check
npm install
npm test
```

## 📋 Contract Functions

### 🏗️ Core Functions

#### `create-ad-slot`
Create a new advertising slot for auction

```clarity
(contract-call? .Ad-Slot-Auction-DApp create-ad-slot 
  "Banner Ad - Homepage" 
  "Premium banner position on homepage - 1M monthly views"
  u1000000  ;; 1 STX minimum bid
  u1000     ;; Duration in blocks (~1 week)
)
```

**Parameters:**
- `title`: Slot title (max 100 chars)
- `description`: Detailed description (max 500 chars)
- `min-bid`: Minimum bid amount in microSTX
- `duration-blocks`: Auction duration in blocks

#### `place-bid`
Place a bid on an active auction

```clarity
(contract-call? .Ad-Slot-Auction-DApp place-bid 
  u1        ;; slot-id
  u2000000  ;; bid amount in microSTX
)
```

**Requirements:**
- Auction must be active
- Bid must exceed minimum bid
- Bid must be higher than current highest bid
- Sufficient STX balance

#### `finalize-auction`
Finalize an ended auction and distribute payments

```clarity
(contract-call? .Ad-Slot-Auction-DApp finalize-auction u1)
```

**Effects:**
- Transfers winning bid to creator (minus 5% commission)
- Transfers commission to contract owner
- Marks auction as finalized

### 🛠️ Management Functions

#### `cancel-auction`
Cancel an active auction (creator only)

```clarity
(contract-call? .Ad-Slot-Auction-DApp cancel-auction u1)
```

#### `extend-auction`
Extend auction duration (creator only)

```clarity
(contract-call? .Ad-Slot-Auction-DApp extend-auction u1 u500) ;; Add 500 blocks
```

#### `withdraw-balance`
Withdraw refunded bids from failed auctions

```clarity
(contract-call? .Ad-Slot-Auction-DApp withdraw-balance)
```

### 🔍 Read-Only Functions

#### `get-ad-slot`
Retrieve complete slot information

```clarity
(contract-call? .Ad-Slot-Auction-DApp get-ad-slot u1)
```

#### `get-auction-status`
Get current auction status

```clarity
(contract-call? .Ad-Slot-Auction-DApp get-auction-status u1)
```

#### `get-time-remaining`
Get blocks remaining in auction

```clarity
(contract-call? .Ad-Slot-Auction-DApp get-time-remaining u1)
```

#### `is-auction-active`
Check if auction is currently active

```clarity
(contract-call? .Ad-Slot-Auction-DApp is-auction-active u1)
```

## 💡 Usage Examples

### 📝 Creating Your First Ad Slot

1. **Blog Owner** creates a sidebar ad slot:
   ```clarity
   (contract-call? .Ad-Slot-Auction-DApp create-ad-slot
     "Sidebar Banner - Tech Blog"
     "300x250 sidebar ad on popular tech blog, 50K monthly visitors"
     u500000   ;; 0.5 STX minimum
     u2016     ;; ~2 weeks duration
   )
   ```

2. **Advertisers** compete by placing bids:
   ```clarity
   ;; Advertiser A bids 0.8 STX
   (contract-call? .Ad-Slot-Auction-DApp place-bid u1 u800000)
   
   ;; Advertiser B bids 1.2 STX
   (contract-call? .Ad-Slot-Auction-DApp place-bid u1 u1200000)
   ```

3. **After auction ends**, anyone can finalize:
   ```clarity
   (contract-call? .Ad-Slot-Auction-DApp finalize-auction u1)
   ```

### 🎮 NFT Project Ad Slot

```clarity
;; Create slot for NFT project promotion
(contract-call? .Ad-Slot-Auction-DApp create-ad-slot
  "Featured NFT Spotlight"
  "Homepage hero section featuring NFT project for 30 days"
  u5000000  ;; 5 STX minimum
  u4320     ;; ~1 month duration
)
```

### 📱 Mobile App Ad Space

```clarity
;; Create interstitial ad slot
(contract-call? .Ad-Slot-Auction-DApp create-ad-slot
  "Mobile App Interstitial"
  "Full-screen ad in popular mobile game, 100K daily users"
  u2000000  ;; 2 STX minimum
  u720      ;; ~5 days duration
)
```

## 🔧 Testing

Run the comprehensive test suite:

```bash
npm test
```

Tests cover:
- ✅ Slot creation and validation
- ✅ Bidding mechanics and edge cases
- ✅ Auction finalization and payments
- ✅ Access control and security
- ✅ Error handling

## 🏗️ Contract Architecture

### 📊 Data Structures

- **`ad-slots`**: Core auction data (creator, bids, timing)
- **`slot-bids`**: Individual bid tracking
- **`user-balances`**: Refund management

### 🛡️ Security Features

- **Access Control**: Creator-only functions protected
- **Reentrancy Protection**: Safe STX transfer patterns
- **Bid Validation**: Multiple checks prevent invalid bids
- **Escrow System**: Funds held securely until finalization

### 💰 Economics

- **Commission Rate**: 5% platform fee
- **Refund System**: Outbid amounts automatically refunded
- **Gas Optimization**: Efficient data structures and operations

## 🌐 Deployment

### Testnet Deployment

```bash
clarinet publish --testnet
```

### Mainnet Deployment

```bash
clarinet publish --mainnet
```

## 🤝 Contributing

Contributions are welcome! Please:

1. 🔀 Fork the repository
2. 🌿 Create a feature branch
3. ✅ Add tests for new functionality
4. 📝 Update documentation
5. 🔍 Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 🔗 Links

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language Reference](https://docs.stacks.co/clarity/)
- [Clarinet Documentation](https://docs.hiro.so/clarinet)

---

**Built with ❤️ on Stacks blockchain** 🔗

# Ad Slot Auction DApp


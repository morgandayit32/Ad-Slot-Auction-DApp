
;; Ad Slot Auction DApp
;; A decentralized marketplace for advertising slots

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_SLOT_NOT_FOUND (err u404))
(define-constant ERR_AUCTION_ENDED (err u400))
(define-constant ERR_AUCTION_ACTIVE (err u401))
(define-constant ERR_BID_TOO_LOW (err u402))
(define-constant ERR_INSUFFICIENT_FUNDS (err u403))
(define-constant ERR_AUCTION_NOT_ENDED (err u405))
(define-constant ERR_ALREADY_FINALIZED (err u406))
(define-constant ERR_NO_BIDS (err u407))
(define-constant ERR_BUY_NOW_NOT_SET (err u408))
(define-constant ERR_INSUFFICIENT_BUY_NOW_AMOUNT (err u409))
(define-constant COMMISSION_RATE u5)

;; Data Variables
(define-data-var slot-counter uint u0)
(define-data-var bid-history-counter uint u0)

;; Data Maps
(define-map ad-slots
  uint
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    min-bid: uint,
    auction-end: uint,
    highest-bidder: (optional principal),
    highest-bid: uint,
    finalized: bool,
    active: bool,
    buy-now-price: (optional uint)
  }
)

(define-map slot-bids
  { slot-id: uint, bidder: principal }
  { bid-amount: uint, bid-time: uint }
)

(define-map user-balances
  principal
  uint
)

(define-map bid-history
  { slot-id: uint, bid-index: uint }
  { bidder: principal, amount: uint, timestamp: uint }
)

(define-map slot-bid-count
  uint
  uint
)

;; Private Functions
(define-private (transfer-stx (amount uint) (from principal) (to principal))
  (stx-transfer? amount from to)
)

(define-private (get-balance (user principal))
  (default-to u0 (map-get? user-balances user))
)

(define-private (set-balance (user principal) (amount uint))
  (map-set user-balances user amount)
)

(define-private (increment-balance (user principal) (amount uint))
  (let ((current-balance (get-balance user)))
    (set-balance user (+ current-balance amount))
  )
)

(define-private (decrement-balance (user principal) (amount uint))
  (let ((current-balance (get-balance user)))
    (if (>= current-balance amount)
      (begin
        (set-balance user (- current-balance amount))
        (ok true)
      )
      (err u403)
    )
  )
)

(define-private (calculate-commission (amount uint))
  (/ (* amount COMMISSION_RATE) u100)
)

(define-private (is-auction-ended (end-block uint))
  (<= end-block stacks-block-height)
)

(define-private (get-slot-bid-count (slot-id uint))
  (default-to u0 (map-get? slot-bid-count slot-id))
)

(define-private (record-bid-history (slot-id uint) (bidder principal) (amount uint))
  (let (
    (current-count (get-slot-bid-count slot-id))
    (next-index (+ current-count u1))
  )
    (begin
      (map-set bid-history
        { slot-id: slot-id, bid-index: next-index }
        { bidder: bidder, amount: amount, timestamp: stacks-block-height }
      )
      (map-set slot-bid-count slot-id next-index)
      true
    )
  )
)

;; Public Functions
(define-public (create-ad-slot (title (string-ascii 100)) (description (string-ascii 500)) (min-bid uint) (duration-blocks uint) (buy-now-price (optional uint)))
  (let (
    (slot-id (+ (var-get slot-counter) u1))
    (auction-end (+ stacks-block-height duration-blocks))
  )
    (begin
      (map-set ad-slots slot-id {
        creator: tx-sender,
        title: title,
        description: description,
        min-bid: min-bid,
        auction-end: auction-end,
        highest-bidder: none,
        highest-bid: u0,
        finalized: false,
        active: true,
        buy-now-price: buy-now-price
      })
      (var-set slot-counter slot-id)
      (ok slot-id)
    )
  )
)

(define-public (place-bid (slot-id uint) (bid-amount uint))
  (let (
    (slot-data (unwrap! (map-get? ad-slots slot-id) ERR_SLOT_NOT_FOUND))
    (current-balance (stx-get-balance tx-sender))
  )
    (asserts! (get active slot-data) ERR_AUCTION_ENDED)
    (asserts! (not (is-auction-ended (get auction-end slot-data))) ERR_AUCTION_ENDED)
    (asserts! (>= bid-amount (get min-bid slot-data)) ERR_BID_TOO_LOW)
    (asserts! (> bid-amount (get highest-bid slot-data)) ERR_BID_TOO_LOW)
    (asserts! (>= current-balance bid-amount) ERR_INSUFFICIENT_FUNDS)
    
    (let (
      (previous-bidder (get highest-bidder slot-data))
      (previous-bid (get highest-bid slot-data))
    )
      (begin
        (if (is-some previous-bidder)
          (increment-balance (unwrap-panic previous-bidder) previous-bid)
          true
        )
        
        (try! (transfer-stx bid-amount tx-sender (as-contract tx-sender)))
        
        (map-set ad-slots slot-id (merge slot-data {
          highest-bidder: (some tx-sender),
          highest-bid: bid-amount
        }))
        
        (map-set slot-bids
          { slot-id: slot-id, bidder: tx-sender }
          { bid-amount: bid-amount, bid-time: stacks-block-height }
        )
        
        (record-bid-history slot-id tx-sender bid-amount)
        
        (ok true)
      )
    )
  )
)

(define-public (buy-now (slot-id uint))
  (let (
    (slot-data (unwrap! (map-get? ad-slots slot-id) ERR_SLOT_NOT_FOUND))
    (buy-price (unwrap! (get buy-now-price slot-data) ERR_BUY_NOW_NOT_SET))
    (current-balance (stx-get-balance tx-sender))
  )
    (asserts! (get active slot-data) ERR_AUCTION_ENDED)
    (asserts! (not (get finalized slot-data)) ERR_ALREADY_FINALIZED)
    (asserts! (>= current-balance buy-price) ERR_INSUFFICIENT_FUNDS)
    
    (let (
      (creator (get creator slot-data))
      (commission (calculate-commission buy-price))
      (creator-payment (- buy-price commission))
      (previous-bidder (get highest-bidder slot-data))
      (previous-bid (get highest-bid slot-data))
    )
      (begin
        (if (is-some previous-bidder)
          (try! (as-contract (transfer-stx previous-bid tx-sender (unwrap-panic previous-bidder))))
          true
        )
        
        (try! (transfer-stx buy-price tx-sender (as-contract tx-sender)))
        (try! (as-contract (transfer-stx creator-payment tx-sender creator)))
        (try! (as-contract (transfer-stx commission tx-sender CONTRACT_OWNER)))
        
        (map-set ad-slots slot-id (merge slot-data {
          highest-bidder: (some tx-sender),
          highest-bid: buy-price,
          finalized: true,
          active: false
        }))
        
        (record-bid-history slot-id tx-sender buy-price)
        
        (ok {
          buyer: tx-sender,
          price: buy-price,
          creator-payment: creator-payment,
          commission: commission
        })
      )
    )
  )
)

(define-public (finalize-auction (slot-id uint))
  (let (
    (slot-data (unwrap! (map-get? ad-slots slot-id) ERR_SLOT_NOT_FOUND))
  )
    (asserts! (is-auction-ended (get auction-end slot-data)) ERR_AUCTION_NOT_ENDED)
    (asserts! (not (get finalized slot-data)) ERR_ALREADY_FINALIZED)
    (asserts! (is-some (get highest-bidder slot-data)) ERR_NO_BIDS)
    
    (let (
      (winner (unwrap-panic (get highest-bidder slot-data)))
      (winning-bid (get highest-bid slot-data))
      (creator (get creator slot-data))
      (commission (calculate-commission winning-bid))
      (creator-payment (- winning-bid commission))
    )
      (begin
        (try! (as-contract (transfer-stx creator-payment tx-sender creator)))
        (try! (as-contract (transfer-stx commission tx-sender CONTRACT_OWNER)))
        
        (map-set ad-slots slot-id (merge slot-data {
          finalized: true,
          active: false
        }))
        
        (ok {
          winner: winner,
          winning-bid: winning-bid,
          creator-payment: creator-payment,
          commission: commission
        })
      )
    )
  )
)

(define-public (cancel-auction (slot-id uint))
  (let (
    (slot-data (unwrap! (map-get? ad-slots slot-id) ERR_SLOT_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (get creator slot-data)) ERR_UNAUTHORIZED)
    (asserts! (not (get finalized slot-data)) ERR_ALREADY_FINALIZED)
    (asserts! (get active slot-data) ERR_AUCTION_ENDED)
    
    (let (
      (highest-bidder-opt (get highest-bidder slot-data))
      (highest-bid (get highest-bid slot-data))
    )
      (begin
        (if (is-some highest-bidder-opt)
          (try! (as-contract (transfer-stx highest-bid tx-sender (unwrap-panic highest-bidder-opt))))
          true
        )
        
        (map-set ad-slots slot-id (merge slot-data {
          active: false,
          finalized: true
        }))
        
        (ok true)
      )
    )
  )
)

(define-public (extend-auction (slot-id uint) (additional-blocks uint))
  (let (
    (slot-data (unwrap! (map-get? ad-slots slot-id) ERR_SLOT_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (get creator slot-data)) ERR_UNAUTHORIZED)
    (asserts! (get active slot-data) ERR_AUCTION_ENDED)
    (asserts! (not (get finalized slot-data)) ERR_ALREADY_FINALIZED)
    
    (let (
      (new-end (+ (get auction-end slot-data) additional-blocks))
    )
      (begin
        (map-set ad-slots slot-id (merge slot-data {
          auction-end: new-end
        }))
        (ok new-end)
      )
    )
  )
)

(define-public (withdraw-balance)
  (let (
    (balance (get-balance tx-sender))
  )
    (asserts! (> balance u0) ERR_INSUFFICIENT_FUNDS)
    (begin
      (try! (as-contract (transfer-stx balance tx-sender tx-sender)))
      (set-balance tx-sender u0)
      (ok balance)
    )
  )
)

;; Read-only Functions
(define-read-only (get-ad-slot (slot-id uint))
  (map-get? ad-slots slot-id)
)

(define-read-only (get-slot-bid (slot-id uint) (bidder principal))
  (map-get? slot-bids { slot-id: slot-id, bidder: bidder })
)

(define-read-only (get-user-balance (user principal))
  (get-balance user)
)

(define-read-only (get-slot-counter)
  (var-get slot-counter)
)

(define-read-only (is-auction-active (slot-id uint))
  (match (map-get? ad-slots slot-id)
    slot-data (and (get active slot-data) (not (is-auction-ended (get auction-end slot-data))))
    false
  )
)

(define-read-only (get-time-remaining (slot-id uint))
  (match (map-get? ad-slots slot-id)
    slot-data 
      (let ((end-block (get auction-end slot-data)))
        (if (> end-block stacks-block-height)
          (ok (- end-block stacks-block-height))
          (ok u0)
        )
      )
    ERR_SLOT_NOT_FOUND
  )
)

(define-read-only (get-auction-status (slot-id uint))
  (match (map-get? ad-slots slot-id)
    slot-data {
      active: (get active slot-data),
      finalized: (get finalized slot-data),
      ended: (is-auction-ended (get auction-end slot-data)),
      has-bids: (is-some (get highest-bidder slot-data))
    }
    { active: false, finalized: false, ended: true, has-bids: false }
  )
)

(define-read-only (get-bid-history-entry (slot-id uint) (bid-index uint))
  (map-get? bid-history { slot-id: slot-id, bid-index: bid-index })
)

(define-read-only (get-total-bids (slot-id uint))
  (ok (get-slot-bid-count slot-id))
)

(define-read-only (get-bid-history-range (slot-id uint) (start-index uint) (end-index uint))
  (ok {
    start: start-index,
    end: end-index,
    total-bids: (get-slot-bid-count slot-id)
  })
)


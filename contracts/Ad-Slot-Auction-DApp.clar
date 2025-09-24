
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
(define-constant COMMISSION_RATE u5)

;; Data Variables
(define-data-var slot-counter uint u0)

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
    active: bool
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

;; Public Functions
(define-public (create-ad-slot (title (string-ascii 100)) (description (string-ascii 500)) (min-bid uint) (duration-blocks uint))
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
        active: true
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
        
        (ok true)
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


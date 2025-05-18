;; VoteChain - A decentralized governance and voting platform
;; Users can create and participate in transparent, tamper-proof voting processes

;; Data storage
(define-map voter-profiles principal {
  active: bool,
  interests: (list 10 uint),
  vote-power: uint,
  last-vote: uint,
  vote-count: uint
})

(define-map proposals uint {
  creator: principal,
  threshold: uint,
  vote-weight: uint,
  active: bool,
  topic: uint,
  total-votes: uint,
  created-at: uint
})

(define-map vote-records {voter: principal, proposal-id: uint} {
  timestamp: uint,
  counted: bool
})

(define-map topics uint (string-ascii 64))

;; Constants
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_PARAMS (err u101))
(define-constant ERR_VOTER_NOT_FOUND (err u102))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u103))
(define-constant ERR_INSUFFICIENT_POWER (err u104))
(define-constant ERR_ALREADY_REGISTERED (err u105))
(define-constant ERR_ALREADY_VOTED (err u106))
(define-constant ERR_INVALID_PRINCIPAL (err u107))
(define-constant ERR_INVALID_VALUE (err u108))
(define-constant ERR_TOPIC_NOT_FOUND (err u109))

(define-constant ZERO_ADDRESS 'SP000000000000000000002Q6VF78)
(define-constant MIN_VOTE_WEIGHT u1)
(define-constant MAX_VOTE_WEIGHT u1000)
(define-constant MIN_PROPOSAL_THRESHOLD u1000)
(define-constant MAX_TOPIC_ID u1000)

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var next-proposal-id uint u1)
(define-data-var system-fee-percent uint u5) ;; 5% fee
(define-data-var system-balance uint u0)

;; Admin functions
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (not (is-eq new-owner ZERO_ADDRESS)) ERR_INVALID_PRINCIPAL)
    (ok (var-set contract-owner new-owner))))

(define-public (set-system-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-fee u20) ERR_INVALID_PARAMS) ;; Max 20% fee
    (ok (var-set system-fee-percent new-fee))))

(define-public (add-topic (topic-id uint) (topic-name (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (> (len topic-name) u0) ERR_INVALID_PARAMS)
    ;; Validate topic ID
    (asserts! (< topic-id MAX_TOPIC_ID) ERR_INVALID_PARAMS)
    (asserts! (is-none (map-get? topics topic-id)) ERR_ALREADY_REGISTERED)
    (ok (map-set topics topic-id topic-name))))

;; User functions
(define-public (register-voter (interests (list 10 uint)))
  (begin
    (asserts! (is-none (map-get? voter-profiles tx-sender)) ERR_ALREADY_REGISTERED)
    (asserts! (validate-interests interests) ERR_INVALID_PARAMS)
    (ok (map-set voter-profiles tx-sender {
      active: true,
      interests: interests,
      vote-power: u0,
      last-vote: u0,
      vote-count: u0
    }))))

(define-public (update-interests (interests (list 10 uint)))
  (let ((voter-profile (unwrap! (map-get? voter-profiles tx-sender) ERR_VOTER_NOT_FOUND)))
    (asserts! (validate-interests interests) ERR_INVALID_PARAMS)
    (ok (map-set voter-profiles tx-sender (merge voter-profile {interests: interests})))))

(define-public (deactivate-voter)
  (let ((voter-profile (unwrap! (map-get? voter-profiles tx-sender) ERR_VOTER_NOT_FOUND)))
    (ok (map-set voter-profiles tx-sender (merge voter-profile {active: false})))))

(define-public (reactivate-voter)
  (let ((voter-profile (unwrap! (map-get? voter-profiles tx-sender) ERR_VOTER_NOT_FOUND)))
    (ok (map-set voter-profiles tx-sender (merge voter-profile {active: true})))))

;; Proposal creator functions
(define-public (create-proposal (threshold uint) (vote-weight uint) (topic uint) (stx-amount uint))
  (begin
    (asserts! (>= threshold MIN_PROPOSAL_THRESHOLD) ERR_INVALID_PARAMS)
    (asserts! (and (>= vote-weight MIN_VOTE_WEIGHT) (<= vote-weight MAX_VOTE_WEIGHT)) ERR_INVALID_PARAMS)
    (asserts! (is-some (map-get? topics topic)) ERR_TOPIC_NOT_FOUND)
    (asserts! (>= stx-amount threshold) ERR_INSUFFICIENT_POWER)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? stx-amount tx-sender (as-contract tx-sender)))
    
    (let ((proposal-id (var-get next-proposal-id)))
      ;; Create proposal
      (map-set proposals proposal-id {
        creator: tx-sender,
        threshold: threshold,
        vote-weight: vote-weight,
        active: true,
        topic: topic,
        total-votes: u0,
        created-at: u0
      })
      
      ;; Increment proposal ID
      (var-set next-proposal-id (+ proposal-id u1))
      (ok proposal-id))))

(define-public (close-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get creator proposal)) ERR_NOT_AUTHORIZED)
    (ok (map-set proposals proposal-id (merge proposal {active: false})))))

(define-public (reopen-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get creator proposal)) ERR_NOT_AUTHORIZED)
    (ok (map-set proposals proposal-id (merge proposal {active: true})))))

(define-public (increase-threshold (proposal-id uint) (additional-threshold uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get creator proposal)) ERR_NOT_AUTHORIZED)
    (asserts! (> additional-threshold u0) ERR_INVALID_PARAMS)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? additional-threshold tx-sender (as-contract tx-sender)))
    
    (ok (map-set proposals proposal-id 
      (merge proposal {threshold: (+ (get threshold proposal) additional-threshold)})))))

;; Helper function to check if a topic matches voter interests
(define-private (check-topic-match (topic uint) (interests (list 10 uint)))
  (or
    (and (> (len interests) u0) (is-eq topic (unwrap-panic (element-at interests u0))))
    (and (> (len interests) u1) (is-eq topic (unwrap-panic (element-at interests u1))))
    (and (> (len interests) u2) (is-eq topic (unwrap-panic (element-at interests u2))))
    (and (> (len interests) u3) (is-eq topic (unwrap-panic (element-at interests u3))))
    (and (> (len interests) u4) (is-eq topic (unwrap-panic (element-at interests u4))))
    (and (> (len interests) u5) (is-eq topic (unwrap-panic (element-at interests u5))))
    (and (> (len interests) u6) (is-eq topic (unwrap-panic (element-at interests u6))))
    (and (> (len interests) u7) (is-eq topic (unwrap-panic (element-at interests u7))))
    (and (> (len interests) u8) (is-eq topic (unwrap-panic (element-at interests u8))))
    (and (> (len interests) u9) (is-eq topic (unwrap-panic (element-at interests u9))))
  ))

;; Voting and power distribution
(define-public (cast-vote (proposal-id uint))
  (let (
    (voter-profile (unwrap! (map-get? voter-profiles tx-sender) ERR_VOTER_NOT_FOUND))
    (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (vote-key {voter: tx-sender, proposal-id: proposal-id})
  )
    ;; Validate conditions
    (asserts! (get active voter-profile) ERR_VOTER_NOT_FOUND)
    (asserts! (get active proposal) ERR_PROPOSAL_NOT_FOUND)
    (asserts! (is-none (map-get? vote-records vote-key)) ERR_ALREADY_VOTED)
    (asserts! (>= (get threshold proposal) (get vote-weight proposal)) ERR_INSUFFICIENT_POWER)
    (asserts! (check-topic-match (get topic proposal) (get interests voter-profile)) ERR_INVALID_PARAMS)
    
    ;; Calculate voting power
    (let (
      (vote-weight (get vote-weight proposal))
      (system-fee (/ (* vote-weight (var-get system-fee-percent)) u100))
      (voter-power (- vote-weight system-fee))
    )
      ;; Record the vote
      (map-set vote-records vote-key {timestamp: u0, counted: true})
      
      ;; Update proposal stats
      (map-set proposals proposal-id (merge proposal {
        threshold: (- (get threshold proposal) vote-weight),
        total-votes: (+ (get total-votes proposal) u1)
      }))
      
      ;; Update voter stats
      (map-set voter-profiles tx-sender (merge voter-profile {
        vote-power: (+ (get vote-power voter-profile) voter-power),
        vote-count: (+ (get vote-count voter-profile) u1)
      }))
      
      ;; Update system balance
      (var-set system-balance (+ (var-get system-balance) system-fee))
      
      (ok voter-power))))

(define-public (claim-vote-power)
  (let ((voter-profile (unwrap! (map-get? voter-profiles tx-sender) ERR_VOTER_NOT_FOUND)))
    (let ((power (get vote-power voter-profile)))
      (asserts! (> power u0) ERR_INSUFFICIENT_POWER)
      
      ;; Transfer STX to voter
      (try! (as-contract (stx-transfer? power tx-sender tx-sender)))
      
      ;; Update voter profile
      (map-set voter-profiles tx-sender (merge voter-profile {
        vote-power: u0,
        last-vote: u0
      }))
      
      (ok power))))

(define-public (withdraw-system-fees)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (let ((amount (var-get system-balance)))
      (asserts! (> amount u0) ERR_INSUFFICIENT_POWER)
      
      ;; Transfer STX to contract owner
      (try! (as-contract (stx-transfer? amount tx-sender (var-get contract-owner))))
      
      ;; Reset system balance
      (var-set system-balance u0)
      
      (ok amount))))

;; Helper function to check if a topic is valid
(define-private (is-valid-topic (topic uint))
  (is-some (map-get? topics topic)))

;; Helper function to count valid topics in a list
(define-private (count-valid-topics (interests (list 10 uint)))
  (+ 
    (if (and (> (len interests) u0) (is-valid-topic (unwrap-panic (element-at interests u0)))) u1 u0)
    (if (and (> (len interests) u1) (is-valid-topic (unwrap-panic (element-at interests u1)))) u1 u0)
    (if (and (> (len interests) u2) (is-valid-topic (unwrap-panic (element-at interests u2)))) u1 u0)
    (if (and (> (len interests) u3) (is-valid-topic (unwrap-panic (element-at interests u3)))) u1 u0)
    (if (and (> (len interests) u4) (is-valid-topic (unwrap-panic (element-at interests u4)))) u1 u0)
    (if (and (> (len interests) u5) (is-valid-topic (unwrap-panic (element-at interests u5)))) u1 u0)
    (if (and (> (len interests) u6) (is-valid-topic (unwrap-panic (element-at interests u6)))) u1 u0)
    (if (and (> (len interests) u7) (is-valid-topic (unwrap-panic (element-at interests u7)))) u1 u0)
    (if (and (> (len interests) u8) (is-valid-topic (unwrap-panic (element-at interests u8)))) u1 u0)
    (if (and (> (len interests) u9) (is-valid-topic (unwrap-panic (element-at interests u9)))) u1 u0)
  ))

;; Validate voter interests
(define-private (validate-interests (interests (list 10 uint)))
  (let ((interests-len (len interests)))
    (and 
      (> interests-len u0)
      (<= interests-len u10)
      (is-eq interests-len (count-valid-topics interests)))))

;; Read-only functions
(define-read-only (get-voter-profile (voter principal))
  (map-get? voter-profiles voter))

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id))

(define-read-only (get-topic (topic-id uint))
  (map-get? topics topic-id))

(define-read-only (get-system-fee)
  (var-get system-fee-percent))

(define-read-only (get-system-balance)
  (var-get system-balance))

(define-read-only (get-vote-record (voter principal) (proposal-id uint))
  (map-get? vote-records {voter: voter, proposal-id: proposal-id}))
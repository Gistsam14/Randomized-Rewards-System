;; Randomized Rewards Contract
;; Handles user participation and random reward distribution

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ALREADY_PARTICIPATED (err u101))
(define-constant ERR_NO_PARTICIPANTS (err u102))


;; Data Maps
(define-map participants principal bool)
(define-map winners { round: uint, position: uint } principal)

;; Data Variables
(define-data-var current-round uint u0)
(define-data-var position uint u0)
(define-data-var participant-count uint u0)

;; Public Functions
(define-public (participate)
    (let ((is-participant (default-to false (map-get? participants tx-sender))))
        (asserts! (not is-participant) ERR_ALREADY_PARTICIPATED)
        (map-set participants tx-sender true)
        (var-set participant-count (+ (var-get participant-count) u1))
        (ok true)))
        
(define-public (select-winner)
    (let (
        (count (var-get participant-count))
        (block-hash (get-block-info? header-hash (- block-height u1)))
        (random-seed (slice? (default-to 0x block-hash) u0 u16))
        (winner-index (mod u1  count))
    )
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (> count u0) ERR_NO_PARTICIPANTS)
        
        (map-set winners { round: (var-get current-round), position: (var-get position) } 
            (get-participant-at-index winner-index))
        (var-set current-round (+ (var-get current-round) u1))
        (ok true)))

;; Read-Only Functions
(define-read-only (get-participant-count)
    (var-get participant-count))

(define-read-only (is-participant (user principal))
    (default-to false (map-get? participants user)))

(define-read-only (get-winner-for-round (round uint))
    (map-get? winners { round: round, position: (var-get position) }))


;; Internal Functions
(define-private (map-get-participants)
    (fold check-participant-map 
        (get-principals)
        (list)))

(define-private (check-participant-map (participant principal) (acc (list 100 principal)))
    (if (default-to false (map-get? participants participant))
        (unwrap-panic (as-max-len? (append acc participant) u100))
        acc))

        
(define-private (get-participant-at-index (index uint))
    (default-to CONTRACT_OWNER 
        (element-at (map-get-participants) index)))


(define-private (get-principals)
    (list 
        ;; Add some test principals for development
        'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
        'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG
        'ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC))


;; Add with data variables
(define-data-var winners-per-round uint u3)

;; Modify winners map

;; Add function to set winner count
(define-public (set-winners-per-round (count uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (var-set winners-per-round count)
        (ok true)))



;; Add with data variables
(define-data-var round-end-height uint u0)
(define-constant ROUND_DURATION u144) ;; ~1 day in blocks

;; Add function to start new round
(define-public (start-new-round)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (var-set round-end-height (+ block-height ROUND_DURATION))
        (ok true)))


;; Add new map
(define-map staked-amounts principal uint)

;; Add staking function
(define-public (stake-tokens (amount uint))
    (begin
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set staked-amounts tx-sender amount)
        (ok true)))



;; Add new map
(define-map referrals principal principal)
(define-constant REFERRAL-BONUS u50)

;; Add referral function
(define-public (participate-with-referral (referrer principal))
    (begin
        (asserts! (not (is-eq tx-sender referrer)) (err u103))
        (map-set referrals tx-sender referrer)
        (try! (participate))
        (try! (stx-transfer? REFERRAL-BONUS CONTRACT_OWNER referrer))
        (ok true)))


;; Add new map to track wins
(define-map win-counts principal uint)

;; Add function to increment wins
(define-private (increment-winner-count (winner principal))
    (let ((current-wins (default-to u0 (map-get? win-counts winner))))
        (map-set win-counts winner (+ current-wins u1))))

;; Add read-only function to get wins
(define-read-only (get-participant-wins (user principal))
    (default-to u0 (map-get? win-counts user)))



;; Add new map for round details
(define-map round-archives 
    { round: uint } 
    { winner: principal, 
      participant-count: uint, 
      timestamp: uint })

;; Add function to archive round
(define-private (archive-round (round uint) (winner principal))
    (map-set round-archives
        { round: round }
        { winner: winner,
          participant-count: (var-get participant-count),
          timestamp: block-height }))

;; Add read-only function to get round details
(define-read-only (get-round-archive (round uint))
    (map-get? round-archives { round: round }))




;; Add new map and constants
(define-map consecutive-rounds principal uint)
(define-constant BONUS-THRESHOLD u5)
(define-constant PARTICIPATION-BONUS u50)

;; Add function to track and reward consecutive participation
(define-private (update-consecutive-rounds (participant principal))
    (let ((current-streak (default-to u0 (map-get? consecutive-rounds participant))))
        (map-set consecutive-rounds participant (+ current-streak u1))
        (if (>= current-streak BONUS-THRESHOLD)
            (as-contract (stx-transfer? PARTICIPATION-BONUS CONTRACT_OWNER participant))
            (ok true))))

;; Add read-only function to check streak
(define-read-only (get-participation-streak (user principal))
    (default-to u0 (map-get? consecutive-rounds user)))




;; Add new map for referral counts
(define-map referral-counts principal uint)

;; Add function to update referral counts
(define-private (update-referral-count (referrer principal))
    (let ((current-count (default-to u0 (map-get? referral-counts referrer))))
        (map-set referral-counts referrer (+ current-count u1))))

;; Add read-only function to get referral counts
(define-read-only (get-referral-count (user principal))
    (default-to u0 (map-get? referral-counts user)))


        ;; Add function to reset participation streak
    (define-public (reset-participation-streak (user principal))
        (begin
            (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
            (map-set consecutive-rounds user u0)
            (ok true)))

;; 1. Tiered Reward System
(define-map user-tiers principal uint)
(define-constant TIER-1-THRESHOLD u1000)
(define-constant TIER-2-THRESHOLD u5000)
(define-constant TIER-3-THRESHOLD u10000)

(define-public (calculate-tier (user principal))
    (let ((staked-amount (default-to u0 (map-get? staked-amounts user))))
        (map-set user-tiers user 
            (if (>= staked-amount TIER-3-THRESHOLD) 
                u3
                (if (>= staked-amount TIER-2-THRESHOLD)
                    u2
                    (if (>= staked-amount TIER-1-THRESHOLD)
                        u1
                        u0))))
        (ok true)))

(define-read-only (get-user-tier (user principal))
    (default-to u0 (map-get? user-tiers user)))

;; 2. Time-locked Rewards
(define-map locked-rewards 
    principal 
    { amount: uint, unlock-height: uint })

(define-public (lock-rewards (amount uint) (lock-period uint))
    (begin
        (asserts! (> amount u0) (err u104))
        (map-set locked-rewards tx-sender
            { amount: amount, 
              unlock-height: (+ block-height lock-period) })
        (ok true)))

(define-read-only (get-locked-rewards (user principal))
    (map-get? locked-rewards user))

;; 3. Achievement System
(define-map user-achievements 
    principal 
    { participation-count: uint,
      wins: uint,
      total-staked: uint })

(define-public (update-achievements (user principal))
    (let ((current-data (default-to 
            { participation-count: u0, wins: u0, total-staked: u0 }
            (map-get? user-achievements user))))
        (map-set user-achievements user
            { participation-count: (+ (get participation-count current-data) u1),
              wins: (get-participant-wins user),
              total-staked: (default-to u0 (map-get? staked-amounts user)) })
        (ok true)))

;; 4. Emergency Pause Mechanism
(define-data-var contract-paused bool false)

(define-public (toggle-pause)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (var-set contract-paused (not (var-get contract-paused)))
        (ok true)))

(define-read-only (is-contract-paused)
    (var-get contract-paused))

;; 5. User Profile System
(define-map user-profiles
    principal
    { username: (string-ascii 50),
      join-height: uint,
      last-active: uint })

(define-public (create-profile (username (string-ascii 50)))
    (begin
        (map-set user-profiles tx-sender
            { username: username,
              join-height: block-height,
              last-active: block-height })
        (ok true)))

(define-read-only (get-user-profile (user principal))
    (map-get? user-profiles user))

;; 6. Token Burning Mechanism
(define-data-var total-burned uint u0)

(define-public (burn-tokens (amount uint))
    (begin
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (var-set total-burned (+ (var-get total-burned) amount))
        (ok true)))

(define-read-only (get-total-burned)
    (var-get total-burned))

;; 7. Reward Distribution Queue
(define-map reward-queue uint 
    { recipient: principal,
      amount: uint,
      processed: bool })
(define-data-var queue-index uint u0)

(define-public (queue-reward (recipient principal) (amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (map-set reward-queue (var-get queue-index)
            { recipient: recipient,
              amount: amount,
              processed: false })
        (var-set queue-index (+ (var-get queue-index) u1))
        (ok true)))

(define-read-only (get-queued-reward (index uint))
    (map-get? reward-queue index))



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

;; Randomized Rewards Contract
;; Handles user participation and random reward distribution

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ALREADY_PARTICIPATED (err u101))
(define-constant ERR_NO_PARTICIPANTS (err u102))


;; Data Maps
(define-map participants principal bool)
(define-map winners { round: uint } principal)

;; Data Variables
(define-data-var current-round uint u0)
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
        
        (map-set winners { round: (var-get current-round) } 
            (get-participant-at-index winner-index))
        (var-set current-round (+ (var-get current-round) u1))
        (ok true)))

;; Read-Only Functions
(define-read-only (get-participant-count)
    (var-get participant-count))

(define-read-only (is-participant (user principal))
    (default-to false (map-get? participants user)))

(define-read-only (get-winner-for-round (round uint))
    (map-get? winners { round: round }))
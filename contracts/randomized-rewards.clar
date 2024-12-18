;; Randomized Rewards Contract
;; Handles user participation and random reward distribution

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ALREADY_PARTICIPATED (err u101))
(define-constant ERR_NO_PARTICIPANTS (err u102))

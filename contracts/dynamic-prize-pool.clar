(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u600))
(define-constant ERR_INSUFFICIENT_POOL (err u601))
(define-constant ERR_INVALID_AMOUNT (err u602))
(define-constant ERR_POOL_NOT_ACTIVE (err u603))

(define-data-var total-prize-pool uint u0)
(define-data-var pool-active bool true)
(define-data-var minimum-contribution uint u10)
(define-data-var pool-fee-percentage uint u5)

(define-map user-contributions principal uint)
(define-map pool-snapshots uint 
    { total-pool: uint, 
      participant-count: uint, 
      winner: (optional principal),
      timestamp: uint })

(define-data-var snapshot-counter uint u0)

(define-public (contribute-to-pool (amount uint))
    (begin
        (asserts! (var-get pool-active) ERR_POOL_NOT_ACTIVE)
        (asserts! (>= amount (var-get minimum-contribution)) ERR_INVALID_AMOUNT)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (var-set total-prize-pool (+ (var-get total-prize-pool) amount))
        (map-set user-contributions tx-sender 
            (+ (default-to u0 (map-get? user-contributions tx-sender)) amount))
        (ok true)))

(define-public (distribute-prize (winner principal))
    (let (
        (current-pool (var-get total-prize-pool))
        (fee-amount (/ (* current-pool (var-get pool-fee-percentage)) u100))
        (prize-amount (- current-pool fee-amount))
    )
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (> current-pool u0) ERR_INSUFFICIENT_POOL)
        (try! (as-contract (stx-transfer? prize-amount CONTRACT_OWNER winner)))
        (map-set pool-snapshots (var-get snapshot-counter)
            { total-pool: current-pool,
              participant-count: u1,
              winner: (some winner),
              timestamp: stacks-block-height })
        (var-set snapshot-counter (+ (var-get snapshot-counter) u1))
        (var-set total-prize-pool u0)
        (ok prize-amount)))

(define-public (set-pool-parameters (min-contribution uint) (fee-percentage uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (<= fee-percentage u20) ERR_INVALID_AMOUNT)
        (var-set minimum-contribution min-contribution)
        (var-set pool-fee-percentage fee-percentage)
        (ok true)))

(define-public (toggle-pool-status)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (var-set pool-active (not (var-get pool-active)))
        (ok (var-get pool-active))))

(define-public (emergency-withdraw)
    (let ((current-pool (var-get total-prize-pool)))
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (> current-pool u0) ERR_INSUFFICIENT_POOL)
        (try! (as-contract (stx-transfer? current-pool CONTRACT_OWNER CONTRACT_OWNER)))
        (var-set total-prize-pool u0)
        (ok current-pool)))

(define-read-only (get-current-pool-size)
    (var-get total-prize-pool))

(define-read-only (get-user-contribution (user principal))
    (default-to u0 (map-get? user-contributions user)))

(define-read-only (get-pool-status)
    { active: (var-get pool-active),
      total-pool: (var-get total-prize-pool),
      min-contribution: (var-get minimum-contribution),
      fee-percentage: (var-get pool-fee-percentage) })

(define-read-only (get-pool-snapshot (snapshot-id uint))
    (map-get? pool-snapshots snapshot-id))

(define-read-only (calculate-potential-prize)
    (let (
        (current-pool (var-get total-prize-pool))
        (fee-amount (/ (* current-pool (var-get pool-fee-percentage)) u100))
    )
        (if (> current-pool u0)
            (- current-pool fee-amount)
            u0)))

(define-public (batch-contribute (contributors (list 10 { user: principal, amount: uint })))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (var-get pool-active) ERR_POOL_NOT_ACTIVE)
        (fold process-contribution contributors (ok u0))))

(define-private (process-contribution 
    (contribution { user: principal, amount: uint })
    (previous-result (response uint uint)))
    (let ((amount (get amount contribution))
          (user (get user contribution)))
        (if (is-ok previous-result)
            (begin
                (map-set user-contributions user 
                    (+ (default-to u0 (map-get? user-contributions user)) amount))
                (var-set total-prize-pool (+ (var-get total-prize-pool) amount))
                (ok (+ (unwrap-panic previous-result) amount)))
            previous-result)))
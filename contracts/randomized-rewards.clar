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
        (asserts! (> lock-period u0) (err u104))
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

;; 1. Daily Login Rewards System
(define-map daily-login-tracker 
    principal 
    { last-login: uint,
      consecutive-days: uint })
(define-constant DAILY-REWARD-AMOUNT u10)
(define-constant BLOCKS-PER-DAY u144)

(define-public (claim-daily-reward)
    (let (
        (last-login (default-to { last-login: u0, consecutive-days: u0 }
                    (map-get? daily-login-tracker tx-sender)))
        (current-block block-height)
    )
        (asserts! (>= (- current-block (get last-login last-login)) BLOCKS-PER-DAY) 
            (err u201))
        (map-set daily-login-tracker tx-sender
            { last-login: current-block,
              consecutive-days: (+ (get consecutive-days last-login) u1) })
        (as-contract (stx-transfer? DAILY-REWARD-AMOUNT CONTRACT_OWNER tx-sender))))

;; 2. User Blacklist System
(define-map blacklisted-users principal bool)
(define-constant ERR_BLACKLISTED (err u202))

(define-public (blacklist-user (user principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (map-set blacklisted-users user true)
        (ok true)))

(define-public (remove-from-blacklist (user principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (map-delete blacklisted-users user)
        (ok true)))

(define-read-only (is-blacklisted (user principal))
    (default-to false (map-get? blacklisted-users user)))

;; 3. Multi-Token Support
(define-map supported-tokens 
    { token-id: uint } 
    { enabled: bool, reward-multiplier: uint })

(define-public (add-supported-token (token-id uint) (multiplier uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (map-set supported-tokens 
            { token-id: token-id }
            { enabled: true, reward-multiplier: multiplier })
        (ok true)))

(define-read-only (is-token-supported (token-id uint))
    (default-to 
        { enabled: false, reward-multiplier: u0 }
        (map-get? supported-tokens { token-id: token-id })))

;; 4. Reward Multiplier System
(define-map user-multipliers principal uint)
(define-constant BASE-MULTIPLIER u100)
(define-constant MAX-MULTIPLIER u500)

(define-public (set-user-multiplier (user principal) (multiplier uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (<= multiplier MAX-MULTIPLIER) (err u203))
        (map-set user-multipliers user multiplier)
        (ok true)))

(define-read-only (get-user-multiplier (user principal))
    (default-to BASE-MULTIPLIER (map-get? user-multipliers user)))

;; 5. User Statistics Tracking
(define-map user-statistics
    principal
    { total-rewards: uint,
      participation-rate: uint,
      last-active-round: uint })

(define-public (update-user-stats (user principal) (reward uint))
    (let ((current-stats (default-to 
            { total-rewards: u0, participation-rate: u0, last-active-round: u0 }
            (map-get? user-statistics user))))
        (map-set user-statistics user
            { total-rewards: (+ (get total-rewards current-stats) reward),
              participation-rate: (+ (get participation-rate current-stats) u1),
              last-active-round: (var-get current-round) })
        (ok true)))

;; 6. Lottery System
(define-map lottery-tickets principal uint)
(define-data-var lottery-pool uint u0)
(define-data-var lottery-round uint u0)
(define-constant TICKET-PRICE u10)

(define-public (buy-lottery-tickets (ticket-count uint))
    (let ((total-cost (* TICKET-PRICE ticket-count)))
        (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
        (map-set lottery-tickets tx-sender 
            (+ (default-to u0 (map-get? lottery-tickets tx-sender)) ticket-count))
        (var-set lottery-pool (+ (var-get lottery-pool) total-cost))
        (ok true)))

(define-public (draw-lottery)
    (let (
        (winner (get-random-ticket-holder))
        (prize (var-get lottery-pool))
    )
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (try! (as-contract (stx-transfer? prize CONTRACT_OWNER winner)))
        (var-set lottery-pool u0)
        (var-set lottery-round (+ (var-get lottery-round) u1))
        (ok true)))

(define-private (get-random-ticket-holder)
    (default-to CONTRACT_OWNER 
        (element-at (map-get-participants) 
            (mod u1 (var-get participant-count)))))

(define-read-only (get-lottery-info)
    { pool: (var-get lottery-pool),
      round: (var-get lottery-round) })


(define-map vip-members principal 
    { status: bool, expiry: uint, tier: uint })
(define-constant VIP-COST u1000)
(define-constant VIP-DURATION u4320) 

(define-public (purchase-vip-membership (tier uint))
    (let ((cost (* VIP-COST tier)))
        (try! (stx-transfer? cost tx-sender (as-contract tx-sender)))
        (map-set vip-members tx-sender 
            { status: true, 
              expiry: (+ block-height VIP-DURATION), 
              tier: tier })
        (ok true)))

(define-read-only (is-vip (user principal))
    (let ((member-data (default-to 
            { status: false, expiry: u0, tier: u0 } 
            (map-get? vip-members user))))
        (and 
            (get status member-data)
            (< block-height (get expiry member-data)))))

(define-read-only (get-vip-tier (user principal))
    (let ((member-data (default-to 
            { status: false, expiry: u0, tier: u0 } 
            (map-get? vip-members user))))
        (get tier member-data)))



(define-data-var boost-active bool false)
(define-data-var boost-multiplier uint u100)
(define-data-var boost-end-height uint u0)

(define-public (start-boost-event (multiplier uint) (duration uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (var-set boost-active true)
        (var-set boost-multiplier multiplier)
        (var-set boost-end-height (+ block-height duration))
        (ok true)))

(define-public (end-boost-event)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (var-set boost-active false)
        (ok true)))

(define-read-only (get-current-boost)
    (if (and 
            (var-get boost-active)
            (< block-height (var-get boost-end-height)))
        (var-get boost-multiplier)
        u100))


(define-map teams uint { name: (string-ascii 50), score: uint })
(define-map user-teams principal uint)
(define-data-var team-count uint u4)

(define-public (create-team (team-id uint) (team-name (string-ascii 50)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (map-set teams team-id { name: team-name, score: u0 })
        (var-set team-count (+ (var-get team-count) u1))
        (ok true)))

(define-public (join-team (team-id uint))
    (begin
        (asserts! (< team-id (var-get team-count)) (err u301))
        (map-set user-teams tx-sender team-id)
        (ok true)))

(define-public (add-team-points (team-id uint) (points uint))
    (let ((team-data (default-to { name: "", score: u0 } (map-get? teams team-id))))
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (map-set teams team-id 
            { name: (get name team-data), 
              score: (+ (get score team-data) points) })
        (ok true)))

(define-read-only (get-team-score (team-id uint))
    (let ((team-data (default-to { name: "", score: u0 } (map-get? teams team-id))))
        (get score team-data)))

(define-read-only (get-user-team (user principal))
    (default-to u0 (map-get? user-teams user)))



(define-map pending-rewards principal uint)
(define-constant ERR_NO_REWARDS (err u401))

(define-public (add-pending-reward (user principal) (amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (map-set pending-rewards user 
            (+ (default-to u0 (map-get? pending-rewards user)) amount))
        (ok true)))

(define-public (claim-rewards)
    (let ((reward-amount (default-to u0 (map-get? pending-rewards tx-sender))))
        (asserts! (> reward-amount u0) ERR_NO_REWARDS)
        (try! (as-contract (stx-transfer? reward-amount CONTRACT_OWNER tx-sender)))
        (map-delete pending-rewards tx-sender)
        (ok reward-amount)))

(define-read-only (get-pending-rewards (user principal))
    (default-to u0 (map-get? pending-rewards user)))



(define-data-var current-season uint u1)
(define-data-var season-end-height uint u0)
(define-constant SEASON_DURATION u12960)

(define-map seasonal-points { season: uint, user: principal } uint)
(define-map season-rewards uint { bronze: uint, ssilver: uint, gold: uint })

(define-public (start-new-season)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (var-set current-season (+ (var-get current-season) u1))
        (var-set season-end-height (+ block-height SEASON_DURATION))
        (ok true)))

(define-public (add-season-points (user principal) (points uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (map-set seasonal-points 
            { season: (var-get current-season), user: user }
            (+ (default-to u0 (map-get? seasonal-points 
                { season: (var-get current-season), user: user })) points))
        (ok true)))



(define-read-only (get-season-points (user principal))
    (default-to u0 (map-get? seasonal-points 
        { season: (var-get current-season), user: user })))

(define-read-only (get-current-season-info)
    { season: (var-get current-season),
      end-height: (var-get season-end-height) })



(define-map referral-tiers principal uint)
(define-constant TIER-1-REFERRALS u5)
(define-constant TIER-2-REFERRALS u15)
(define-constant TIER-3-REFERRALS u30)

(define-public (update-referral-tier (user principal))
    (let ((ref-count (get-referral-count user)))
        (map-set referral-tiers user 
            (if (>= ref-count TIER-3-REFERRALS)
                u3
                (if (>= ref-count TIER-2-REFERRALS)
                    u2
                    (if (>= ref-count TIER-1-REFERRALS)
                        u1
                        u0))))
        (ok true)))

(define-read-only (get-referral-tier (user principal))
    (default-to u0 (map-get? referral-tiers user)))

(define-read-only (get-referral-bonus (user principal))
    (let ((tier (get-referral-tier user)))
        (* REFERRAL-BONUS 
            (if (is-eq tier u3)
                u3
                (if (is-eq tier u2)
                    u2
                    (if (is-eq tier u1)
                        u1
                        u1))))))



(define-map proposals uint 
    { title: (string-ascii 100),
      active: bool,
      yes-votes: uint,
      no-votes: uint,
      end-height: uint })
(define-map user-votes { proposal-id: uint, user: principal } bool)
(define-data-var proposal-count uint u0)

(define-public (create-proposal (title (string-ascii 100)) (duration uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (map-set proposals (var-get proposal-count)
            { title: title,
              active: true,
              yes-votes: u0,
              no-votes: u0,
              end-height: (+ block-height duration) })
        (var-set proposal-count (+ (var-get proposal-count) u1))
        (ok (- (var-get proposal-count) u1))))

(define-public (vote-on-proposal (proposal-id uint) (vote bool))
    (let ((proposal (default-to 
            { title: "", active: false, yes-votes: u0, no-votes: u0, end-height: u0 }
            (map-get? proposals proposal-id))))
        (asserts! (get active proposal) (err u501))
        (asserts! (< block-height (get end-height proposal)) (err u502))
        (asserts! (not (default-to false (map-get? user-votes 
            { proposal-id: proposal-id, user: tx-sender }))) (err u503))
        
        (map-set user-votes { proposal-id: proposal-id, user: tx-sender } true)
        (map-set proposals proposal-id
            (if vote
                { title: (get title proposal),
                  active: (get active proposal),
                  yes-votes: (+ (get yes-votes proposal) u1),
                  no-votes: (get no-votes proposal),
                  end-height: (get end-height proposal) }
                { title: (get title proposal),
                  active: (get active proposal),
                  yes-votes: (get yes-votes proposal),
                  no-votes: (+ (get no-votes proposal) u1),
                  end-height: (get end-height proposal) }))
        (ok true)))

(define-public (close-proposal (proposal-id uint))
    (let ((proposal (default-to 
            { title: "", active: false, yes-votes: u0, no-votes: u0, end-height: u0 }
            (map-get? proposals proposal-id))))
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (get active proposal) (err u504))
        (map-set proposals proposal-id
            { title: (get title proposal),
              active: false,
              yes-votes: (get yes-votes proposal),
              no-votes: (get no-votes proposal),
              end-height: (get end-height proposal) })
        (ok true)))

(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals proposal-id))

(define-read-only (has-voted (proposal-id uint) (user principal))
    (default-to false (map-get? user-votes { proposal-id: proposal-id, user: user })))



(define-map reward-pools 
    uint 
    { base-amount: uint,
      start-height: uint,
      end-height: uint,
      multiplier: uint,
      active: bool })

(define-data-var pool-counter uint u0)

(define-public (create-reward-pool 
    (base-amount uint)
    (duration uint)
    (multiplier uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (map-set reward-pools (var-get pool-counter)
            { base-amount: base-amount,
              start-height: block-height,
              end-height: (+ block-height duration),
              multiplier: multiplier,
              active: true })
        (var-set pool-counter (+ (var-get pool-counter) u1))
        (ok (- (var-get pool-counter) u1))))

(define-read-only (get-pool-reward (pool-id uint))
    (let ((pool (unwrap! (map-get? reward-pools pool-id) (ok u0))))
        (if (and 
            (get active pool)
            (>= block-height (get start-height pool))
            (<= block-height (get end-height pool)))
            (ok (* (get base-amount pool) (get multiplier pool)))
            (ok (get base-amount pool)))))
    


(define-map power-ups
    principal
    { boost: uint,
      duration: uint,
      active-height: uint })

(define-constant POWERUP-BASIC u150)
(define-constant POWERUP-RARE u200)
(define-constant POWERUP-EPIC u300)

(define-public (grant-power-up (recipient principal) (boost-type uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (map-set power-ups recipient
            { boost: boost-type,
              duration: u144,
              active-height: block-height })
        (ok true)))

(define-read-only (get-active-power-up (user principal))
    (let ((power-up (default-to
            { boost: u100, duration: u0, active-height: u0 }
            (map-get? power-ups user))))
        (if (< (+ (get active-height power-up) (get duration power-up)) block-height)
            u100
            (get boost power-up))))
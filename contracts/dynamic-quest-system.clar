;; Dynamic Quest System Contract
;; Generates procedural quests with randomized objectives and rewards

;; Contract owner and error constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u800))
(define-constant ERR_QUEST_NOT_FOUND (err u801))
(define-constant ERR_QUEST_EXPIRED (err u802))
(define-constant ERR_QUEST_ALREADY_ACTIVE (err u803))
(define-constant ERR_QUEST_NOT_COMPLETED (err u804))
(define-constant ERR_INVALID_DIFFICULTY (err u805))
(define-constant ERR_INSUFFICIENT_PROGRESS (err u806))
(define-constant ERR_QUEST_ALREADY_COMPLETED (err u807))

;; Quest types and difficulty levels
(define-constant QUEST_TYPE_PARTICIPATION u1)
(define-constant QUEST_TYPE_STREAK u2)
(define-constant QUEST_TYPE_REFERRAL u3)
(define-constant QUEST_TYPE_TEAM u4)
(define-constant QUEST_TYPE_STAKING u5)
(define-constant QUEST_TYPE_SOCIAL u6)

(define-constant DIFFICULTY_EASY u1)
(define-constant DIFFICULTY_MEDIUM u2)
(define-constant DIFFICULTY_HARD u3)
(define-constant DIFFICULTY_EPIC u4)

;; Quest generation parameters
(define-constant QUEST_DURATION_SHORT u144)   ;; ~1 day
(define-constant QUEST_DURATION_MEDIUM u720)  ;; ~5 days
(define-constant QUEST_DURATION_LONG u1440)   ;; ~10 days

;; Reward multipliers by difficulty
(define-constant EASY_MULTIPLIER u100)
(define-constant MEDIUM_MULTIPLIER u150)
(define-constant HARD_MULTIPLIER u200)
(define-constant EPIC_MULTIPLIER u300)

;; Base rewards by quest type
(define-constant BASE_PARTICIPATION_REWARD u25)
(define-constant BASE_STREAK_REWARD u50)
(define-constant BASE_REFERRAL_REWARD u75)
(define-constant BASE_TEAM_REWARD u100)
(define-constant BASE_STAKING_REWARD u150)
(define-constant BASE_SOCIAL_REWARD u40)

;; Data variables for quest management
(define-data-var quest-counter uint u0)
(define-data-var daily-quest-seed uint u1)
(define-data-var quest-generation-active bool true)
(define-data-var max-active-quests-per-user uint u3)

;; Quest structure definition
(define-map quests uint 
    { quest-type: uint,
      difficulty: uint,
      target-value: uint,
      reward-amount: uint,
      duration: uint,
      start-height: uint,
      end-height: uint,
      active: bool,
      title: (string-ascii 100),
      description: (string-ascii 200) })

;; User quest assignments and progress tracking
(define-map user-quests 
    { user: principal, quest-id: uint }
    { assigned: bool,
      current-progress: uint,
      completed: bool,
      claimed: bool,
      assignment-height: uint })

;; User quest completion statistics
(define-map user-quest-stats principal
    { total-quests-completed: uint,
      total-rewards-earned: uint,
      current-streak: uint,
      best-streak: uint,
      favorite-quest-type: uint,
      last-completion-height: uint })

;; Quest templates for procedural generation
(define-map quest-templates uint
    { quest-type: uint,
      min-target: uint,
      max-target: uint,
      base-duration: uint,
      scaling-factor: uint })

;; User active quest tracking
(define-map user-active-quests principal 
    { quest-1: (optional uint),
      quest-2: (optional uint), 
      quest-3: (optional uint),
      count: uint })

;; Daily generated quests pool
(define-map daily-quest-pool uint uint)
(define-data-var daily-pool-size uint u0)

;; Quest completion leaderboard
(define-map quest-leaderboard 
    { timeframe: uint, position: uint }
    { user: principal,
      completed-count: uint,
      total-rewards: uint })

;; Initialize quest templates
(define-private (initialize-quest-templates)
    (begin
        ;; Participation quests
        (map-set quest-templates u1
            { quest-type: QUEST_TYPE_PARTICIPATION,
              min-target: u3,
              max-target: u10,
              base-duration: QUEST_DURATION_SHORT,
              scaling-factor: u120 })
        
        ;; Streak quests  
        (map-set quest-templates u2
            { quest-type: QUEST_TYPE_STREAK,
              min-target: u5,
              max-target: u15,
              base-duration: QUEST_DURATION_MEDIUM,
              scaling-factor: u150 })
        
        ;; Referral quests
        (map-set quest-templates u3
            { quest-type: QUEST_TYPE_REFERRAL,
              min-target: u2,
              max-target: u8,
              base-duration: QUEST_DURATION_LONG,
              scaling-factor: u180 })
        
        ;; Team quests
        (map-set quest-templates u4
            { quest-type: QUEST_TYPE_TEAM,
              min-target: u100,
              max-target: u500,
              base-duration: QUEST_DURATION_MEDIUM,
              scaling-factor: u140 })
        
        ;; Staking quests
        (map-set quest-templates u5
            { quest-type: QUEST_TYPE_STAKING,
              min-target: u1000,
              max-target: u5000,
              base-duration: QUEST_DURATION_LONG,
              scaling-factor: u200 })
        
        ;; Social quests
        (map-set quest-templates u6
            { quest-type: QUEST_TYPE_SOCIAL,
              min-target: u5,
              max-target: u20,
              base-duration: QUEST_DURATION_SHORT,
              scaling-factor: u110 })
        (ok true)))

;; Generate a procedural quest
(define-public (generate-quest (quest-type uint) (difficulty uint))
    (let (
        (template (unwrap! (map-get? quest-templates quest-type) ERR_QUEST_NOT_FOUND))
        (random-seed (generate-quest-seed))
        (target-value (calculate-target-value template difficulty random-seed))
        (duration (calculate-quest-duration template difficulty))
        (reward (calculate-quest-reward quest-type difficulty target-value))
        (quest-id (var-get quest-counter))
        (title (generate-quest-title quest-type difficulty))
        (description (generate-quest-description quest-type target-value))
    )
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (<= difficulty DIFFICULTY_EPIC) ERR_INVALID_DIFFICULTY)
        
        (map-set quests quest-id
            { quest-type: quest-type,
              difficulty: difficulty,
              target-value: target-value,
              reward-amount: reward,
              duration: duration,
              start-height: stacks-block-height,
              end-height: (+ stacks-block-height duration),
              active: true,
              title: title,
              description: description })
        
        (var-set quest-counter (+ quest-id u1))
        (ok quest-id)))

;; Assign a quest to a user
(define-public (assign-quest-to-user (user principal) (quest-id uint))
    (let (
        (quest (unwrap! (map-get? quests quest-id) ERR_QUEST_NOT_FOUND))
        (user-quests-data (default-to 
            { quest-1: none, quest-2: none, quest-3: none, count: u0 }
            (map-get? user-active-quests user)))
        (existing-assignment (map-get? user-quests { user: user, quest-id: quest-id }))
    )
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (get active quest) ERR_QUEST_EXPIRED)
        (asserts! (< (get count user-quests-data) (var-get max-active-quests-per-user)) ERR_QUEST_ALREADY_ACTIVE)
        (asserts! (is-none existing-assignment) ERR_QUEST_ALREADY_ACTIVE)
        
        ;; Assign quest to user
        (map-set user-quests { user: user, quest-id: quest-id }
            { assigned: true,
              current-progress: u0,
              completed: false,
              claimed: false,
              assignment-height: stacks-block-height })
        
        ;; Update user's active quest tracking
        (map-set user-active-quests user
            (if (is-none (get quest-1 user-quests-data))
                { quest-1: (some quest-id),
                  quest-2: (get quest-2 user-quests-data),
                  quest-3: (get quest-3 user-quests-data),
                  count: (+ (get count user-quests-data) u1) }
                (if (is-none (get quest-2 user-quests-data))
                    { quest-1: (get quest-1 user-quests-data),
                      quest-2: (some quest-id),
                      quest-3: (get quest-3 user-quests-data),
                      count: (+ (get count user-quests-data) u1) }
                    { quest-1: (get quest-1 user-quests-data),
                      quest-2: (get quest-2 user-quests-data),
                      quest-3: (some quest-id),
                      count: (+ (get count user-quests-data) u1) })))
        (ok true)))

;; Update quest progress
(define-public (update-quest-progress (user principal) (quest-id uint) (progress-increment uint))
    (let (
        (quest (unwrap! (map-get? quests quest-id) ERR_QUEST_NOT_FOUND))
        (user-quest-data (unwrap! (map-get? user-quests { user: user, quest-id: quest-id }) ERR_QUEST_NOT_FOUND))
        (new-progress (+ (get current-progress user-quest-data) progress-increment))
    )
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (get assigned user-quest-data) ERR_QUEST_NOT_FOUND)
        (asserts! (not (get completed user-quest-data)) ERR_QUEST_ALREADY_COMPLETED)
        (asserts! (<= stacks-block-height (get end-height quest)) ERR_QUEST_EXPIRED)
        
        ;; Update progress
        (map-set user-quests { user: user, quest-id: quest-id }
            (merge user-quest-data 
                { current-progress: new-progress,
                  completed: (>= new-progress (get target-value quest)) }))
        
        ;; Auto-complete if target reached
        (if (>= new-progress (get target-value quest))
            (begin
                (try! (complete-quest user quest-id))
                (ok true))
            (ok true))))

;; Complete a quest
(define-private (complete-quest (user principal) (quest-id uint))
    (let (
        (quest (unwrap! (map-get? quests quest-id) ERR_QUEST_NOT_FOUND))
        (user-quest-data (unwrap! (map-get? user-quests { user: user, quest-id: quest-id }) ERR_QUEST_NOT_FOUND))
        (user-stats (default-to 
            { total-quests-completed: u0,
              total-rewards-earned: u0,
              current-streak: u0,
              best-streak: u0,
              favorite-quest-type: u1,
              last-completion-height: u0 }
            (map-get? user-quest-stats user)))
    )
        (asserts! (get completed user-quest-data) ERR_QUEST_NOT_COMPLETED)
        (asserts! (not (get claimed user-quest-data)) ERR_QUEST_ALREADY_COMPLETED)
        
        ;; Update user statistics
        (map-set user-quest-stats user
            { total-quests-completed: (+ (get total-quests-completed user-stats) u1),
              total-rewards-earned: (+ (get total-rewards-earned user-stats) (get reward-amount quest)),
              current-streak: (if (<= (- stacks-block-height (get last-completion-height user-stats)) u144)
                                 (+ (get current-streak user-stats) u1)
                                 u1),
              best-streak: (let ((new-streak (if (<= (- stacks-block-height (get last-completion-height user-stats)) u144)
                                                   (+ (get current-streak user-stats) u1)
                                                   u1)))
                               (if (> new-streak (get best-streak user-stats))
                                   new-streak
                                   (get best-streak user-stats))),
              favorite-quest-type: (get quest-type quest),
              last-completion-height: stacks-block-height })
        
        ;; Mark quest as claimed
        (map-set user-quests { user: user, quest-id: quest-id }
            (merge user-quest-data { claimed: true }))
        
        ;; Remove from active quests
        (unwrap-panic (remove-from-active-quests user quest-id))
        (ok true)))

;; Claim quest rewards
(define-public (claim-quest-reward (quest-id uint))
    (let (
        (quest (unwrap! (map-get? quests quest-id) ERR_QUEST_NOT_FOUND))
        (user-quest-data (unwrap! (map-get? user-quests { user: tx-sender, quest-id: quest-id }) ERR_QUEST_NOT_FOUND))
    )
        (asserts! (get completed user-quest-data) ERR_QUEST_NOT_COMPLETED)
        (asserts! (not (get claimed user-quest-data)) ERR_QUEST_ALREADY_COMPLETED)
        
        ;; Transfer reward
        (try! (as-contract (stx-transfer? (get reward-amount quest) CONTRACT_OWNER tx-sender)))
        
        ;; Complete the quest
        (try! (complete-quest tx-sender quest-id))
        (ok (get reward-amount quest))))

;; Generate daily quest pool
(define-public (generate-daily-quest-pool)
    (let (
        (seed (var-get daily-quest-seed))
        (pool-size u6)
    )
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (var-get quest-generation-active) ERR_NOT_AUTHORIZED)
        
        ;; Clear previous pool
        (var-set daily-pool-size u0)
        
        ;; Generate varied quest types
        (try! (generate-quest QUEST_TYPE_PARTICIPATION (calculate-random-difficulty seed u1)))
        (map-set daily-quest-pool u0 (- (var-get quest-counter) u1))
        
        (try! (generate-quest QUEST_TYPE_STREAK (calculate-random-difficulty seed u2)))
        (map-set daily-quest-pool u1 (- (var-get quest-counter) u1))
        
        (try! (generate-quest QUEST_TYPE_REFERRAL (calculate-random-difficulty seed u3)))
        (map-set daily-quest-pool u2 (- (var-get quest-counter) u1))
        
        (try! (generate-quest QUEST_TYPE_TEAM (calculate-random-difficulty seed u4)))
        (map-set daily-quest-pool u3 (- (var-get quest-counter) u1))
        
        (try! (generate-quest QUEST_TYPE_STAKING (calculate-random-difficulty seed u5)))
        (map-set daily-quest-pool u4 (- (var-get quest-counter) u1))
        
        (try! (generate-quest QUEST_TYPE_SOCIAL (calculate-random-difficulty seed u6)))
        (map-set daily-quest-pool u5 (- (var-get quest-counter) u1))
        
        (var-set daily-pool-size pool-size)
        (var-set daily-quest-seed (+ seed u1))
        (ok pool-size)))

;; Helper functions
(define-private (generate-quest-seed)
    (let (
        (current-height stacks-block-height)
        (hash-input (mod current-height u1000000))
    )
        (mod (+ hash-input (var-get daily-quest-seed)) u1000000)))

(define-private (calculate-target-value (template { quest-type: uint, min-target: uint, max-target: uint, base-duration: uint, scaling-factor: uint }) (difficulty uint) (seed uint))
    (let (
        (range (- (get max-target template) (get min-target template)))
        (random-offset (mod seed range))
        (base-target (+ (get min-target template) random-offset))
        (difficulty-multiplier (if (is-eq difficulty DIFFICULTY_EASY) u100
                               (if (is-eq difficulty DIFFICULTY_MEDIUM) u150
                               (if (is-eq difficulty DIFFICULTY_HARD) u200
                                   u300))))
    )
        (/ (* base-target difficulty-multiplier) u100)))

(define-private (calculate-quest-duration (template { quest-type: uint, min-target: uint, max-target: uint, base-duration: uint, scaling-factor: uint }) (difficulty uint))
    (let (
        (base-duration (get base-duration template))
        (scaling-factor (get scaling-factor template))
    )
        (/ (* base-duration scaling-factor difficulty) u100)))

(define-private (calculate-quest-reward (quest-type uint) (difficulty uint) (target-value uint))
    (let (
        (base-reward (if (is-eq quest-type QUEST_TYPE_PARTICIPATION) BASE_PARTICIPATION_REWARD
                     (if (is-eq quest-type QUEST_TYPE_STREAK) BASE_STREAK_REWARD
                     (if (is-eq quest-type QUEST_TYPE_REFERRAL) BASE_REFERRAL_REWARD
                     (if (is-eq quest-type QUEST_TYPE_TEAM) BASE_TEAM_REWARD
                     (if (is-eq quest-type QUEST_TYPE_STAKING) BASE_STAKING_REWARD
                         BASE_SOCIAL_REWARD))))))
        (difficulty-multiplier (if (is-eq difficulty DIFFICULTY_EASY) EASY_MULTIPLIER
                               (if (is-eq difficulty DIFFICULTY_MEDIUM) MEDIUM_MULTIPLIER
                               (if (is-eq difficulty DIFFICULTY_HARD) HARD_MULTIPLIER
                                   EPIC_MULTIPLIER))))
    )
        (/ (* base-reward difficulty-multiplier) u100)))

(define-private (calculate-random-difficulty (seed uint) (offset uint))
    (let ((random-val (mod (+ seed offset) u100)))
        (if (< random-val u40) DIFFICULTY_EASY
        (if (< random-val u70) DIFFICULTY_MEDIUM
        (if (< random-val u90) DIFFICULTY_HARD
            DIFFICULTY_EPIC)))))

(define-private (generate-quest-title (quest-type uint) (difficulty uint))
    (if (is-eq quest-type QUEST_TYPE_PARTICIPATION)
        (if (is-eq difficulty DIFFICULTY_EASY) "Participation Starter"
        (if (is-eq difficulty DIFFICULTY_MEDIUM) "Active Participant"
        (if (is-eq difficulty DIFFICULTY_HARD) "Participation Champion"
            "Ultimate Participant")))
    (if (is-eq quest-type QUEST_TYPE_STREAK)
        (if (is-eq difficulty DIFFICULTY_EASY) "Streak Beginner"
        (if (is-eq difficulty DIFFICULTY_MEDIUM) "Consistency Builder"
        (if (is-eq difficulty DIFFICULTY_HARD) "Streak Master"
            "Legendary Streaker")))
    (if (is-eq quest-type QUEST_TYPE_REFERRAL)
        (if (is-eq difficulty DIFFICULTY_EASY) "Friend Inviter"
        (if (is-eq difficulty DIFFICULTY_MEDIUM) "Community Builder"
        (if (is-eq difficulty DIFFICULTY_HARD) "Network Expander"
            "Referral Legend")))
    (if (is-eq quest-type QUEST_TYPE_TEAM)
        (if (is-eq difficulty DIFFICULTY_EASY) "Team Supporter"
        (if (is-eq difficulty DIFFICULTY_MEDIUM) "Team Player"
        (if (is-eq difficulty DIFFICULTY_HARD) "Team Leader"
            "Team Champion")))
    (if (is-eq quest-type QUEST_TYPE_STAKING)
        (if (is-eq difficulty DIFFICULTY_EASY) "Staking Novice"
        (if (is-eq difficulty DIFFICULTY_MEDIUM) "Committed Staker"
        (if (is-eq difficulty DIFFICULTY_HARD) "Staking Expert"
            "Staking Whale")))
        (if (is-eq difficulty DIFFICULTY_EASY) "Social Starter"
        (if (is-eq difficulty DIFFICULTY_MEDIUM) "Social Connector"
        (if (is-eq difficulty DIFFICULTY_HARD) "Social Influencer"
            "Social Legend")))))))))

(define-private (generate-quest-description (quest-type uint) (target-value uint))
    (if (is-eq quest-type QUEST_TYPE_PARTICIPATION)
        "Complete the specified number of participation rounds"
    (if (is-eq quest-type QUEST_TYPE_STREAK)
        "Maintain a consecutive participation streak"
    (if (is-eq quest-type QUEST_TYPE_REFERRAL)
        "Successfully invite new users to join"
    (if (is-eq quest-type QUEST_TYPE_TEAM)
        "Contribute points to your team's score"
    (if (is-eq quest-type QUEST_TYPE_STAKING)
        "Stake the required amount of tokens"
        "Engage in social activities on the platform"))))))

(define-private (remove-from-active-quests (user principal) (quest-id uint))
    (let (
        (user-quests-data (default-to 
            { quest-1: none, quest-2: none, quest-3: none, count: u0 }
            (map-get? user-active-quests user)))
    )
        (map-set user-active-quests user
            (if (is-eq (get quest-1 user-quests-data) (some quest-id))
                { quest-1: none,
                  quest-2: (get quest-2 user-quests-data),
                  quest-3: (get quest-3 user-quests-data),
                  count: (- (get count user-quests-data) u1) }
                (if (is-eq (get quest-2 user-quests-data) (some quest-id))
                    { quest-1: (get quest-1 user-quests-data),
                      quest-2: none,
                      quest-3: (get quest-3 user-quests-data),
                      count: (- (get count user-quests-data) u1) }
                    { quest-1: (get quest-1 user-quests-data),
                      quest-2: (get quest-2 user-quests-data),
                      quest-3: none,
                      count: (- (get count user-quests-data) u1) })))
        (ok true)))

;; Read-only functions
(define-read-only (get-quest-details (quest-id uint))
    (map-get? quests quest-id))

(define-read-only (get-user-quest-progress (user principal) (quest-id uint))
    (map-get? user-quests { user: user, quest-id: quest-id }))

(define-read-only (get-user-quest-stats (user principal))
    (map-get? user-quest-stats user))

(define-read-only (get-user-active-quests (user principal))
    (map-get? user-active-quests user))

(define-read-only (get-daily-quest-pool (pool-index uint))
    (map-get? daily-quest-pool pool-index))

(define-read-only (get-quest-pool-size)
    (var-get daily-pool-size))

(define-read-only (get-system-stats)
    { total-quests-generated: (var-get quest-counter),
      generation-active: (var-get quest-generation-active),
      max-quests-per-user: (var-get max-active-quests-per-user),
      current-seed: (var-get daily-quest-seed) })

;; Admin functions
(define-public (toggle-quest-generation)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (var-set quest-generation-active (not (var-get quest-generation-active)))
        (ok (var-get quest-generation-active))))

(define-public (set-max-active-quests (max-quests uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (var-set max-active-quests-per-user max-quests)
        (ok true)))

(define-public (emergency-complete-quest (user principal) (quest-id uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (try! (complete-quest user quest-id))
        (ok true)))

;; Initialize contract
(unwrap-panic (initialize-quest-templates))


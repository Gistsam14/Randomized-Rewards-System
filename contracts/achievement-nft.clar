(define-trait nft-trait
  ((transfer (uint principal principal) (response bool uint))
   (get-owner (uint) (response (optional principal) uint))
   (get-last-token-id () (response uint uint))))

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u700))
(define-constant ERR_NOT_TOKEN_OWNER (err u701))
(define-constant ERR_TOKEN_NOT_FOUND (err u702))
(define-constant ERR_ALREADY_CLAIMED (err u703))

(define-non-fungible-token achievement-nft uint)

(define-data-var last-token-id uint u0)
(define-data-var token-mint-price uint u100)

(define-map token-metadata uint 
  { achievement-type: (string-ascii 50),
    rarity: uint,
    mint-height: uint,
    special-attributes: (string-ascii 200) })

(define-map user-achievements principal (list 20 uint))
(define-map achievement-claimed { user: principal, achievement-id: uint } bool)

(define-constant ACHIEVEMENT_FIRST_WIN u1)
(define-constant ACHIEVEMENT_STREAK_5 u2)  
(define-constant ACHIEVEMENT_STREAK_10 u3)
(define-constant ACHIEVEMENT_HIGH_ROLLER u4)
(define-constant ACHIEVEMENT_COMMUNITY_HERO u5)

(define-map achievement-definitions uint
  { name: (string-ascii 50),
    description: (string-ascii 200),
    rarity: uint,
    criteria-value: uint })

(define-private (setup-achievements)
  (begin
    (map-set achievement-definitions ACHIEVEMENT_FIRST_WIN
      { name: "First Victory",
        description: "Won your first reward round",
        rarity: u1,
        criteria-value: u1 })
    (map-set achievement-definitions ACHIEVEMENT_STREAK_5  
      { name: "Streak Master",
        description: "Participated in 5 consecutive rounds",
        rarity: u2,
        criteria-value: u5 })
    (map-set achievement-definitions ACHIEVEMENT_STREAK_10
      { name: "Dedication Legend", 
        description: "Participated in 10 consecutive rounds",
        rarity: u3,
        criteria-value: u10 })
    (map-set achievement-definitions ACHIEVEMENT_HIGH_ROLLER
      { name: "High Roller",
        description: "Staked over 5000 STX tokens",
        rarity: u3,
        criteria-value: u5000 })
    (map-set achievement-definitions ACHIEVEMENT_COMMUNITY_HERO
      { name: "Community Hero",
        description: "Referred 10 new players",
        rarity: u4,
        criteria-value: u10 })))

(define-public (mint-achievement (recipient principal) (achievement-id uint))
  (let (
    (token-id (+ (var-get last-token-id) u1))
    (achievement-data (unwrap! (map-get? achievement-definitions achievement-id) ERR_TOKEN_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (not (default-to false (map-get? achievement-claimed 
      { user: recipient, achievement-id: achievement-id }))) ERR_ALREADY_CLAIMED)
    
    (try! (nft-mint? achievement-nft token-id recipient))
    (map-set token-metadata token-id
      { achievement-type: (get name achievement-data),
        rarity: (get rarity achievement-data), 
        mint-height: stacks-block-height,
        special-attributes: (get description achievement-data) })
    (map-set achievement-claimed { user: recipient, achievement-id: achievement-id } true)
    (var-set last-token-id token-id)
    (update-user-achievements recipient token-id)
    (ok token-id)))

(define-private (update-user-achievements (user principal) (token-id uint))
  (let ((current-achievements (default-to (list) (map-get? user-achievements user))))
    (map-set user-achievements user (unwrap-panic (as-max-len? (append current-achievements token-id) u20)))))

(define-public (transfer-achievement (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq sender (unwrap! (nft-get-owner? achievement-nft token-id) ERR_TOKEN_NOT_FOUND)) ERR_NOT_TOKEN_OWNER)
    (try! (nft-transfer? achievement-nft token-id sender recipient))
    (ok true)))

(define-public (check-and-mint-achievement (user principal) (achievement-type uint) (user-stats-value uint))
  (let (
    (achievement-data (unwrap! (map-get? achievement-definitions achievement-type) ERR_TOKEN_NOT_FOUND))
    (criteria-met (>= user-stats-value (get criteria-value achievement-data)))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (if criteria-met
      (mint-achievement user achievement-type)
      (ok u0))))

(define-read-only (get-token-metadata (token-id uint))
  (map-get? token-metadata token-id))

(define-read-only (get-user-achievements (user principal))
  (default-to (list) (map-get? user-achievements user)))

(define-read-only (get-achievement-definition (achievement-id uint))
  (map-get? achievement-definitions achievement-id))

(define-read-only (has-achievement (user principal) (achievement-id uint))
  (default-to false (map-get? achievement-claimed { user: user, achievement-id: achievement-id })))

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id)))

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? achievement-nft token-id)))

(define-read-only (get-rarity-count (rarity uint))
  (fold count-rarity (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20) u0))

(define-private (count-rarity (token-id uint) (acc uint))
  (match (map-get? token-metadata token-id)
    metadata (if (is-eq (get rarity metadata) acc) (+ acc u1) acc)
    acc))

(setup-achievements)

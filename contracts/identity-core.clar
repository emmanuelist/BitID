;; BitID: Identity Core Contract

(use-trait sip009-nft-trait .sip009-nft-trait.sip009-nft-trait)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-expired (err u104))

;; Data Variables
(define-data-var next-identity-id uint u0)

;; Maps
(define-map identities principal uint)
(define-map identity-details
  uint
  {
    owner: principal,
    username: (string-ascii 50),
    pubkey: (buff 33),
    created-at: uint,
    last-updated: uint,
    recovery-address: (optional principal),
    is-active: bool
  }
)
(define-map identity-delegates {identity-id: uint, delegate: principal} {expires-at: uint})
(define-map nft-ownership {identity-id: uint, nft-contract: principal} (list 10 uint))

;; Private Functions
(define-private (is-owner (id uint))
  (let ((identity (unwrap! (map-get? identity-details id) false)))
    (is-eq tx-sender (get owner identity))
  )
)

(define-private (is-delegate (id uint))
  (match (map-get? identity-delegates {identity-id: id, delegate: tx-sender})
    delegate-info (< block-height (get expires-at delegate-info))
    false
  )
)

(define-private (is-authorized (id uint))
  (or (is-owner id) (is-delegate id))
)

;; Public Functions
(define-public (create-identity (username (string-ascii 50)) (pubkey (buff 33)))
  (let
    (
      (new-id (var-get next-identity-id))
      (caller tx-sender)
    )
    (asserts! (is-none (map-get? identities caller)) err-already-exists)
    (map-set identities caller new-id)
    (map-set identity-details new-id
      {
        owner: caller,
        username: username,
        pubkey: pubkey,
        created-at: block-height,
        last-updated: block-height,
        recovery-address: none,
        is-active: true
      }
    )
    (var-set next-identity-id (+ new-id u1))
    (ok new-id)
  )
)

(define-public (update-identity (id uint) (new-username (string-ascii 50)) (new-pubkey (buff 33)))
  (let
    (
      (identity (unwrap! (map-get? identity-details id) err-not-found))
    )
    (asserts! (is-authorized id) err-unauthorized)
    (ok (map-set identity-details id
      (merge identity
        {
          username: new-username,
          pubkey: new-pubkey,
          last-updated: block-height
        }
      )
    ))
  )
)

(define-public (set-recovery-address (id uint) (recovery principal))
  (let
    (
      (identity (unwrap! (map-get? identity-details id) err-not-found))
    )
    (asserts! (is-owner id) err-unauthorized)
    (ok (map-set identity-details id
      (merge identity
        {recovery-address: (some recovery)}
      )
    ))
  )
)

(define-public (recover-identity (id uint) (new-owner principal))
  (let
    (
      (identity (unwrap! (map-get? identity-details id) err-not-found))
    )
    (asserts! (is-some (get recovery-address identity)) err-unauthorized)
    (asserts! (is-eq (some tx-sender) (get recovery-address identity)) err-unauthorized)
    (map-set identities new-owner id)
    (ok (map-set identity-details id
      (merge identity
        {
          owner: new-owner,
          recovery-address: none,
          last-updated: block-height
        }
      )
    ))
  )
)

(define-public (add-delegate (id uint) (delegate principal) (expires-in uint))
  (let
    (
      (identity (unwrap! (map-get? identity-details id) err-not-found))
    )
    (asserts! (is-owner id) err-unauthorized)
    (ok (map-set identity-delegates
      {identity-id: id, delegate: delegate}
      {expires-at: (+ block-height expires-in)}
    ))
  )
)

(define-public (remove-delegate (id uint) (delegate principal))
  (let
    (
      (identity (unwrap! (map-get? identity-details id) err-not-found))
    )
    (asserts! (is-owner id) err-unauthorized)
    (ok (map-delete identity-delegates {identity-id: id, delegate: delegate}))
  )
)

(define-public (disable-identity (id uint))
  (let
    (
      (identity (unwrap! (map-get? identity-details id) err-not-found))
    )
    (asserts! (or (is-eq tx-sender contract-owner) (is-owner id)) err-unauthorized)
    (ok (map-set identity-details id
      (merge identity {is-active: false})
    ))
  )
)

(define-public (add-nft (id uint) (nft-contract <sip009-nft-trait>) (token-id uint))
  (let
    (
      (identity (unwrap! (map-get? identity-details id) err-not-found))
      (owner (unwrap! (contract-call? nft-contract get-owner token-id) err-unauthorized))
    )
    (asserts! (is-authorized id) err-unauthorized)
    (asserts! (is-eq (get owner identity) owner) err-unauthorized)
    (let
      (
        (current-nfts (default-to (list) (map-get? nft-ownership {identity-id: id, nft-contract: (contract-of nft-contract)})))
      )
      (ok (map-set nft-ownership
        {identity-id: id, nft-contract: (contract-of nft-contract)}
        (unwrap! (as-max-len? (append current-nfts token-id) u10) err-unauthorized)
      ))
    )
  )
)

;; Read-only Functions
(define-read-only (get-identity (id uint))
  (map-get? identity-details id)
)

(define-read-only (get-identity-by-owner (owner principal))
  (match (map-get? identities owner)
    id (get-identity id)
    none
  )
)

(define-read-only (get-delegates (id uint))
  (fold check-delegate (map-to-list identity-delegates) (list))
)

(define-private (check-delegate (entry {key: {identity-id: uint, delegate: principal}, value: {expires-at: uint}}) (result (list 10 principal)))
  (if (and
        (is-eq (get identity-id (get key entry)) id)
        (< block-height (get expires-at (get value entry)))
      )
    (unwrap! (as-max-len? (append result (get delegate (get key entry))) u10) result)
    result
  )
)

(define-read-only (get-nfts (id uint))
  (map-to-list nft-ownership)
)
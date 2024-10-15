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
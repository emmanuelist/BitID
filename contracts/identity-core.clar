(use-trait sip009-nft-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.sip009-nft-trait.sip009-nft-trait)

;; Constants
(define-data-var contract-owner principal tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-expired (err u104))
(define-constant err-invalid-input (err u105))

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
(define-map identity-delegate-list uint (list 10 principal))

;; Private Functions
(define-private (is-valid-username (username (string-ascii 50)))
  (let
    (
      (length (len username))
    )
    (and
      (>= length u3)            ;; minimum 3 characters
      (<= length u50)           ;; maximum 50 characters
      (is-valid-char (unwrap-panic (element-at username u0))) ;; first character must be valid
    )
  )
)

(define-private (is-valid-char (char (string-ascii 1)))
  (or 
    ;; Check if character is alphanumeric (0-9, a-z, A-Z)
    (match (index-of "0123456789" char) num true false)
    (match (index-of "abcdefghijklmnopqrstuvwxyz" char) num true false)
    (match (index-of "ABCDEFGHIJKLMNOPQRSTUVWXYZ" char) num true false)
    ;; Check if character is allowed special character
    (match (index-of "-_" char) num true false)
  )
)

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

(define-private (is-valid-pubkey (pubkey (buff 33)))
  (is-eq (len pubkey) u33)  ;; Must be exactly 33 bytes for compressed public key
)

(define-private (is-valid-expiration (expires-in uint))
  (and 
    (> expires-in u0)
    (<= expires-in u52560000) ;; Max ~1 year in blocks (assuming 10 min blocks)
  )
)

;; Public Functions
(define-public (create-identity (username (string-ascii 50)) (pubkey (buff 33)))
  (let
    (
      (new-id (var-get next-identity-id))
      (caller tx-sender)
    )
    (asserts! (is-valid-username username) err-invalid-input)
    (asserts! (is-valid-pubkey pubkey) err-invalid-input)
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
    (asserts! (is-valid-username new-username) err-invalid-input)
    (asserts! (is-valid-pubkey new-pubkey) err-invalid-input)
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
    (asserts! (not (is-eq new-owner (get owner identity))) err-invalid-input)
    
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
      (current-delegates (default-to (list) (map-get? identity-delegate-list id)))
    )
    (asserts! (is-valid-expiration expires-in) err-invalid-input)
    (asserts! (not (is-eq delegate (get owner identity))) err-invalid-input)
    (asserts! (is-owner id) err-unauthorized)
    
    (asserts! (not (is-some (index-of current-delegates delegate))) err-already-exists)
    
    (map-set identity-delegates
      {identity-id: id, delegate: delegate}
      {expires-at: (+ block-height expires-in)}
    )
    
    (ok (map-set identity-delegate-list
      id
      (unwrap! (as-max-len? (append current-delegates delegate) u10) err-unauthorized))
    ))
)

(define-public (remove-delegate (id uint) (delegate principal))
  (let
    (
      (identity (unwrap! (map-get? identity-details id) err-not-found))
      (delegate-info (map-get? identity-delegates {identity-id: id, delegate: delegate}))
    )
    (asserts! (is-owner id) err-unauthorized)
    (asserts! (is-some delegate-info) err-not-found)
    
    (ok (map-delete identity-delegates {identity-id: id, delegate: delegate}))
  )
)

(define-public (disable-identity (id uint))
  (let
    (
      (identity (unwrap! (map-get? identity-details id) err-not-found))
    )
    (asserts! (or (is-eq tx-sender (var-get contract-owner)) (is-owner id)) err-unauthorized)
    (asserts! (get is-active identity) err-invalid-input)
    
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
  (default-to (list) (map-get? identity-delegate-list id))
)

(define-read-only (get-nfts (id uint) (nft-contract principal))
  (default-to (list) (map-get? nft-ownership {identity-id: id, nft-contract: nft-contract}))
)

;; Contract Owner Functions
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) err-owner-only)
    (ok (var-set contract-owner new-owner))
  )
)
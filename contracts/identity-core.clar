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
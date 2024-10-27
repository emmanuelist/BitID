;; SIP009 NFT trait definition
(define-trait sip009-nft-trait
  (
    ;; Last token ID, limited to uint range
    (get-last-token-id () (response uint uint))
    
    ;; URI for metadata associated with the token
    (get-token-uri (uint) (response (optional (string-ascii 256)) uint))
    
    ;; Owner of a given token identifier
    (get-owner (uint) (response principal uint))
    
    ;; Transfer token to a specified principal
    (transfer (uint principal principal) (response bool uint))
  )
)
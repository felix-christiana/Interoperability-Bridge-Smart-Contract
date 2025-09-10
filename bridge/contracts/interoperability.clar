;; Interoperability Bridge Contract
;; Enables cross-chain asset transfers with security features

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_BRIDGE_PAUSED (err u102))
(define-constant ERR_INSUFFICIENT_BALANCE (err u103))
(define-constant ERR_INVALID_CHAIN (err u104))
(define-constant ERR_DUPLICATE_TX (err u105))
(define-constant ERR_VALIDATOR_EXISTS (err u106))
(define-constant ERR_NOT_VALIDATOR (err u107))
(define-constant ERR_INSUFFICIENT_SIGNATURES (err u108))
(define-constant ERR_INVALID_INPUT (err u109))

;; Data Variables
(define-data-var bridge-paused bool false)
(define-data-var min-transfer-amount uint u1000000) ;; 1 STX
(define-data-var max-transfer-amount uint u100000000000) ;; 1000 STX
(define-data-var bridge-fee uint u10000) ;; 0.01 STX
(define-data-var required-signatures uint u3)

;; Maps
(define-map supported-chains uint bool)
(define-map validators principal bool)
(define-map processed-transactions {chain-id: uint, tx-hash: (buff 32)} bool)
(define-map pending-transfers 
  uint 
  {sender: principal, amount: uint, target-chain: uint, recipient: (buff 32), block-height: uint})
(define-map validator-signatures {transfer-id: uint, validator: principal} bool)
(define-map transfer-signature-count uint uint)
(define-map user-balances principal uint)

;; Data Variables for tracking
(define-data-var next-transfer-id uint u1)
(define-data-var total-locked uint u0)

;; Initialize supported chains and validators
(map-set supported-chains u1 true) ;; Ethereum
(map-set supported-chains u56 true) ;; BSC
(map-set supported-chains u137 true) ;; Polygon

;; Owner functions
(define-public (add-validator (validator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? validators validator)) ERR_VALIDATOR_EXISTS)
    (ok (map-set validators validator true))))

(define-public (remove-validator (validator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? validators validator)) ERR_NOT_VALIDATOR)
    (ok (map-delete validators validator))))

(define-public (set-bridge-pause (paused bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (ok (var-set bridge-paused paused))))

(define-public (set-transfer-limits (min-amount uint) (max-amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> min-amount u0) ERR_INVALID_INPUT)
    (asserts! (> max-amount min-amount) ERR_INVALID_INPUT)
    (asserts! (<= max-amount u1000000000000) ERR_INVALID_INPUT) ;; Max 10,000 STX
    (var-set min-transfer-amount min-amount)
    (ok (var-set max-transfer-amount max-amount))))

(define-public (set-bridge-fee (fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= fee u100000000) ERR_INVALID_INPUT) ;; Max 1 STX fee
    (ok (var-set bridge-fee fee))))

(define-public (set-required-signatures (count uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (and (> count u0) (<= count u10)) ERR_INVALID_INPUT)
    (ok (var-set required-signatures count))))

(define-public (add-supported-chain (chain-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (and (> chain-id u0) (<= chain-id u1000000)) ERR_INVALID_INPUT)
    (ok (map-set supported-chains chain-id true))))

;; Bridge functions
(define-public (initiate-transfer (amount uint) (target-chain uint) (recipient (buff 32)))
  (let ((transfer-id (var-get next-transfer-id))
        (total-amount (+ amount (var-get bridge-fee))))
    (asserts! (not (var-get bridge-paused)) ERR_BRIDGE_PAUSED)
    (asserts! (>= amount (var-get min-transfer-amount)) ERR_INVALID_AMOUNT)
    (asserts! (<= amount (var-get max-transfer-amount)) ERR_INVALID_AMOUNT)
    (asserts! (> (len recipient) u0) ERR_INVALID_INPUT)
    (asserts! (<= (len recipient) u32) ERR_INVALID_INPUT)
    (asserts! (default-to false (map-get? supported-chains target-chain)) ERR_INVALID_CHAIN)
    (asserts! (>= (stx-get-balance tx-sender) total-amount) ERR_INSUFFICIENT_BALANCE)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))
    
    ;; Store pending transfer
    (map-set pending-transfers transfer-id
      {sender: tx-sender, amount: amount, target-chain: target-chain, 
       recipient: recipient, block-height: block-height})
    
    ;; Update tracking variables
    (var-set next-transfer-id (+ transfer-id u1))
    (var-set total-locked (+ (var-get total-locked) amount))
    
    ;; Emit event via print
    (print {event: "transfer-initiated", transfer-id: transfer-id, 
            sender: tx-sender, amount: amount, target-chain: target-chain})
    (ok transfer-id)))

(define-public (validate-transfer (transfer-id uint))
  (let ((transfer-data (unwrap! (map-get? pending-transfers transfer-id) ERR_INVALID_AMOUNT))
        (current-sigs (default-to u0 (map-get? transfer-signature-count transfer-id))))
    (asserts! (> transfer-id u0) ERR_INVALID_INPUT)
    (asserts! (< transfer-id (var-get next-transfer-id)) ERR_INVALID_INPUT)
    (asserts! (default-to false (map-get? validators tx-sender)) ERR_NOT_VALIDATOR)
    (asserts! (is-none (map-get? validator-signatures {transfer-id: transfer-id, validator: tx-sender})) 
              ERR_DUPLICATE_TX)
    
    ;; Record validator signature
    (map-set validator-signatures {transfer-id: transfer-id, validator: tx-sender} true)
    (map-set transfer-signature-count transfer-id (+ current-sigs u1))
    
    ;; Check if we have enough signatures
    (if (>= (+ current-sigs u1) (var-get required-signatures))
        (begin
          ;; Complete the transfer
          (map-delete pending-transfers transfer-id)
          (print {event: "transfer-validated", transfer-id: transfer-id, 
                  signatures: (+ current-sigs u1)})
          (ok true))
        (begin
          (print {event: "signature-added", transfer-id: transfer-id, 
                  validator: tx-sender, total-sigs: (+ current-sigs u1)})
          (ok false)))))

(define-public (complete-incoming-transfer 
  (amount uint) (recipient principal) (source-chain uint) (tx-hash (buff 32)))
  (begin
    (asserts! (default-to false (map-get? validators tx-sender)) ERR_NOT_VALIDATOR)
    (asserts! (> amount u0) ERR_INVALID_INPUT)
    (asserts! (<= amount u1000000000000) ERR_INVALID_INPUT) ;; Max 10,000 STX
    (asserts! (and (> source-chain u0) (<= source-chain u1000000)) ERR_INVALID_INPUT)
    (asserts! (> (len tx-hash) u0) ERR_INVALID_INPUT)
    (asserts! (is-none (map-get? processed-transactions {chain-id: source-chain, tx-hash: tx-hash})) 
              ERR_DUPLICATE_TX)
    (asserts! (>= (stx-get-balance (as-contract tx-sender)) amount) ERR_INSUFFICIENT_BALANCE)
    
    ;; Mark transaction as processed
    (map-set processed-transactions {chain-id: source-chain, tx-hash: tx-hash} true)
    
    ;; Transfer STX to recipient
    (try! (as-contract (stx-transfer? amount tx-sender recipient)))
    
    ;; Update total locked
    (var-set total-locked (- (var-get total-locked) amount))
    
    (print {event: "incoming-transfer-completed", recipient: recipient, 
            amount: amount, source-chain: source-chain})
    (ok true)))

(define-public (emergency-withdraw (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_INPUT)
    (asserts! (>= (stx-get-balance (as-contract tx-sender)) amount) ERR_INSUFFICIENT_BALANCE)
    (as-contract (stx-transfer? amount tx-sender CONTRACT_OWNER))))

;; Read-only functions
(define-read-only (get-transfer-info (transfer-id uint))
  (map-get? pending-transfers transfer-id))

(define-read-only (get-signature-count (transfer-id uint))
  (default-to u0 (map-get? transfer-signature-count transfer-id)))

(define-read-only (is-validator (address principal))
  (default-to false (map-get? validators address)))

(define-read-only (is-chain-supported (chain-id uint))
  (default-to false (map-get? supported-chains chain-id)))

(define-read-only (get-bridge-config)
  {bridge-paused: (var-get bridge-paused),
   min-transfer: (var-get min-transfer-amount),
   max-transfer: (var-get max-transfer-amount),
   bridge-fee: (var-get bridge-fee),
   required-sigs: (var-get required-signatures),
   total-locked: (var-get total-locked)})

(define-read-only (is-transaction-processed (chain-id uint) (tx-hash (buff 32)))
  (default-to false (map-get? processed-transactions {chain-id: chain-id, tx-hash: tx-hash})))

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender)))

(define-read-only (get-next-transfer-id)
  (var-get next-transfer-id))

(define-read-only (has-validator-signed (transfer-id uint) (validator principal))
  (default-to false (map-get? validator-signatures {transfer-id: transfer-id, validator: validator})))

;; Initialization
(begin
  (map-set validators CONTRACT_OWNER true)
  (print {event: "bridge-deployed", owner: CONTRACT_OWNER}))
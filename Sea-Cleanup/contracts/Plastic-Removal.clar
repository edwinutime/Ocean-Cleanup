;; Ocean Cleanup Incentive System Smart Contract
;; This contract creates a decentralized system to incentivize ocean plastic cleanup
;; by rewarding participants with tokens based on their verified cleanup contributions

;; Contract owner and administrative controls
(define-constant CONTRACT-OWNER tx-sender)

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-INSUFFICIENT-FUNDS (err u102))
(define-constant ERR-USER-NOT-FOUND (err u103))
(define-constant ERR-CLEANUP-NOT-FOUND (err u104))
(define-constant ERR-ALREADY-VERIFIED (err u105))
(define-constant ERR-INVALID-LOCATION (err u106))
(define-constant ERR-REWARD-CALCULATION-ERROR (err u107))
(define-constant ERR-TRANSFER-FAILED (err u108))
(define-constant ERR-INVALID-VALIDATOR (err u109))
(define-constant ERR-CLEANUP-EXPIRED (err u110))

;; Validation constants
(define-constant MIN-PLASTIC-AMOUNT u1) ;; Minimum 1kg of plastic
(define-constant MAX-PLASTIC-AMOUNT u10000) ;; Maximum 10,000kg per cleanup
(define-constant REWARD-PER-KG u100) ;; 100 tokens per kg of plastic
(define-constant BONUS-MULTIPLIER u150) ;; 150% bonus for verified cleanups
(define-constant CLEANUP-VALIDITY-PERIOD u144) ;; 144 blocks (~24 hours) to verify
(define-constant MAX-LOCATION-LENGTH u100) ;; Maximum characters for location string
(define-constant MIN-PHOTO-HASH-LENGTH u32) ;; Minimum length for IPFS hash (32 chars for short hash)
(define-constant MAX-PHOTO-HASH-LENGTH u64) ;; Maximum length for IPFS hash (64 chars for full hash)

;; Contract configuration variables
(define-data-var contract-active bool true)
(define-data-var total-plastic-removed uint u0)
(define-data-var total-rewards-distributed uint u0)
(define-data-var reward-pool uint u1000000) ;; Initial reward pool of 1M tokens
(define-data-var minimum-validator-stake uint u10000) ;; Minimum stake for validators

;; Data structures for cleanup records
;; Each cleanup record contains all necessary information about a cleanup event
(define-map cleanup-records
    uint ;; cleanup-id
    {
        participant: principal, ;; Who performed the cleanup
        location: (string-ascii 100), ;; Where the cleanup occurred
        plastic-amount: uint, ;; Amount of plastic removed in kg
        timestamp: uint, ;; Block height when submitted
        verified: bool, ;; Whether cleanup has been verified
        verifier: (optional principal), ;; Who verified the cleanup
        reward-amount: uint, ;; Tokens earned from this cleanup
        photo-hash: (string-ascii 64) ;; IPFS hash of cleanup photo evidence
    }
)

;; Track participant statistics and performance
(define-map participant-stats
    principal ;; participant address
    {
        total-cleanups: uint, ;; Number of cleanups performed
        total-plastic: uint, ;; Total kg of plastic removed
        total-rewards: uint, ;; Total tokens earned
        reputation-score: uint, ;; Reputation based on verified cleanups
        joined-at: uint ;; Block height when first participated
    }
)

;; Validator registry for cleanup verification
;; Validators stake tokens to participate in verification process
(define-map validators
    principal ;; validator address
    {
        stake-amount: uint, ;; Amount staked by validator
        verifications-count: uint, ;; Number of cleanups verified
        reputation: uint, ;; Validator reputation score
        active: bool ;; Whether validator is currently active
    }
)

;; Location-based cleanup tracking for analytics
(define-map location-stats
    (string-ascii 100) ;; location identifier
    {
        total-cleanups: uint, ;; Cleanups at this location
        total-plastic: uint, ;; Total plastic removed from location
        last-cleanup: uint ;; Block height of most recent cleanup
    }
)

;; Counter for generating unique cleanup IDs
(define-data-var next-cleanup-id uint u1)

;; Token balance tracking for the reward system
(define-map token-balances principal uint)

;; Administrative function to pause/unpause contract in emergencies
(define-public (toggle-contract-status)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set contract-active (not (var-get contract-active)))
        (ok (var-get contract-active))
    )
)

;; Allow contract owner to adjust reward parameters based on token availability
(define-public (update-reward-pool (new-amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (> new-amount u0) ERR-INVALID-AMOUNT)
        (var-set reward-pool new-amount)
        (ok new-amount)
    )
)

;; Validators must stake tokens to participate in verification process
;; This ensures validators have skin in the game and discourages malicious behavior
(define-public (register-validator (stake-amount uint))
    (let ((current-balance (default-to u0 (map-get? token-balances tx-sender))))
        (asserts! (var-get contract-active) ERR-NOT-AUTHORIZED)
        (asserts! (>= stake-amount (var-get minimum-validator-stake)) ERR-INVALID-AMOUNT)
        (asserts! (>= current-balance stake-amount) ERR-INSUFFICIENT-FUNDS)
        
        ;; Transfer stake from validator to contract
        (map-set token-balances tx-sender (- current-balance stake-amount))
        
        ;; Register validator with initial stats
        (map-set validators tx-sender {
            stake-amount: stake-amount,
            verifications-count: u0,
            reputation: u100, ;; Starting reputation score
            active: true
        })
        (ok true)
    )
)

;; Core function for participants to submit cleanup claims
;; Participants provide evidence and details of their cleanup efforts
(define-public (submit-cleanup (location (string-ascii 100)) (plastic-amount uint) (photo-hash (string-ascii 64)))
    (let ((cleanup-id (var-get next-cleanup-id))
          (photo-hash-len (len photo-hash)))
        (asserts! (var-get contract-active) ERR-NOT-AUTHORIZED)
        (asserts! (and (>= plastic-amount MIN-PLASTIC-AMOUNT) (<= plastic-amount MAX-PLASTIC-AMOUNT)) ERR-INVALID-AMOUNT)
        (asserts! (and (> (len location) u0) (<= (len location) MAX-LOCATION-LENGTH)) ERR-INVALID-LOCATION)
        (asserts! (and (>= photo-hash-len MIN-PHOTO-HASH-LENGTH) (<= photo-hash-len MAX-PHOTO-HASH-LENGTH)) ERR-INVALID-AMOUNT)
        
        ;; Create cleanup record with submitted information
        (map-set cleanup-records cleanup-id {
            participant: tx-sender,
            location: location,
            plastic-amount: plastic-amount,
            timestamp: block-height,
            verified: false,
            verifier: none,
            reward-amount: u0,
            photo-hash: photo-hash
        })
        
        ;; Update participant statistics
        (update-participant-stats tx-sender plastic-amount u0)
        
        ;; Update location-based statistics
        (update-location-stats location plastic-amount)
        
        ;; Increment cleanup counter for next submission
        (var-set next-cleanup-id (+ cleanup-id u1))
        
        ;; Update global plastic removal counter
        (var-set total-plastic-removed (+ (var-get total-plastic-removed) plastic-amount))
        
        (ok cleanup-id)
    )
)

;; Validators can verify cleanup submissions to trigger reward distribution
;; Verification process includes checking evidence and validating claims
(define-public (verify-cleanup (cleanup-id uint) (approved bool))
    (let (
        (cleanup (unwrap! (map-get? cleanup-records cleanup-id) ERR-CLEANUP-NOT-FOUND))
        (validator (unwrap! (map-get? validators tx-sender) ERR-INVALID-VALIDATOR))
    )
        (asserts! (var-get contract-active) ERR-NOT-AUTHORIZED)
        (asserts! (get active validator) ERR-INVALID-VALIDATOR)
        (asserts! (is-eq (get verified cleanup) false) ERR-ALREADY-VERIFIED)
        (asserts! (<= (- block-height (get timestamp cleanup)) CLEANUP-VALIDITY-PERIOD) ERR-CLEANUP-EXPIRED)
        
        ;; Update cleanup record with verification results
        (map-set cleanup-records cleanup-id (merge cleanup {
            verified: approved,
            verifier: (some tx-sender)
        }))
        
        ;; If approved, calculate and distribute rewards
        (if approved
            (let ((reward-amount (calculate-reward (get plastic-amount cleanup) true)))
                (if (is-ok (distribute-reward (get participant cleanup) reward-amount cleanup-id))
                    (begin
                        ;; Update validator statistics for successful verification
                        (update-validator-stats tx-sender)
                        (ok true)
                    )
                    ERR-REWARD-CALCULATION-ERROR
                )
            )
            ;; If rejected, still update validator stats but no reward distribution
            (begin
                (update-validator-stats tx-sender)
                (ok false)
            )
        )
    )
)

;; Internal function to calculate rewards based on plastic amount and verification status
;; Verified cleanups receive bonus multiplier for additional incentive
(define-private (calculate-reward (plastic-amount uint) (verified bool))
    (let ((base-reward (* plastic-amount REWARD-PER-KG)))
        (if verified
            (/ (* base-reward BONUS-MULTIPLIER) u100) ;; Apply 150% bonus for verified cleanups
            base-reward ;; Base reward for unverified cleanups
        )
    )
)

;; Internal function to handle reward token distribution to participants
(define-private (distribute-reward (participant principal) (reward-amount uint) (cleanup-id uint))
    (let (
        (current-balance (default-to u0 (map-get? token-balances participant)))
        (current-pool (var-get reward-pool))
    )
        (asserts! (>= current-pool reward-amount) ERR-INSUFFICIENT-FUNDS)
        
        ;; Transfer tokens from reward pool to participant
        (map-set token-balances participant (+ current-balance reward-amount))
        (var-set reward-pool (- current-pool reward-amount))
        (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) reward-amount))
        
        ;; Update cleanup record with reward amount
        (let ((cleanup (unwrap! (map-get? cleanup-records cleanup-id) ERR-CLEANUP-NOT-FOUND)))
            (map-set cleanup-records cleanup-id (merge cleanup {
                reward-amount: reward-amount
            }))
        )
        
        ;; Update participant stats with reward information
        (update-participant-stats participant u0 reward-amount)
        (ok reward-amount)
    )
)

;; Internal helper function to update participant statistics
;; Tracks cleanup count, plastic removal, rewards, and reputation
(define-private (update-participant-stats (participant principal) (plastic-added uint) (reward-added uint))
    (let ((current-stats (default-to 
            {total-cleanups: u0, total-plastic: u0, total-rewards: u0, reputation-score: u50, joined-at: block-height}
            (map-get? participant-stats participant)
        )))
        (map-set participant-stats participant {
            total-cleanups: (+ (get total-cleanups current-stats) (if (> plastic-added u0) u1 u0)),
            total-plastic: (+ (get total-plastic current-stats) plastic-added),
            total-rewards: (+ (get total-rewards current-stats) reward-added),
            reputation-score: (calculate-reputation-score 
                (+ (get total-cleanups current-stats) (if (> plastic-added u0) u1 u0))
                (+ (get total-plastic current-stats) plastic-added)
            ),
            joined-at: (get joined-at current-stats)
        })
    )
)

;; Internal helper function to update location-based cleanup statistics
(define-private (update-location-stats (location (string-ascii 100)) (plastic-amount uint))
    (let ((current-stats (default-to 
            {total-cleanups: u0, total-plastic: u0, last-cleanup: u0}
            (map-get? location-stats location)
        )))
        (map-set location-stats location {
            total-cleanups: (+ (get total-cleanups current-stats) u1),
            total-plastic: (+ (get total-plastic current-stats) plastic-amount),
            last-cleanup: block-height
        })
    )
)

;; Internal helper function to update validator statistics after verification
(define-private (update-validator-stats (validator principal))
    (let ((current-stats (unwrap-panic (map-get? validators validator)))
          (new-reputation (+ (get reputation current-stats) u5)))
        (map-set validators validator (merge current-stats {
            verifications-count: (+ (get verifications-count current-stats) u1),
            reputation: (if (<= new-reputation u1000) new-reputation u1000) ;; Cap reputation at 1000
        }))
    )
)

;; Internal function to calculate participant reputation based on activity
;; Higher reputation for more cleanups and larger plastic removal amounts
(define-private (calculate-reputation-score (cleanups uint) (total-plastic uint))
    (let ((cleanup-score (* cleanups u10))
          (plastic-score (/ total-plastic u10))
          (total-score (+ cleanup-score plastic-score)))
        (if (<= total-score u1000) total-score u1000) ;; Cap reputation at 1000
    )
)

;; Public read-only function to get cleanup details
(define-read-only (get-cleanup-details (cleanup-id uint))
    (map-get? cleanup-records cleanup-id)
)

;; Public read-only function to get participant statistics
(define-read-only (get-participant-stats (participant principal))
    (map-get? participant-stats participant)
)

;; Public read-only function to get validator information
(define-read-only (get-validator-info (validator principal))
    (map-get? validators validator)
)

;; Public read-only function to get location statistics
(define-read-only (get-location-stats (location (string-ascii 100)))
    (map-get? location-stats location)
)

;; Public read-only function to get participant token balance
(define-read-only (get-token-balance (participant principal))
    (default-to u0 (map-get? token-balances participant))
)

;; Public read-only function to get global contract statistics
(define-read-only (get-global-stats)
    {
        total-plastic-removed: (var-get total-plastic-removed),
        total-rewards-distributed: (var-get total-rewards-distributed),
        reward-pool: (var-get reward-pool),
        contract-active: (var-get contract-active),
        next-cleanup-id: (var-get next-cleanup-id)
    }
)

;; Public read-only function to calculate potential reward for a given plastic amount
(define-read-only (estimate-reward (plastic-amount uint) (will-be-verified bool))
    (calculate-reward plastic-amount will-be-verified)
)

;; Emergency function for contract owner to withdraw remaining reward pool
;; Should only be used in extreme circumstances when contract needs to be decommissioned
(define-public (emergency-withdraw)
    (let ((current-pool (var-get reward-pool)))
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (> current-pool u0) ERR-INSUFFICIENT-FUNDS)
        
        (map-set token-balances CONTRACT-OWNER 
            (+ (default-to u0 (map-get? token-balances CONTRACT-OWNER)) current-pool))
        (var-set reward-pool u0)
        (ok current-pool)
    )
)

;; Function for validators to withdraw their stake when leaving the system
(define-public (withdraw-validator-stake)
    (let (
        (validator-info (unwrap! (map-get? validators tx-sender) ERR-INVALID-VALIDATOR))
        (stake-amount (get stake-amount validator-info))
    )
        (asserts! (get active validator-info) ERR-INVALID-VALIDATOR)
        
        ;; Deactivate validator
        (map-set validators tx-sender (merge validator-info {active: false}))
        
        ;; Return stake to validator
        (map-set token-balances tx-sender 
            (+ (default-to u0 (map-get? token-balances tx-sender)) stake-amount))
        
        (ok stake-amount)
    )
)
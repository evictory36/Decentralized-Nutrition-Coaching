;; Decentralized Nutrition Coaching Smart Contract
;; AI-powered nutrition advice with dietitian verification

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_INSUFFICIENT_BALANCE (err u104))
(define-constant ERR_CONSULTATION_NOT_PENDING (err u105))
(define-constant ERR_INVALID_RATING (err u106))
(define-constant ERR_ALREADY_RATED (err u107))

;; Data Variables
(define-data-var next-consultation-id uint u1)
(define-data-var platform-fee-rate uint u500) ;; 5% fee (500 basis points)

;; Data Maps
(define-map dietitians principal {
    name: (string-ascii 50),
    credentials: (string-ascii 100),
    specialization: (string-ascii 50),
    hourly-rate: uint,
    total-consultations: uint,
    average-rating: uint,
    is-verified: bool,
    is-active: bool
})

(define-map user-profiles principal {
    name: (string-ascii 50),
    age: uint,
    height: uint, ;; in cm
    weight: uint, ;; in kg
    activity-level: (string-ascii 20),
    dietary-restrictions: (string-ascii 100),
    health-goals: (string-ascii 100),
    created-at: uint
})

(define-map consultations uint {
    client: principal,
    dietitian: principal,
    ai-recommendation: (string-ascii 500),
    dietitian-feedback: (string-ascii 500),
    consultation-type: (string-ascii 20), ;; "ai-only", "verified", "custom"
    amount-paid: uint,
    status: (string-ascii 20), ;; "pending", "completed", "cancelled"
    created-at: uint,
    completed-at: (optional uint),
    rating: (optional uint)
})

(define-map nutrition-plans uint {
    consultation-id: uint,
    meal-plan: (string-ascii 1000),
    calorie-target: uint,
    macro-distribution: (string-ascii 100), ;; "protein:30,carbs:40,fat:30"
    supplements: (string-ascii 200),
    notes: (string-ascii 300),
    validity-period: uint ;; days
})

(define-map user-balances principal uint)

(define-map consultation-ratings uint {
    client: principal,
    dietitian: principal,
    rating: uint,
    review: (string-ascii 200),
    created-at: uint
})

;; Authorization Functions
(define-private (is-contract-owner)
    (is-eq tx-sender CONTRACT_OWNER))

(define-private (is-verified-dietitian (dietitian principal))
    (match (map-get? dietitians dietitian)
        dietitian-data (and (get is-verified dietitian-data) (get is-active dietitian-data))
        false))

;; Helper Functions
(define-private (get-balance (user principal))
    (default-to u0 (map-get? user-balances user)))

(define-private (calculate-platform-fee (amount uint))
    (/ (* amount (var-get platform-fee-rate)) u10000))

;; Public Functions

;; User Profile Management
(define-public (create-user-profile 
    (name (string-ascii 50))
    (age uint)
    (height uint)
    (weight uint)
    (activity-level (string-ascii 20))
    (dietary-restrictions (string-ascii 100))
    (health-goals (string-ascii 100)))
    (begin
        (asserts! (is-none (map-get? user-profiles tx-sender)) ERR_ALREADY_EXISTS)
        (ok (map-set user-profiles tx-sender {
            name: name,
            age: age,
            height: height,
            weight: weight,
            activity-level: activity-level,
            dietary-restrictions: dietary-restrictions,
            health-goals: health-goals,
            created-at: block-height
        }))))

(define-public (update-user-profile 
    (height uint)
    (weight uint)
    (activity-level (string-ascii 20))
    (dietary-restrictions (string-ascii 100))
    (health-goals (string-ascii 100)))
    (match (map-get? user-profiles tx-sender)
        profile (ok (map-set user-profiles tx-sender 
            (merge profile {
                height: height,
                weight: weight,
                activity-level: activity-level,
                dietary-restrictions: dietary-restrictions,
                health-goals: health-goals
            })))
        ERR_NOT_FOUND))

;; Dietitian Management
(define-public (register-dietitian 
    (name (string-ascii 50))
    (credentials (string-ascii 100))
    (specialization (string-ascii 50))
    (hourly-rate uint))
    (begin
        (asserts! (is-none (map-get? dietitians tx-sender)) ERR_ALREADY_EXISTS)
        (ok (map-set dietitians tx-sender {
            name: name,
            credentials: credentials,
            specialization: specialization,
            hourly-rate: hourly-rate,
            total-consultations: u0,
            average-rating: u0,
            is-verified: false,
            is-active: true
        }))))

(define-public (verify-dietitian (dietitian principal))
    (begin
        (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
        (match (map-get? dietitians dietitian)
            dietitian-data (ok (map-set dietitians dietitian 
                (merge dietitian-data { is-verified: true })))
            ERR_NOT_FOUND)))

(define-public (update-dietitian-rate (new-rate uint))
    (match (map-get? dietitians tx-sender)
        dietitian-data (ok (map-set dietitians tx-sender 
            (merge dietitian-data { hourly-rate: new-rate })))
        ERR_NOT_FOUND))

;; Balance Management
(define-public (deposit-funds)
    (let ((current-balance (get-balance tx-sender)))
        (map-set user-balances tx-sender (+ current-balance (stx-get-balance tx-sender)))
        (ok (+ current-balance (stx-get-balance tx-sender)))))

(define-public (withdraw-funds (amount uint))
    (let ((current-balance (get-balance tx-sender)))
        (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
        (map-set user-balances tx-sender (- current-balance amount))
        (stx-transfer? amount tx-sender tx-sender)))

;; Consultation Management
(define-public (request-ai-consultation 
    (ai-recommendation (string-ascii 500)))
    (let ((consultation-id (var-get next-consultation-id)))
        (asserts! (is-some (map-get? user-profiles tx-sender)) ERR_NOT_FOUND)
        (map-set consultations consultation-id {
            client: tx-sender,
            dietitian: CONTRACT_OWNER, ;; AI consultations handled by contract
            ai-recommendation: ai-recommendation,
            dietitian-feedback: "",
            consultation-type: "ai-only",
            amount-paid: u0,
            status: "completed",
            created-at: block-height,
            completed-at: (some block-height),
            rating: none
        })
        (var-set next-consultation-id (+ consultation-id u1))
        (ok consultation-id)))

(define-public (request-verified-consultation 
    (dietitian principal)
    (ai-recommendation (string-ascii 500)))
    (let ((consultation-id (var-get next-consultation-id))
          (dietitian-data (unwrap! (map-get? dietitians dietitian) ERR_NOT_FOUND))
          (consultation-fee (get hourly-rate dietitian-data))
          (platform-fee (calculate-platform-fee consultation-fee))
          (total-amount (+ consultation-fee platform-fee))
          (user-balance (get-balance tx-sender)))
        
        (asserts! (is-some (map-get? user-profiles tx-sender)) ERR_NOT_FOUND)
        (asserts! (is-verified-dietitian dietitian) ERR_UNAUTHORIZED)
        (asserts! (>= user-balance total-amount) ERR_INSUFFICIENT_BALANCE)
        
        (map-set user-balances tx-sender (- user-balance total-amount))
        (map-set consultations consultation-id {
            client: tx-sender,
            dietitian: dietitian,
            ai-recommendation: ai-recommendation,
            dietitian-feedback: "",
            consultation-type: "verified",
            amount-paid: total-amount,
            status: "pending",
            created-at: block-height,
            completed-at: none,
            rating: none
        })
        (var-set next-consultation-id (+ consultation-id u1))
        (ok consultation-id)))

(define-public (complete-consultation 
    (consultation-id uint)
    (dietitian-feedback (string-ascii 500)))
    (match (map-get? consultations consultation-id)
        consultation-data 
        (begin
            (asserts! (is-eq tx-sender (get dietitian consultation-data)) ERR_UNAUTHORIZED)
            (asserts! (is-eq (get status consultation-data) "pending") ERR_CONSULTATION_NOT_PENDING)
            
            (map-set consultations consultation-id 
                (merge consultation-data {
                    dietitian-feedback: dietitian-feedback,
                    status: "completed",
                    completed-at: (some block-height)
                }))
            
            ;; Pay the dietitian
            (let ((dietitian-payment (- (get amount-paid consultation-data) 
                                      (calculate-platform-fee (get amount-paid consultation-data))))
                  (current-dietitian-balance (get-balance (get dietitian consultation-data))))
                (map-set user-balances (get dietitian consultation-data) 
                    (+ current-dietitian-balance dietitian-payment)))
            
            ;; Update dietitian stats
            (match (map-get? dietitians (get dietitian consultation-data))
                dietitian-info (map-set dietitians (get dietitian consultation-data)
                    (merge dietitian-info { 
                        total-consultations: (+ (get total-consultations dietitian-info) u1)
                    }))
                false)
            
            (ok true))
        ERR_NOT_FOUND))

;; Nutrition Plan Management
(define-public (create-nutrition-plan 
    (consultation-id uint)
    (meal-plan (string-ascii 1000))
    (calorie-target uint)
    (macro-distribution (string-ascii 100))
    (supplements (string-ascii 200))
    (notes (string-ascii 300))
    (validity-period uint))
    (match (map-get? consultations consultation-id)
        consultation-data
        (begin
            (asserts! (is-eq tx-sender (get dietitian consultation-data)) ERR_UNAUTHORIZED)
            (asserts! (is-eq (get status consultation-data) "completed") ERR_CONSULTATION_NOT_PENDING)
            
            (ok (map-set nutrition-plans consultation-id {
                consultation-id: consultation-id,
                meal-plan: meal-plan,
                calorie-target: calorie-target,
                macro-distribution: macro-distribution,
                supplements: supplements,
                notes: notes,
                validity-period: validity-period
            })))
        ERR_NOT_FOUND))

;; Rating System
(define-public (rate-consultation 
    (consultation-id uint)
    (rating uint)
    (review (string-ascii 200)))
    (match (map-get? consultations consultation-id)
        consultation-data
        (begin
            (asserts! (is-eq tx-sender (get client consultation-data)) ERR_UNAUTHORIZED)
            (asserts! (is-eq (get status consultation-data) "completed") ERR_CONSULTATION_NOT_PENDING)
            (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
            (asserts! (is-none (get rating consultation-data)) ERR_ALREADY_RATED)
            
            ;; Update consultation with rating
            (map-set consultations consultation-id 
                (merge consultation-data { rating: (some rating) }))
            
            ;; Store detailed rating
            (map-set consultation-ratings consultation-id {
                client: tx-sender,
                dietitian: (get dietitian consultation-data),
                rating: rating,
                review: review,
                created-at: block-height
            })
            
            ;; Update dietitian average rating
            (match (map-get? dietitians (get dietitian consultation-data))
                dietitian-info 
                (let ((total-consultations (get total-consultations dietitian-info))
                      (current-avg (get average-rating dietitian-info))
                      (new-avg (/ (+ (* current-avg total-consultations) rating) 
                                (+ total-consultations u1))))
                    (map-set dietitians (get dietitian consultation-data)
                        (merge dietitian-info { average-rating: new-avg })))
                false)
            
            (ok true))
        ERR_NOT_FOUND))

;; Read-only Functions
(define-read-only (get-user-profile (user principal))
    (map-get? user-profiles user))

(define-read-only (get-dietitian-info (dietitian principal))
    (map-get? dietitians dietitian))

(define-read-only (get-consultation (consultation-id uint))
    (map-get? consultations consultation-id))

(define-read-only (get-nutrition-plan (consultation-id uint))
    (map-get? nutrition-plans consultation-id))

(define-read-only (get-user-balance (user principal))
    (get-balance user))

(define-read-only (get-platform-fee-rate)
    (var-get platform-fee-rate))

;; Admin Functions
(define-public (set-platform-fee-rate (new-rate uint))
    (begin
        (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
        (asserts! (<= new-rate u1000) ERR_INVALID_AMOUNT) ;; Max 10%
        (var-set platform-fee-rate new-rate)
        (ok new-rate)))

(define-public (deactivate-dietitian (dietitian principal))
    (begin
        (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
        (match (map-get? dietitians dietitian)
            dietitian-data (ok (map-set dietitians dietitian 
                (merge dietitian-data { is-active: false })))
            ERR_NOT_FOUND)))
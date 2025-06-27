;; Compliance Tracking Contract
;; Tracks revenue compliance with accounting standards

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_INVALID_RULE (err u301))
(define-constant ERR_COMPLIANCE_VIOLATION (err u302))
(define-constant ERR_NOT_FOUND (err u303))

;; Data Variables
(define-data-var next-rule-id uint u1)
(define-data-var compliance-score uint u100)

;; Data Maps
(define-map compliance-rules uint {
    name: (string-ascii 50),
    description: (string-ascii 200),
    threshold: uint,
    active: bool,
    created-by: principal
})

(define-map compliance-checks uint {
    rule-id: uint,
    entity-id: uint,
    check-date: uint,
    result: bool,
    score: uint,
    notes: (string-ascii 200)
})

(define-map entity-compliance uint {
    total-checks: uint,
    passed-checks: uint,
    failed-checks: uint,
    compliance-rate: uint,
    last-check: uint
})

;; Public Functions
(define-public (add-compliance-rule (name (string-ascii 50)) (description (string-ascii 200)) (threshold uint))
    (let ((rule-id (var-get next-rule-id)))
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set compliance-rules rule-id {
            name: name,
            description: description,
            threshold: threshold,
            active: true,
            created-by: tx-sender
        })
        (var-set next-rule-id (+ rule-id u1))
        (ok rule-id)
    )
)

(define-public (perform-compliance-check (rule-id uint) (entity-id uint) (score uint) (notes (string-ascii 200)))
    (let ((rule (unwrap! (map-get? compliance-rules rule-id) ERR_INVALID_RULE))
          (check-id (+ (* rule-id u10000) (* entity-id u100) block-height))
          (passed (>= score (get threshold rule))))
        (map-set compliance-checks check-id {
            rule-id: rule-id,
            entity-id: entity-id,
            check-date: block-height,
            result: passed,
            score: score,
            notes: notes
        })
        (let ((current-compliance (default-to {
                total-checks: u0,
                passed-checks: u0,
                failed-checks: u0,
                compliance-rate: u0,
                last-check: u0
            } (map-get? entity-compliance entity-id))))
            (map-set entity-compliance entity-id {
                total-checks: (+ (get total-checks current-compliance) u1),
                passed-checks: (+ (get passed-checks current-compliance) (if passed u1 u0)),
                failed-checks: (+ (get failed-checks current-compliance) (if passed u0 u1)),
                compliance-rate: (/ (* (+ (get passed-checks current-compliance) (if passed u1 u0)) u100)
                                   (+ (get total-checks current-compliance) u1)),
                last-check: block-height
            })
        )
        (ok passed)
    )
)

(define-public (update-rule-status (rule-id uint) (active bool))
    (let ((rule (unwrap! (map-get? compliance-rules rule-id) ERR_INVALID_RULE)))
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set compliance-rules rule-id (merge rule {active: active}))
        (ok true)
    )
)

;; Read-only Functions
(define-read-only (get-compliance-rule (rule-id uint))
    (map-get? compliance-rules rule-id)
)

(define-read-only (get-entity-compliance (entity-id uint))
    (map-get? entity-compliance entity-id)
)

(define-read-only (get-compliance-score)
    (var-get compliance-score)
)

(define-read-only (is-entity-compliant (entity-id uint) (minimum-rate uint))
    (match (map-get? entity-compliance entity-id)
        compliance (>= (get compliance-rate compliance) minimum-rate)
        false
    )
)

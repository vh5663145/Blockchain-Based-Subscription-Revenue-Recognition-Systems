;; Audit Management Contract
;; Manages revenue audit processes and trails

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_INVALID_AUDIT (err u501))
(define-constant ERR_AUDIT_EXISTS (err u502))
(define-constant ERR_NOT_FOUND (err u503))

;; Data Variables
(define-data-var next-audit-id uint u1)
(define-data-var audit-system-active bool true)

;; Data Maps
(define-map audits uint {
    audit-type: (string-ascii 30),
    entity-id: uint,
    auditor: principal,
    start-date: uint,
    end-date: uint,
    status: (string-ascii 20),
    findings-count: uint
})

(define-map audit-findings uint {
    audit-id: uint,
    finding-type: (string-ascii 50),
    severity: (string-ascii 20),
    description: (string-ascii 300),
    resolved: bool,
    resolution-date: uint
})

(define-map audit-trails uint {
    entity-id: uint,
    action: (string-ascii 100),
    timestamp: uint,
    user: principal,
    details: (string-ascii 200)
})

(define-map entity-audit-history uint {
    total-audits: uint,
    passed-audits: uint,
    failed-audits: uint,
    last-audit-date: uint,
    audit-score: uint
})

;; Public Functions
(define-public (create-audit (audit-type (string-ascii 30)) (entity-id uint) (auditor principal))
    (let ((audit-id (var-get next-audit-id)))
        (map-set audits audit-id {
            audit-type: audit-type,
            entity-id: entity-id,
            auditor: auditor,
            start-date: block-height,
            end-date: u0,
            status: "in-progress",
            findings-count: u0
        })
        (var-set next-audit-id (+ audit-id u1))
        (ok audit-id)
    )
)

(define-public (add-audit-finding (audit-id uint) (finding-type (string-ascii 50)) (severity (string-ascii 20)) (description (string-ascii 300)))
    (let ((audit (unwrap! (map-get? audits audit-id) ERR_INVALID_AUDIT))
          (finding-id (+ (* audit-id u1000) (get findings-count audit))))
        (asserts! (is-eq (get status audit) "in-progress") ERR_INVALID_AUDIT)
        (map-set audit-findings finding-id {
            audit-id: audit-id,
            finding-type: finding-type,
            severity: severity,
            description: description,
            resolved: false,
            resolution-date: u0
        })
        (map-set audits audit-id (merge audit {
            findings-count: (+ (get findings-count audit) u1)
        }))
        (ok finding-id)
    )
)

(define-public (complete-audit (audit-id uint) (passed bool))
    (let ((audit (unwrap! (map-get? audits audit-id) ERR_INVALID_AUDIT))
          (entity-id (get entity-id audit)))
        (map-set audits audit-id (merge audit {
            end-date: block-height,
            status: (if passed "passed" "failed")
        }))
        (let ((history (default-to {
                total-audits: u0,
                passed-audits: u0,
                failed-audits: u0,
                last-audit-date: u0,
                audit-score: u0
            } (map-get? entity-audit-history entity-id))))
            (map-set entity-audit-history entity-id {
                total-audits: (+ (get total-audits history) u1),
                passed-audits: (+ (get passed-audits history) (if passed u1 u0)),
                failed-audits: (+ (get failed-audits history) (if passed u0 u1)),
                last-audit-date: block-height,
                audit-score: (/ (* (+ (get passed-audits history) (if passed u1 u0)) u100)
                               (+ (get total-audits history) u1))
            })
        )
        (ok true)
    )
)

(define-public (log-audit-trail (entity-id uint) (action (string-ascii 100)) (details (string-ascii 200)))
    (let ((trail-id (+ (* entity-id u10000) block-height)))
        (map-set audit-trails trail-id {
            entity-id: entity-id,
            action: action,
            timestamp: block-height,
            user: tx-sender,
            details: details
        })
        (ok trail-id)
    )
)

;; Read-only Functions
(define-read-only (get-audit (audit-id uint))
    (map-get? audits audit-id)
)

(define-read-only (get-audit-finding (finding-id uint))
    (map-get? audit-findings finding-id)
)

(define-read-only (get-entity-audit-history (entity-id uint))
    (map-get? entity-audit-history entity-id)
)

(define-read-only (is-entity-audit-compliant (entity-id uint) (minimum-score uint))
    (match (map-get? entity-audit-history entity-id)
        history (>= (get audit-score history) minimum-score)
        false
    )
)

(define-read-only (get-total-audits)
    (- (var-get next-audit-id) u1)
)

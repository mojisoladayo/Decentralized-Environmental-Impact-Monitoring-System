;; reporting.clar
;; Generates authenticated environmental disclosures

(define-data-var admin principal tx-sender)

;; Map of reports
(define-map reports
  { report-id: (string-ascii 64) }
  {
    facility-id: (string-ascii 32),
    start-period: uint,
    end-period: uint,
    metrics: (list 10 {
      metric-type: (string-ascii 32),
      average-value: uint,
      max-value: uint,
      compliance-status: bool
    }),
    timestamp: uint,
    verified: bool,
    verifier: (optional principal)
  }
)

;; Map of authorized report generators
(define-map report-generators
  { generator: principal }
  { authorized: bool }
)

;; Map of authorized report verifiers
(define-map report-verifiers
  { verifier: principal }
  { authorized: bool }
)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-REPORT-NOT-FOUND (err u108))
(define-constant ERR-ALREADY-VERIFIED (err u109))

;; Create a report
(define-public (create-report
  (report-id (string-ascii 64))
  (facility-id (string-ascii 32))
  (start-period uint)
  (end-period uint)
  (metrics (list 10 {
    metric-type: (string-ascii 32),
    average-value: uint,
    max-value: uint,
    compliance-status: bool
  }))
)
  (let ((generator-status (map-get? report-generators { generator: tx-sender })))
    (asserts! (or
      (is-eq tx-sender (var-get admin))
      (and (is-some generator-status) (get authorized (unwrap! generator-status ERR-NOT-AUTHORIZED)))
    ) ERR-NOT-AUTHORIZED)

    (map-set reports
      { report-id: report-id }
      {
        facility-id: facility-id,
        start-period: start-period,
        end-period: end-period,
        metrics: metrics,
        timestamp: block-height,
        verified: false,
        verifier: none
      }
    )
    (ok true)
  )
)

;; Verify a report
(define-public (verify-report (report-id (string-ascii 64)))
  (let (
    (verifier-status (map-get? report-verifiers { verifier: tx-sender }))
    (report (map-get? reports { report-id: report-id }))
  )
    (asserts! (or
      (is-eq tx-sender (var-get admin))
      (and (is-some verifier-status) (get authorized (unwrap! verifier-status ERR-NOT-AUTHORIZED)))
    ) ERR-NOT-AUTHORIZED)
    (asserts! (is-some report) ERR-REPORT-NOT-FOUND)
    (asserts! (not (get verified (unwrap! report ERR-REPORT-NOT-FOUND))) ERR-ALREADY-VERIFIED)

    (map-set reports
      { report-id: report-id }
      (merge (unwrap! report ERR-REPORT-NOT-FOUND)
        {
          verified: true,
          verifier: (some tx-sender)
        }
      )
    )
    (ok true)
  )
)

;; Get report details
(define-read-only (get-report (report-id (string-ascii 64)))
  (map-get? reports { report-id: report-id })
)

;; Add a report generator (admin only)
(define-public (add-report-generator (generator principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (map-set report-generators
      { generator: generator }
      { authorized: true }
    )
    (ok true)
  )
)

;; Remove a report generator (admin only)
(define-public (remove-report-generator (generator principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (map-set report-generators
      { generator: generator }
      { authorized: false }
    )
    (ok true)
  )
)

;; Add a report verifier (admin only)
(define-public (add-report-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (map-set report-verifiers
      { verifier: verifier }
      { authorized: true }
    )
    (ok true)
  )
)

;; Remove a report verifier (admin only)
(define-public (remove-report-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (map-set report-verifiers
      { verifier: verifier }
      { authorized: false }
    )
    (ok true)
  )
)

;; Transfer admin rights (admin only)
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

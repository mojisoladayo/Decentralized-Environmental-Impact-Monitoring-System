;; alert-management.clar
;; Handles notification of violations

(define-data-var admin principal tx-sender)

;; Map of alerts
(define-map alerts
  { alert-id: (string-ascii 64) }
  {
    facility-id: (string-ascii 32),
    sensor-id: (string-ascii 32),
    metric-type: (string-ascii 32),
    value: uint,
    threshold: uint,
    timestamp: uint,
    resolved: bool,
    resolution-timestamp: (optional uint)
  }
)

;; Map of alert subscribers
(define-map alert-subscribers
  {
    facility-id: (string-ascii 32),
    subscriber: principal
  }
  { active: bool }
)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALERT-NOT-FOUND (err u106))
(define-constant ERR-ALREADY-RESOLVED (err u107))

;; Create an alert
(define-public (create-alert
  (alert-id (string-ascii 64))
  (facility-id (string-ascii 32))
  (sensor-id (string-ascii 32))
  (metric-type (string-ascii 32))
  (value uint)
  (threshold uint)
)
  (begin
    ;; In a real implementation, we would check if the caller is authorized
    ;; For simplicity, we'll allow anyone to create alerts

    (map-set alerts
      { alert-id: alert-id }
      {
        facility-id: facility-id,
        sensor-id: sensor-id,
        metric-type: metric-type,
        value: value,
        threshold: threshold,
        timestamp: block-height,
        resolved: false,
        resolution-timestamp: none
      }
    )
    (ok true)
  )
)

;; Resolve an alert
(define-public (resolve-alert (alert-id (string-ascii 64)))
  (let ((alert (map-get? alerts { alert-id: alert-id })))
    (asserts! (is-some alert) ERR-ALERT-NOT-FOUND)
    (asserts! (not (get resolved (unwrap! alert ERR-ALERT-NOT-FOUND))) ERR-ALREADY-RESOLVED)

    ;; In a real implementation, we would check if the caller is authorized
    ;; For simplicity, we'll allow anyone to resolve alerts

    (map-set alerts
      { alert-id: alert-id }
      (merge (unwrap! alert ERR-ALERT-NOT-FOUND)
        {
          resolved: true,
          resolution-timestamp: (some block-height)
        }
      )
    )
    (ok true)
  )
)

;; Subscribe to alerts for a facility
(define-public (subscribe-to-alerts (facility-id (string-ascii 32)))
  (begin
    (map-set alert-subscribers
      {
        facility-id: facility-id,
        subscriber: tx-sender
      }
      { active: true }
    )
    (ok true)
  )
)

;; Unsubscribe from alerts for a facility
(define-public (unsubscribe-from-alerts (facility-id (string-ascii 32)))
  (begin
    (map-set alert-subscribers
      {
        facility-id: facility-id,
        subscriber: tx-sender
      }
      { active: false }
    )
    (ok true)
  )
)

;; Check if a principal is subscribed to alerts for a facility
(define-read-only (is-subscribed (facility-id (string-ascii 32)) (subscriber principal))
  (let ((subscription (map-get? alert-subscribers { facility-id: facility-id, subscriber: subscriber })))
    (if (is-some subscription)
      (get active (unwrap! subscription false))
      false
    )
  )
)

;; Get alert details
(define-read-only (get-alert (alert-id (string-ascii 64)))
  (map-get? alerts { alert-id: alert-id })
)

;; Transfer admin rights (admin only)
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

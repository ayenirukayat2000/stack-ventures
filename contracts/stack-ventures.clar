;; ----------------------------------------------------------
;; Contract: stack-ventures.clar
;; A mega-contract combining freelance jobs, crowdfunding,
;; DAO arbitration, staking, NFTs, and milestone unlocks.
;; ----------------------------------------------------------

(define-trait i-nft
  ((mint (principal uint) (response uint uint))
   (transfer (uint principal principal) (response bool uint))
   (owner-of (uint) (response (optional principal) uint))))

;; -----------------------
;; Constants
;; -----------------------
(define-constant ERR-INVALID-JOB-ID (err u1000))
(define-constant ERR-INVALID-BUDGET (err u1001))
(define-constant ERR-INVALID-MILESTONE (err u1002))
(define-constant ERR-NOT-FOUND (err u1003))
(define-constant ERR-UNAUTHORIZED (err u1004))
(define-constant ERR-ALREADY-VOTED (err u1005))
(define-constant ERR-NOT-APPROVED (err u1006))
(define-constant ERR-ALREADY-RELEASED (err u1007))
(define-constant ERR-ALREADY-EXECUTED (err u1008))

;; -----------------------
;; Data Maps & Variables
;; -----------------------
(define-map jobs
  uint  ;; job-id
  {
    client: principal,
    freelancer: (optional principal),
    budget: uint,
    milestone: uint,
    funded: bool,
    status: (string-ascii 20)
  })

(define-map milestones
  {job-id: uint, ms-id: uint}
  {
    amount: uint,
    approved: bool,
    released: bool
  })

(define-map backers
  {job-id: uint, backer: principal}
  {
    staked: uint,
    voted: bool
  })

(define-map reputation
  principal  ;; user
  {
    score: int
  })

(define-map proposals
  uint  ;; proposal-id
  {
    proposer: principal,
    description: (string-ascii 200),
    votes-for: uint,
    votes-against: uint,
    executed: bool
  })

(define-data-var job-counter uint u0)
(define-data-var proposal-counter uint u0)

;; -----------------------
;; Functions
;; -----------------------

;; JOB FUNCTIONS
(define-private (check-uint (value uint) (min uint))
  (> value min))

(define-private (check-valid-job (job-id uint))
  (is-some (map-get? jobs job-id)))

(define-public (post-job (budget uint) (milestone uint))
  (begin
    (asserts! (check-uint budget u0) ERR-INVALID-BUDGET)
    (asserts! (check-uint milestone u0) ERR-INVALID-MILESTONE)
    (let 
      ((id (+ (var-get job-counter) u1)))
      (var-set job-counter id)
      (map-set jobs id
        {
          client: tx-sender,
          freelancer: none,
          budget: budget,
          milestone: milestone,
          funded: false,
          status: "open"
        })
      (ok id))))

(define-public (apply-job (job-id uint))
  (begin
    (asserts! (check-valid-job job-id) ERR-NOT-FOUND)
    (let 
      ((job (unwrap! (map-get? jobs job-id) ERR-NOT-FOUND)))
      (asserts! (is-eq (get freelancer job) none) ERR-UNAUTHORIZED)
      (map-set jobs job-id
        (merge job {freelancer: (some tx-sender)}))
      (ok true))))

(define-public (fund-job (job-id uint) (amount uint))
  (begin
    (asserts! (check-valid-job job-id) ERR-NOT-FOUND)
    (asserts! (check-uint amount u0) ERR-INVALID-BUDGET)
    (let ((job (unwrap! (map-get? jobs job-id) ERR-NOT-FOUND)))
      (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      (map-set jobs job-id 
        (merge job {funded: true}))
      (ok true))))

;; MILESTONE FUNCTIONS
(define-public (vote-milestone (job-id uint) (ms-id uint) (approve bool))
  (begin
    (asserts! (check-valid-job job-id) ERR-NOT-FOUND)
    (asserts! (check-uint ms-id u0) ERR-INVALID-MILESTONE)
    (let 
      ((milestone (unwrap! (map-get? milestones {job-id: job-id, ms-id: ms-id}) ERR-NOT-FOUND))
       (back (unwrap! (map-get? backers {job-id: job-id, backer: tx-sender}) ERR-UNAUTHORIZED))
       (milestone-key {job-id: job-id, ms-id: ms-id})
       (backer-key {job-id: job-id, backer: tx-sender}))
      (asserts! (not (get voted back)) ERR-ALREADY-VOTED)
      (map-set backers backer-key 
        (merge back {voted: true}))
      (map-set milestones milestone-key 
        (merge milestone {approved: approve}))
      (ok true))))

(define-public (release-milestone (job-id uint) (ms-id uint))
  (begin
    (asserts! (check-valid-job job-id) ERR-NOT-FOUND)
    (asserts! (check-uint ms-id u0) ERR-INVALID-MILESTONE)
    (let 
      ((job (unwrap! (map-get? jobs job-id) ERR-NOT-FOUND))
       (milestone (unwrap! (map-get? milestones {job-id: job-id, ms-id: ms-id}) ERR-NOT-FOUND))
       (milestone-key {job-id: job-id, ms-id: ms-id}))
      (asserts! (get approved milestone) ERR-NOT-APPROVED)
      (asserts! (not (get released milestone)) ERR-ALREADY-RELEASED)
      (try! 
        (stx-transfer? 
          (get amount milestone)
          (as-contract tx-sender) 
          (unwrap! (get freelancer job) ERR-UNAUTHORIZED)))
      (map-set milestones milestone-key 
        (merge milestone {released: true}))
      (ok true))))

;; DAO FUNCTIONS
(define-public (create-proposal (description (string-ascii 200)))
  (begin
    (asserts! (> (len description) u0) ERR-INVALID-MILESTONE)
    (let ((id (+ (var-get proposal-counter) u1)))
      (var-set proposal-counter id)
      (map-set proposals id
        {
          proposer: tx-sender,
          description: description,
          votes-for: u0,
          votes-against: u0,
          executed: false
        })
      (ok id))))

(define-public (vote-proposal (proposal-id uint) (support bool))
  (begin
    (asserts! (check-valid-job proposal-id) ERR-NOT-FOUND)
    (let 
      ((proposal (unwrap! (map-get? proposals proposal-id) ERR-NOT-FOUND)))
      (asserts! (not (get executed proposal)) ERR-ALREADY-EXECUTED)
      (if support
        (map-set proposals proposal-id
          (merge proposal {votes-for: (+ (get votes-for proposal) u1)}))
        (map-set proposals proposal-id
          (merge proposal {votes-against: (+ (get votes-against proposal) u1)})))
      (ok true))))

(define-public (execute-proposal (proposal-id uint))
  (begin
    (asserts! (check-valid-job proposal-id) ERR-NOT-FOUND)
    (let 
      ((proposal (unwrap! (map-get? proposals proposal-id) ERR-NOT-FOUND)))
      (asserts! (not (get executed proposal)) ERR-ALREADY-EXECUTED)
      (asserts! (> (get votes-for proposal) (get votes-against proposal)) ERR-NOT-APPROVED)
      (map-set proposals proposal-id
        (merge proposal {executed: true}))
      (ok true))))

;; REPUTATION
(define-private (check-score (value int))
  (not (is-eq value 0)))

(define-public (update-reputation (user principal) (delta int))
  (begin
    (asserts! (check-score delta) ERR-INVALID-MILESTONE)
    (let 
      ((current-rep (default-to {score: 0} (map-get? reputation user)))
       (new-score (+ (get score current-rep) delta)))
      (asserts! (check-score new-score) ERR-INVALID-MILESTONE)
      (map-set reputation user {score: new-score})
      (ok true))))

# Proof Server Errors

## Source

The proof server is a standalone HTTP service that generates zero-knowledge proofs for transactions. It is part of the `midnight-ledger` repository, implemented in the `proof-server` crate. It typically runs on port 6300.

The proof server is the only crate in `midnight-ledger` that uses `thiserror` derives for error handling. Errors are mapped to HTTP status codes and returned as HTTP responses.

## Worker Pool Errors (WorkerPoolError)

These errors arise from the proof server's internal job queue and worker pool management.

| HTTP Status | Error | Description | Fixes |
|-------------|-------|-------------|-------|
| 429 Too Many Requests | `JobQueueFull` | The proof generation job queue is full | Wait and retry; the server is under heavy load |
| 428 Precondition Required | `JobMissing(Uuid)` | Referenced job not found | The job ID is invalid or the job has expired |
| 400 Bad Request | `JobNotPending(Uuid)` | Tried to cancel a non-pending job | Job is already processing, completed, or cancelled |
| 500 Internal Server Error | `ChannelClosed` | Internal work channel closed | Restart the proof server |

## Work Errors (WorkError)

These errors occur during the actual proof generation process.

| HTTP Status | Error | Description | Fixes |
|-------------|-------|-------------|-------|
| 400 Bad Request | `BadInput(String)` | Proof request input data is invalid | Check the transaction data being sent for proving |
| 500 Internal Server Error | `InternalError(String)` | Internal proof generation error | Check proof server logs; may need restart |
| 500 Internal Server Error | `CancelledUnexpectedly` | Job was cancelled without explicit request | Internal error; retry the proof request |
| 500 Internal Server Error | `JoinError` | Task join error during proof generation | Internal threading error; retry or restart |

## Job Status Enum

The proof server tracks jobs through these states:

| Status | Description |
|--------|-------------|
| `Pending` | Job queued, waiting for a worker |
| `Processing` | Proof generation in progress |
| `Cancelled` | Job was cancelled |
| `Error(WorkError)` | Job failed with an error |
| `Success(Vec<u8>)` | Proof generated successfully |

## Health Endpoint

| Endpoint | HTTP Status | Meaning |
|----------|-------------|---------|
| `GET /ready` | 200 OK | Server is ready to accept proof requests |
| `GET /ready` | 503 Service Unavailable | Server is busy (all workers occupied) |

## Common Issues

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| 429 responses | Too many concurrent proof requests | Reduce parallelism; add retry with backoff |
| 503 from `/ready` | All proof workers busy | Wait for current proofs to complete; increase worker count in config |
| 500 with "BadInput" | Malformed transaction data | Verify the transaction was built correctly with the SDK |
| Connection refused on port 6300 | Proof server not running | Start the proof server container; check Docker status |
| Slow proof generation | Large circuit / insufficient resources | Allocate more CPU/memory to the proof server container |

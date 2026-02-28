## gRPC Checklist (Conditional — when interfaces include grpc) — 12 points

### Proto Design (17-22)
17. Package naming follows reverse domain with version suffix
18. Service, message, enum naming follows proto3 conventions
19. Every enum has UNSPECIFIED=0 first value
20. Breaking changes in new package version only
21. google.protobuf types used (Timestamp, FieldMask, Duration)
22. Field documentation comments on all message fields

### Implementation (23-28)
23. Deadline propagation on all client calls
24. Error model uses google.rpc.Status with details
25. Server reflection enabled in dev/staging
26. Health check protocol (grpc.health.v1) implemented
27. gRPC interceptors for auth, logging, tracing
28. Graceful shutdown drains in-flight RPCs

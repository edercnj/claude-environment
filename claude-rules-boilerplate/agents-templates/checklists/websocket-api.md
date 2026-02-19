## WebSocket Checklist (Conditional — when interfaces include websocket) — 8 points

39. Connection authentication (token in first message or handshake)
40. Heartbeat/ping-pong configured
41. Reconnection strategy with exponential backoff
42. Message envelope with type/payload/correlationId/timestamp
43. Message size limits enforced
44. Connection draining on deploy (graceful close + reconnect)
45. Room/channel subscription management
46. Binary vs text frame usage documented

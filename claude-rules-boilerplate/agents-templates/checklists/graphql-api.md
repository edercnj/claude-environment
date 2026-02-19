## GraphQL Checklist (Conditional — when interfaces include graphql) — 10 points

### Schema (29-33)
29. Cursor-based pagination (Relay Connection spec)
30. Query depth limiting configured
31. Complexity analysis configured
32. Input types for mutations (single input argument)
33. Introspection disabled in production

### Resolvers (34-38)
34. DataLoader for N+1 prevention
35. Field-level authorization for sensitive data
36. Error handling follows GraphQL spec (errors array with extensions)
37. Resolver traces per execution
38. No sensitive data in error messages

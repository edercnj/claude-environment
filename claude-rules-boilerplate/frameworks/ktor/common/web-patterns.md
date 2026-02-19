# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Ktor — Web Patterns (Routing, ContentNegotiation, StatusPages)

## Routing DSL

```kotlin
fun Application.configureRouting() {
    routing {
        route("/api/v1") {
            merchantRoutes()
            terminalRoutes()
        }
        healthRoutes()
    }
}

fun Route.merchantRoutes() {
    val service by inject<MerchantService>()

    route("/merchants") {
        get {
            val page = call.request.queryParameters["page"]?.toIntOrNull() ?: 0
            val limit = call.request.queryParameters["limit"]?.toIntOrNull() ?: 20
            call.respond(service.list(page, limit))
        }

        post {
            val request = call.receive<CreateMerchantRequest>()
            val merchant = service.create(request)
            call.respond(HttpStatusCode.Created, merchant)
        }

        get("/{id}") {
            val id = call.parameters["id"]?.toLongOrNull()
                ?: throw BadRequestException("Invalid merchant ID")
            val merchant = service.findById(id)
                ?: throw NotFoundException("Merchant not found: $id")
            call.respond(merchant)
        }

        delete("/{id}") {
            val id = call.parameters["id"]?.toLongOrNull()
                ?: throw BadRequestException("Invalid merchant ID")
            service.deactivate(id)
            call.respond(HttpStatusCode.NoContent)
        }
    }
}
```

## Content Negotiation

```kotlin
fun Application.configureSerialization() {
    install(ContentNegotiation) {
        json(Json {
            prettyPrint = false
            isLenient = false
            ignoreUnknownKeys = true
            encodeDefaults = true
            serializersModule = SerializersModule {
                contextual(OffsetDateTime::class, OffsetDateTimeSerializer)
            }
        })
    }
}
```

## StatusPages (Exception Handling)

```kotlin
fun Application.configureStatusPages() {
    install(StatusPages) {
        exception<NotFoundException> { call, cause ->
            call.respond(HttpStatusCode.NotFound, ProblemDetail(
                type = "/errors/not-found", title = "Not Found",
                status = 404, detail = cause.message ?: "Resource not found",
            ))
        }

        exception<ConflictException> { call, cause ->
            call.respond(HttpStatusCode.Conflict, ProblemDetail(
                type = "/errors/conflict", title = "Conflict",
                status = 409, detail = cause.message ?: "Resource already exists",
            ))
        }

        exception<BadRequestException> { call, cause ->
            call.respond(HttpStatusCode.BadRequest, ProblemDetail(
                type = "/errors/bad-request", title = "Bad Request",
                status = 400, detail = cause.message ?: "Invalid request",
            ))
        }

        exception<Throwable> { call, cause ->
            application.log.error("Unhandled exception", cause)
            call.respond(HttpStatusCode.InternalServerError, ProblemDetail(
                type = "/errors/internal-error", title = "Internal Server Error",
                status = 500, detail = "An unexpected error occurred",
            ))
        }
    }
}
```

## Request/Response Models

```kotlin
@Serializable
data class CreateMerchantRequest(
    val mid: String,
    val name: String,
    val document: String,
    val mcc: String,
)

@Serializable
data class MerchantResponse(
    val id: Long,
    val mid: String,
    val name: String,
    val documentMasked: String,
    val mcc: String,
    val status: String,
    val createdAt: String,
)

@Serializable
data class ProblemDetail(
    val type: String,
    val title: String,
    val status: Int,
    val detail: String,
    val instance: String? = null,
)
```

## Authentication Plugin

```kotlin
fun Application.configureAuth() {
    install(Authentication) {
        bearer("api-key") {
            authenticate { tokenCredential ->
                if (tokenCredential.token == environment.config.property("auth.apiKey").getString()) {
                    UserIdPrincipal("api-client")
                } else null
            }
        }
    }
}
```

## Anti-Patterns

- Do NOT put business logic in route handlers -- delegate to services
- Do NOT use raw `call.respondText()` for JSON APIs -- use `call.respond()` with serialization
- Do NOT forget to install `StatusPages` -- unhandled exceptions return 500 with stack trace
- Do NOT return database entities directly -- map to response DTOs

# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Ktor — Configuration Patterns
> Extends: `core/10-infrastructure-principles.md`

## application.conf (HOCON)

```hocon
ktor {
    deployment {
        port = 8080
        port = ${?PORT}
    }
    application {
        modules = [com.example.ApplicationKt.module]
    }
}

database {
    url = "jdbc:postgresql://localhost:5432/simulator"
    url = ${?DATABASE_URL}
    driver = "org.postgresql.Driver"
    user = "simulator"
    user = ${?DB_USER}
    password = "simulator"
    password = ${?DB_PASSWORD}
    maxPoolSize = 10
}

auth {
    apiKey = "dev-key-1234567890123456"
    apiKey = ${?API_KEY}
}

features {
    otelEnabled = false
    otelEnabled = ${?OTEL_ENABLED}
    otelEndpoint = "http://otel-collector:4317"
    otelEndpoint = ${?OTEL_ENDPOINT}
}
```

## Typed Config Classes

```kotlin
data class AppConfig(
    val database: DatabaseConfig,
    val auth: AuthConfig,
    val features: FeaturesConfig,
)

data class DatabaseConfig(
    val url: String,
    val driver: String,
    val user: String,
    val password: String,
    val maxPoolSize: Int = 10,
)

data class AuthConfig(
    val apiKey: String,
)

data class FeaturesConfig(
    val otelEnabled: Boolean = false,
    val otelEndpoint: String = "http://otel-collector:4317",
)
```

## Loading Config in Application

```kotlin
fun loadConfig(): AppConfig {
    val config = HoconApplicationConfig(ConfigFactory.load())

    return AppConfig(
        database = DatabaseConfig(
            url = config.property("database.url").getString(),
            driver = config.property("database.driver").getString(),
            user = config.property("database.user").getString(),
            password = config.property("database.password").getString(),
            maxPoolSize = config.propertyOrNull("database.maxPoolSize")?.getString()?.toInt() ?: 10,
        ),
        auth = AuthConfig(
            apiKey = config.property("auth.apiKey").getString(),
        ),
        features = FeaturesConfig(
            otelEnabled = config.propertyOrNull("features.otelEnabled")?.getString()?.toBoolean() ?: false,
            otelEndpoint = config.propertyOrNull("features.otelEndpoint")?.getString() ?: "http://otel-collector:4317",
        ),
    )
}
```

## Environment Variable Override

HOCON supports `${?ENV_VAR}` syntax for optional environment variable substitution. The `?` makes it optional -- if the env var is not set, the default value is used.

| HOCON Key              | Env Variable    | Default                         |
| ---------------------- | --------------- | ------------------------------- |
| ktor.deployment.port   | PORT            | 8080                            |
| database.url           | DATABASE_URL    | jdbc:postgresql://localhost/sim  |
| database.user          | DB_USER         | simulator                       |
| database.password      | DB_PASSWORD     | simulator                       |
| auth.apiKey            | API_KEY         | dev-key-...                     |
| features.otelEnabled   | OTEL_ENABLED    | false                           |

## Profile-Based Config

```hocon
# application-test.conf
include "application.conf"

database {
    url = "jdbc:h2:mem:testdb;MODE=PostgreSQL"
    driver = "org.h2.Driver"
    user = "sa"
    password = ""
}
```

## Anti-Patterns

- Do NOT hardcode configuration values in Kotlin code -- use HOCON files
- Do NOT skip the `${?VAR}` optional syntax for env var overrides
- Do NOT access `ApplicationConfig` deep in service layers -- inject typed config objects
- Do NOT commit config files with real production secrets

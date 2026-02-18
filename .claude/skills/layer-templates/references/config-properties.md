# Template: Configuration (application.properties)

## Pattern

```properties
# === {Feature Name} ===
# Story: STORY-NNN

# Feature-specific configuration
simulator.feature.property-one=default-value
simulator.feature.property-two=42
simulator.feature.enabled=true

# Externalized via env vars for K8S
simulator.feature.sensitive-value=${FEATURE_SECRET:local-default}
```

## Pattern — @ConfigMapping Interface

```java
package com.bifrost.simulator.config;

import io.smallrye.config.ConfigMapping;
import io.smallrye.config.WithDefault;

@ConfigMapping(prefix = "simulator.feature")
public interface FeatureConfig {

    @WithDefault("default-value")
    String propertyOne();

    @WithDefault("42")
    int propertyTwo();

    @WithDefault("true")
    boolean enabled();
}
```

## CHANGE THESE

- **Property prefix**: `simulator.{feature}.*`
- **Properties**: Match the Architect's plan configuration section
- **@WithDefault**: Sensible defaults for local development
- **Env vars**: `${ENV_VAR:default}` for sensitive/environment-specific values

## Critical Rules (memorize)

1. Use `@ConfigMapping` for 3+ properties with common prefix
2. Use `@ConfigProperty` only for 1-2 isolated properties
3. Credentials ALWAYS via `${ENV_VAR:default}` — never hardcoded
4. `@WithDefault` for every property (application starts without external config)
5. Profile-specific overrides in `application-{profile}.properties`

## Checklist

- [ ] Properties prefixed with `simulator.*`
- [ ] `@WithDefault` on all config interface methods
- [ ] Sensitive values use `${ENV_VAR:default}` pattern
- [ ] Comment header with Story reference
- [ ] No duplicate of existing properties

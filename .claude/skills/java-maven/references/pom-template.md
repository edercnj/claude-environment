# POM Template — b8583

Use this as the base `pom.xml` when setting up the project (STORY-000).

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
                             https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.bifrost</groupId>
    <artifactId>b8583</artifactId>
    <version>0.1.0-SNAPSHOT</version>
    <packaging>jar</packaging>

    <name>b8583</name>
    <description>ISO 8583 message parsing and packing library for the Bifrost project</description>

    <properties>
        <!-- Java -->
        <java.version>21</java.version>
        <maven.compiler.release>${java.version}</maven.compiler.release>

        <!-- Encoding -->
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>

        <!-- Dependencies versions (test only) -->
        <junit-jupiter.version>5.11.3</junit-jupiter.version>
        <assertj.version>3.26.3</assertj.version>

        <!-- Plugin versions -->
        <maven-compiler-plugin.version>3.13.0</maven-compiler-plugin.version>
        <maven-surefire-plugin.version>3.5.2</maven-surefire-plugin.version>
        <maven-jar-plugin.version>3.4.2</maven-jar-plugin.version>
        <maven-javadoc-plugin.version>3.10.1</maven-javadoc-plugin.version>
        <jacoco-maven-plugin.version>0.8.12</jacoco-maven-plugin.version>

        <!-- Coverage thresholds -->
        <jacoco.line.coverage>0.95</jacoco.line.coverage>
        <jacoco.branch.coverage>0.90</jacoco.branch.coverage>
    </properties>

    <dependencies>
        <!-- Test dependencies ONLY — zero runtime deps -->
        <dependency>
            <groupId>org.junit.jupiter</groupId>
            <artifactId>junit-jupiter</artifactId>
            <version>${junit-jupiter.version}</version>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.assertj</groupId>
            <artifactId>assertj-core</artifactId>
            <version>${assertj.version}</version>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <!-- Compiler: Java 21 with parameter names retained -->
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>${maven-compiler-plugin.version}</version>
                <configuration>
                    <release>${java.version}</release>
                    <parameters>true</parameters>
                    <compilerArgs>
                        <arg>-Xlint:all</arg>
                    </compilerArgs>
                </configuration>
            </plugin>

            <!-- Surefire: JUnit 5 test execution -->
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-surefire-plugin</artifactId>
                <version>${maven-surefire-plugin.version}</version>
                <configuration>
                    <argLine>${argLine}</argLine>
                </configuration>
            </plugin>

            <!-- JaCoCo: Coverage measurement and enforcement -->
            <plugin>
                <groupId>org.jacoco</groupId>
                <artifactId>jacoco-maven-plugin</artifactId>
                <version>${jacoco-maven-plugin.version}</version>
                <executions>
                    <!-- Prepare agent for coverage collection -->
                    <execution>
                        <id>prepare-agent</id>
                        <goals>
                            <goal>prepare-agent</goal>
                        </goals>
                    </execution>
                    <!-- Generate report after tests -->
                    <execution>
                        <id>report</id>
                        <phase>test</phase>
                        <goals>
                            <goal>report</goal>
                        </goals>
                    </execution>
                    <!-- Enforce coverage thresholds -->
                    <execution>
                        <id>check</id>
                        <phase>verify</phase>
                        <goals>
                            <goal>check</goal>
                        </goals>
                        <configuration>
                            <rules>
                                <rule>
                                    <element>BUNDLE</element>
                                    <limits>
                                        <limit>
                                            <counter>LINE</counter>
                                            <value>COVEREDRATIO</value>
                                            <minimum>${jacoco.line.coverage}</minimum>
                                        </limit>
                                        <limit>
                                            <counter>BRANCH</counter>
                                            <value>COVEREDRATIO</value>
                                            <minimum>${jacoco.branch.coverage}</minimum>
                                        </limit>
                                    </limits>
                                </rule>
                            </rules>
                        </configuration>
                    </execution>
                </executions>
            </plugin>

            <!-- JAR packaging -->
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-jar-plugin</artifactId>
                <version>${maven-jar-plugin.version}</version>
                <configuration>
                    <archive>
                        <manifest>
                            <addDefaultImplementationEntries>true</addDefaultImplementationEntries>
                        </manifest>
                    </archive>
                </configuration>
            </plugin>

            <!-- Javadoc -->
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-javadoc-plugin</artifactId>
                <version>${maven-javadoc-plugin.version}</version>
                <configuration>
                    <failOnError>true</failOnError>
                    <doclint>all,-missing</doclint>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
```

## Notes

- The `<argLine>${argLine}</argLine>` in surefire is required for JaCoCo agent injection.
- `<parameters>true</parameters>` retains method parameter names at runtime — useful for annotation processing and better error messages.
- `-Xlint:all` enables all compiler warnings.
- JaCoCo `check` runs during the `verify` phase — use `mvn clean verify` to enforce thresholds.
- During early development (STORY-000 only), you may temporarily lower thresholds. Reset to 95/90 before STORY-001.

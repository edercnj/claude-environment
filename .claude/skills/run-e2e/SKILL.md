---
name: run-e2e
description: "Run end-to-end tests: TCP → Parse → Process → DB → Response. Validates complete transaction flow with real database."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[scenario: purchase|reversal|echo|timeout|persistent]"
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Skill: End-to-End Tests (E2E)

## When to Use

When implementing tests that validate the full application flow:
TCP → Parse → Process → Database → Response

## Stack

- **@QuarkusIntegrationTest** — test with compiled application (JVM or native)
- **Testcontainers** — real PostgreSQL
- **TcpTestClient** — custom TCP client with framing
- **AssertJ** — assertions (NEVER JUnit assertEquals)
- **Awaitility** — for asynchronous and timeout scenarios

## Full E2E Flow

```
TcpTestClient → [2-byte header + ISO body] → Vert.x NetServer
    → RecordParser (message framing)
    → ISO 8583 Unpacker (b8583 lib)
    → Domain: TransactionRequest record
    → Application: ProcessTransactionUseCase
    → Domain: CentsDecisionEngine
    → Adapter: TransactionRepository.persist()
    → Domain: TransactionResponse record
    → ISO 8583 Packer (b8583 lib)
    → [2-byte header + ISO response] → TcpTestClient
```

## TcpTestClient (Essential Fixture)

```java
/**
 * TCP client that simulates a terminal/acquirer with persistent connection.
 * Supports message framing (2-byte length prefix).
 */
public class TcpTestClient implements AutoCloseable {
    private final Socket socket;
    private final DataInputStream in;
    private final DataOutputStream out;

    public TcpTestClient(String host, int port) throws IOException {
        this.socket = new Socket(host, port);
        this.socket.setKeepAlive(true);
        this.socket.setSoTimeout(60_000); // 60s read timeout
        this.in = new DataInputStream(socket.getInputStream());
        this.out = new DataOutputStream(socket.getOutputStream());
    }

    /**
     * Sends an ISO message and waits for a response.
     * Framing: [2-byte length BE][ISO message body]
     */
    public byte[] sendAndReceive(byte[] isoMessage) throws IOException {
        // Write
        out.writeShort(isoMessage.length);
        out.write(isoMessage);
        out.flush();

        // Read
        int len = in.readUnsignedShort();
        byte[] response = new byte[len];
        in.readFully(response);
        return response;
    }

    /** Checks if the connection is still active */
    public boolean isConnected() {
        return socket.isConnected() && !socket.isClosed();
    }

    @Override
    public void close() throws IOException {
        socket.close();
    }
}
```

## Required E2E Scenarios

### 1. Purchase Approved (Happy Path)

```java
@QuarkusIntegrationTest
class PurchaseE2ETest {

    @Test
    void purchase_approved_persistsAndResponds() {
        // Arrange
        var client = new TcpTestClient("localhost", 8583);
        var msg = IsoMessageBuilder.purchase()
            .pan("4111111111111111")
            .amount("000000001000")  // R$10.00 — cents=00 → RC=00
            .stan("000001")
            .terminalId("TERM0001")
            .merchantId("MERCH00000001")
            .build();

        // Act
        byte[] response = client.sendAndReceive(msg);

        // Assert
        var resp = IsoMessageParser.parse(response);
        assertThat(resp.mti()).isEqualTo("0210");
        assertThat(resp.field(39)).isEqualTo("00");  // Approved
        assertThat(resp.field(38)).isNotBlank();       // Auth code

        // Verify DB
        // (via REST API or direct query)
        assertThat(findTransaction(resp.field(37)))
            .isNotNull()
            .extracting("status").isEqualTo("APPROVED");

        client.close();
    }
}
```

### 2. Purchase Declined

```java
@Test
void purchase_declined_insufficientFunds() {
    var msg = IsoMessageBuilder.purchase()
        .amount("000000001051")  // cents=51 → RC=51
        .build();

    byte[] response = client.sendAndReceive(msg);
    var resp = IsoMessageParser.parse(response);

    assertThat(resp.field(39)).isEqualTo("51");
}
```

### 3. Reversal Flow

```java
@Test
void reversal_afterApproval_reversesTransaction() {
    // Step 1: Approve purchase
    var purchase = sendPurchase("000000001000");
    assertThat(purchase.field(39)).isEqualTo("00");

    // Step 2: Send reversal
    var reversal = IsoMessageBuilder.reversal()
        .originalData(purchase)  // DE-56/DE-90
        .build();
    byte[] revResponse = client.sendAndReceive(reversal);
    var revResp = IsoMessageParser.parse(revResponse);

    assertThat(revResp.mti()).isEqualTo("0410");
    assertThat(revResp.field(39)).isEqualTo("00");

    // Verify DB: original reversed
    assertThat(findTransaction(purchase.field(37)))
        .extracting("status").isEqualTo("REVERSED");
}
```

### 4. Persistent Connection (Multi-message)

```java
@Test
void persistentConnection_multipleMessages_sameConnection() {
    var client = new TcpTestClient("localhost", 8583);

    for (int i = 0; i < 10; i++) {
        var msg = IsoMessageBuilder.purchase()
            .amount(String.format("0000000010%02d", i))
            .stan(String.format("%06d", i + 1))
            .build();

        byte[] response = client.sendAndReceive(msg);
        assertThat(IsoMessageParser.parse(response).mti()).isEqualTo("0210");
    }

    assertThat(client.isConnected()).isTrue();
    client.close();
}
```

### 5. Timeout Scenario

```java
@Test
void timeout_delaysResponse_keepsConnection() {
    var msg = IsoMessageBuilder.purchase()
        .terminalId("TIMEOUT_TID") // Flag for RULE-002
        .amount("000000001000")
        .build();

    long start = System.currentTimeMillis();
    byte[] response = client.sendAndReceive(msg);
    long elapsed = System.currentTimeMillis() - start;

    assertThat(elapsed).isGreaterThanOrEqualTo(35_000L);
    assertThat(client.isConnected()).isTrue();
}
```

### 6. Multi-Version ISO

```java
@ParameterizedTest
@EnumSource(IsoVersion.class)  // ISO_1987, ISO_1993, ISO_2021
void purchase_allIsoVersions_approved(IsoVersion version) {
    var msg = IsoMessageBuilder.purchase()
        .version(version)
        .amount("000000001000")
        .build();

    byte[] response = client.sendAndReceive(msg);
    var resp = IsoMessageParser.parse(response, version);

    assertThat(resp.responseCode()).isEqualTo("00");
}
```

### 7. Malformed Message

```java
@Test
void malformedMessage_returnsError_keepsConnection() {
    byte[] garbage = "NOT_AN_ISO_MESSAGE".getBytes();

    // Send with correct framing but invalid content
    byte[] response = client.sendAndReceive(garbage);
    var resp = IsoMessageParser.parse(response);

    assertThat(resp.field(39)).isEqualTo("96"); // System error
    assertThat(client.isConnected()).isTrue();   // Connection preserved
}
```

### 8. Reversal Advice (0420)

```java
@Test
void reversalAdvice_unconfirmedReversal_responds() {
    // 0420 is used when the reversal (0400) did not receive a response
    // The acquirer resends as advice to ensure processing
    var purchase = sendPurchase("000000001000");
    assertThat(purchase.field(39)).isEqualTo("00");

    var advice = IsoMessageBuilder.reversalAdvice()
        .originalData(purchase)  // DE-56/DE-90
        .build();
    byte[] advResponse = client.sendAndReceive(advice);
    var advResp = IsoMessageParser.parse(advResponse);

    assertThat(advResp.mti()).isEqualTo("0430");
    assertThat(advResp.field(39)).isEqualTo("00");
}
```

### 9. Mixed Transaction Types on Same Connection

```java
@Test
void mixedTypes_sameConnection_allProcessed() {
    var client = new TcpTestClient("localhost", 8583);

    // Echo test
    var echo = IsoMessageBuilder.echo().build();
    var echoResp = IsoMessageParser.parse(client.sendAndReceive(echo));
    assertThat(echoResp.mti()).isEqualTo("0810");

    // Purchase
    var purchase = IsoMessageBuilder.purchase()
        .amount("000000001000").stan("000001").build();
    var purchResp = IsoMessageParser.parse(client.sendAndReceive(purchase));
    assertThat(purchResp.mti()).isEqualTo("0210");
    assertThat(purchResp.field(39)).isEqualTo("00");

    // Authorization
    var auth = IsoMessageBuilder.authorization()
        .amount("000000002000").stan("000002").build();
    var authResp = IsoMessageParser.parse(client.sendAndReceive(auth));
    assertThat(authResp.mti()).isEqualTo("0110");

    // Reversal of the purchase
    var reversal = IsoMessageBuilder.reversal()
        .originalData(purchResp).build();
    var revResp = IsoMessageParser.parse(client.sendAndReceive(reversal));
    assertThat(revResp.mti()).isEqualTo("0410");

    assertThat(client.isConnected()).isTrue();
    client.close();
}
```

### 10. Idle Connection Survives

```java
@Test
void idleConnection_survivesPause_continuesProcessing() throws Exception {
    var client = new TcpTestClient("localhost", 8583);

    // First message
    var msg1 = IsoMessageBuilder.purchase().amount("000000001000").build();
    client.sendAndReceive(msg1);

    // Idle 10 seconds (below idle timeout of 300s)
    Thread.sleep(10_000);

    // Second message on same connection
    var msg2 = IsoMessageBuilder.purchase().amount("000000002000").build();
    byte[] resp2 = client.sendAndReceive(msg2);
    assertThat(IsoMessageParser.parse(resp2).mti()).isEqualTo("0210");

    assertThat(client.isConnected()).isTrue();
    client.close();
}
```

### 11. Connection Reset by Client

```java
@Test
void connectionReset_serverHandlesGracefully() throws Exception {
    var client1 = new TcpTestClient("localhost", 8583);
    client1.sendAndReceive(IsoMessageBuilder.echo().build());
    client1.close(); // Abrupt close

    // New connection works fine
    var client2 = new TcpTestClient("localhost", 8583);
    byte[] resp = client2.sendAndReceive(IsoMessageBuilder.echo().build());
    assertThat(IsoMessageParser.parse(resp).mti()).isEqualTo("0810");
    client2.close();
}
```

### 12. Multiple Concurrent Connections

```java
@Test
void concurrentConnections_allProcessedIndependently() throws Exception {
    int numConnections = 5;
    var clients = new ArrayList<TcpTestClient>();
    var futures = new ArrayList<CompletableFuture<String>>();

    for (int i = 0; i < numConnections; i++) {
        var client = new TcpTestClient("localhost", 8583);
        clients.add(client);
        int idx = i;
        futures.add(CompletableFuture.supplyAsync(() -> {
            var msg = IsoMessageBuilder.purchase()
                .amount(String.format("0000000010%02d", idx))
                .stan(String.format("%06d", idx + 1))
                .build();
            byte[] resp = client.sendAndReceive(msg);
            return IsoMessageParser.parse(resp).field(39);
        }));
    }

    // All should complete successfully
    var results = futures.stream()
        .map(CompletableFuture::join)
        .toList();
    assertThat(results).hasSize(numConnections);

    clients.forEach(TcpTestClient::close);
}
```

## IsoMessageBuilder (Fixture)

```java
public class IsoMessageBuilder {
    private String mti = "0200";
    private final Map<Integer, String> fields = new TreeMap<>();
    private IsoVersion version = IsoVersion.ISO_1993;

    public static IsoMessageBuilder purchase() {
        return new IsoMessageBuilder()
            .mti("0200")
            .field(3, "000000")    // Purchase processing code
            .field(49, "986");      // BRL currency
    }

    public static IsoMessageBuilder authorization() {
        return new IsoMessageBuilder().mti("0100").field(3, "000000");
    }

    public static IsoMessageBuilder reversal() {
        return new IsoMessageBuilder().mti("0400").field(3, "000000");
    }

    public static IsoMessageBuilder reversalAdvice() {
        return new IsoMessageBuilder().mti("0420").field(3, "000000");
    }

    public static IsoMessageBuilder echo() {
        return new IsoMessageBuilder().mti("0800").field(70, "301");
    }

    // ... builders for each field
    public byte[] build() { /* use b8583 lib to pack */ }
}
```

## E2E Checklist (15 points)

- [ ] TcpTestClient with correct framing (2-byte header)?
- [ ] Testcontainers PostgreSQL active?
- [ ] All transaction types tested? (purchase, auth, reversal, reversal advice, echo)
- [ ] Persistent connection validated (multiple sequential messages)?
- [ ] Timeout tested (35s delay, connection kept)?
- [ ] Multi-version ISO tested? (1987, 1993, 2021)
- [ ] Malformed message does not kill connection?
- [ ] DB verified after each transaction?
- [ ] 0420 Reversal Advice tested?
- [ ] Mixed types on same connection? (echo + purchase + auth + reversal)
- [ ] Idle connection survives pause and continues?
- [ ] Connection reset handled gracefully by server?
- [ ] Multiple concurrent connections processed independently?
- [ ] Error scenarios for each MTI covered?
- [ ] Cents rule validated for all response codes (00, 05, 14, 43, 51, 57, 96)?

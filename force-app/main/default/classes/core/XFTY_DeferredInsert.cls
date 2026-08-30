/**
 * The registry behind the `DEFERRED` insert mode.
 *
 * A Provider call with `.setInsertMode(XFTY_InsertModeEnum.DEFERRED)` generates
 * its graph structurally - exactly like `NEVER`, no Ids - and registers every
 * record here instead of inserting. Call `XFTY_DeferredInsert.flush()` once the
 * test has generated everything it needs: it inserts the whole accumulated set in
 * one `insert` per dependency depth, and because the records handed back were the
 * same instances, their `Id` fields are now populated.
 *
 * <pre>
 * XFTY_DummySObjectBundle a = new XFTY_DummySObjectProvider(Account.SObjectType, lookup)
 *         .setInsertMode(XFTY_InsertModeEnum.DEFERRED).supplyBundle();
 * XFTY_DummySObjectBundle c = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
 *         .setInsertMode(XFTY_InsertModeEnum.DEFERRED).supplyBundle();
 *
 * XFTY_DeferredInsert.flush();   // both graphs inserted; Ids now on a's and c's records
 * </pre>
 *
 * - A test that never calls `flush()` gets `NEVER` semantics - no surprise DML.
 * - Plays nicely with other modes: records inserted by a `NOW` call are not in
 *   the registry, already have Ids, and a `DEFERRED` record pointing at one keeps
 *   that Id. `flush()` only touches what was registered.
 * - `flush()` clears the registry, so generation after a `flush()` starts a fresh
 *   pending set.
 * - Static, so it resets between test methods. Not supported with `@TestSetup`
 *   (which resets statics) or with shared ancestors (refused during generation).
 */
@IsTest
public class XFTY_DeferredInsert {

    private static XFTY_DeferredInsertBuffer buffer = new XFTY_DeferredInsertBuffer();

    /**
     * Add a structurally-generated bundle to the pending set. Called by
     * `XFTY_DummySObjectProvider` for a `DEFERRED` generation; can also be called
     * directly to hand a `NEVER`-generated bundle to the deferred flush. Register
     * each bundle at most once.
     */
    public static void register(XFTY_DummySObjectBundle bundle) {
        buffer.add(bundle);
    }

    /** How many records are waiting for the next `flush()`. */
    public static Integer pendingCount() {
        return buffer.pendingCount();
    }

    /**
     * Insert every registered record, batched by dependency depth, back-filling
     * Ids on the instances already handed out, then clear the pending set. A
     * no-op (0 DML) when nothing is registered.
     */
    public static void flush() {
        buffer.insertAll();
        buffer = new XFTY_DeferredInsertBuffer();
    }
}

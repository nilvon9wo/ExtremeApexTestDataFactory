/**
 * The registry behind the `DEFERRED` insert mode.
 *
 * A `DEFERRED` Provider call generates its graph like `NEVER` and registers it
 * here instead of inserting. `flush()` then saves everything registered so far -
 * across every `supplyBundle()` call - in one depth-batched pass, and the Ids
 * appear on the instances the calls already returned.
 *
 * Static, so it clears between test methods; not usable from `@TestSetup` (which
 * also clears statics). Shared ancestors work (each resolves in its own pre-phase
 * with a real / mock Id, so the flush treats it as an anchor). Up-flowing values
 * ({@link XFTY_CopyFromDescendantExpression}) are filled here, at the top of `flush()`.
 */
@IsTest
public class XFTY_DeferredInserter {

    private static XFTY_DeferredInsertBuffer buffer = new XFTY_DeferredInsertBuffer();

    public static void register(XFTY_DummySObjectBundle bundle) {
        buffer.add(bundle);
    }

    public static Integer pendingCount() {
        return buffer.pendingCount();
    }

    /** Save every registered record, back-fill its Id, and clear the registry. */
    public static void flush() {
        XFTY_GovernorBudget budget = new XFTY_GovernorBudget();
        buffer.insertAll();
        buffer = new XFTY_DeferredInsertBuffer();
        budget.warnIfExpensive();
    }
}

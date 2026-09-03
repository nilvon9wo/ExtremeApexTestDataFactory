/**
 * Saves the contents of a generated `XFTY_DummySObjectBundle` into the running
 * org - ancestors, primaries, downward children, every SObjectType - and reports
 * what the platform made of it.
 *
 * Built for a Salesforce **Apex Integration Test** (`@IntegrationTest`), which
 * commits real DML with no automatic rollback. A consumer generates a graph with
 * their Providers (any insert mode - the records are re-persisted here) and calls
 * `XFTY_Seeder.seed(bundle)`; the data stays in the org after the test.
 *
 * Best effort: one record failing a validation rule, a required field, a
 * duplicate rule or a permission check does not stop the rest. It does not police
 * the bundle - mock Ids or injected read-only values will simply be rejected by
 * the platform and reported in the `XFTY_SeedResult`.
 *
 * One transaction, so the platform's per-transaction DML-row and CPU limits
 * apply; a very large seed should be split across several `@IntegrationTest`
 * methods (or wait for the Bulk API path).
 */
@IsTest
public class XFTY_Seeder {

    /** Persist every record `bundle` holds and return the per-record outcome. */
    public static XFTY_SeedResult seed(XFTY_DummySObjectBundle bundle) {
        XFTY_DeferredInsertBuffer graph = XFTY_DeferredInsertBuffer.flatten(bundle);
        List<SObject> records = graph.records();
        Map<Integer, Database.SaveResult> outcomes = XFTY_DepthBatchedInserter.seedAll(records, graph.parentLinks());
        return new XFTY_SeedResult(records, outcomes);
    }
}

/**
 * Saves the contents of a generated `XFTY_DummySObjectBundle` into the running
 * org - ancestors, primaries, downward children, every SObjectType - and reports
 * what the platform made of it.
 *
 * Built for a Salesforce **Apex Integration Test** (`@IntegrationTest`), which
 * commits real DML with no automatic rollback. A consumer generates a graph with
 * their Providers in `LATER` mode (no Ids, nothing inserted) and calls
 * `XFTY_Seeder.seed(bundle)`; the data stays in the org after the test.
 *
 * Called anywhere else - a regular `@IsTest` method, anonymous Apex - the DML
 * still runs but rolls back with the transaction; `seed` warns, and
 * `XFTY_SeedResult.ranInIntegrationTest()` is `false`.
 *
 * Best effort: one record failing a validation rule, a required field, a
 * duplicate rule or a permission check does not stop the rest. It does not police
 * the bundle - mock Ids or injected read-only values are simply rejected by the
 * platform and reported in the `XFTY_SeedResult`.
 *
 * One transaction, so the platform's per-transaction DML-row and CPU limits
 * apply; a very large seed should be split across several `@IntegrationTest`
 * methods.
 */
@IsTest
public class XFTY_Seeder {

    // System.Quiddity.RUN_INTEGRATION_TESTS by name - so this compiles on an API
    // version that predates the enum value.
    private static final String INTEGRATION_TEST_QUIDDITY = 'RUN_INTEGRATION_TESTS';

    /** Persist every record `bundle` holds and return the per-record outcome. */
    public static XFTY_SeedResult seed(XFTY_DummySObjectBundle bundle) {
        Boolean inIntegrationTest = isInIntegrationTest();
        warnIfNotPersisting(inIntegrationTest);
        XFTY_DeferredInsertBuffer graph = XFTY_DeferredInsertBuffer.flatten(bundle);
        List<SObject> records = graph.records();
        Map<Integer, Database.SaveResult> outcomes = XFTY_DepthBatchedInserter.seedAll(records, graph.parentLinks());
        return new XFTY_SeedResult(records, outcomes, inIntegrationTest);
    }

    /** True when this is running inside an `@IntegrationTest` method - the only context a seed survives. */
    public static Boolean isInIntegrationTest() {
        return String.valueOf(Request.getCurrent().getQuiddity()) == INTEGRATION_TEST_QUIDDITY;
    }

    private static void warnIfNotPersisting(Boolean inIntegrationTest) {
        if (!inIntegrationTest) {
            System.debug(LoggingLevel.WARN,
                    'XFTY_Seeder.seed is not running in an @IntegrationTest - the DML will roll back with the '
                            + 'transaction. Wrap the call in an @IntegrationTest method for the data to persist.');
        }
    }
}

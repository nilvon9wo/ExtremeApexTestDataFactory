/**
 * `.depthBatched()` and the `DEFERRED` mode at volume: the bundle-walk that
 * collects records and links must stay cheap, and the depth-batched insert must
 * hold at one DML statement per dependency depth regardless of row count.
 *
 * `test-support/` only. See docs/reference/volume-and-limits.md.
 */
@IsTest
private class XFTY_DeferredLoadTest {
    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    /**
     * `.depthBatched()` collapses a wide `Task` graph (Account + Contact parents,
     * the Contact itself needing an Account = 3 dependency depths) to one `insert`
     * per depth - fewer than the per-Provider default, and constant as volume
     * grows.
     */
    @IsTest
    static void depthBatchedCostsOneInsertPerDepthAndBeatsThePerProviderDefault() {
        Integer batchedStatements;
        Integer defaultStatements;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            batchedStatements = statementsToBuildTaskGraph(300, true);
            defaultStatements = statementsToBuildTaskGraph(50, false);
            Test.stopTest();
        }

        Assert.areEqual(350, [SELECT COUNT() FROM Task]);
        Assert.areEqual(3, batchedStatements, 'one insert per dependency depth (Account -> Contact -> Task)');
        Assert.isTrue(
                batchedStatements < defaultStatements,
                'depth-batched (' + batchedStatements + ') beats the per-Provider default (' + defaultStatements + ')'
        );
    }

    private static Integer statementsToBuildTaskGraph(Integer quantity, Boolean depthBatched) {
        Integer before = Limits.getDmlStatements();
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Task.SObjectType, XFTY_LoadProviders.lookup())
                .putRequired(Task.WhatId, new XFTY_DummyDefaultRelationship(new Account()))
                .putRequired(Task.WhoId, new XFTY_DummyDefaultRelationship(new Contact()))
                .setQuantityPerTemplate(quantity)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW);
        if (depthBatched) {
            provider.depthBatched();
        }
        provider.supplyList();
        return Limits.getDmlStatements() - before;
    }

    /**
     * DEFERRED across 8 `supplyBundle()` calls (100 Contacts each), one
     * `flush()`: the accumulated 800 Contacts + 800 Accounts insert in a small
     * constant number of statements, and the flush stays inside a CPU budget.
     *
     * Volume note: on a standard org the `flush()` insert (with its triggers)
     * dominates - ~5 s CPU for 4 000 records, half the limit. Keep a single
     * transaction's DEFERRED / NOW volume to ~1 000-1 500 primaries with parents.
     * See docs/reference/volume-and-limits.md.
     */
    @IsTest
    static void deferredAcrossManyCallsFlushesInABoundedNumberOfStatements() {
        Integer stmtsBefore;
        Integer stmtsAfter;
        Long cpuBefore;
        Long cpuAfter;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            for (Integer call = 0; call < 8; call++) {
                new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                        .setQuantityPerTemplate(100)
                        .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                        .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                        .supplyBundle();
            }
            stmtsBefore = Limits.getDmlStatements();
            cpuBefore = Limits.getCpuTime();
            XFTY_DeferredInserter.flush();
            stmtsAfter = Limits.getDmlStatements();
            cpuAfter = Limits.getCpuTime();
            Test.stopTest();
        }

        Assert.areEqual(800, [SELECT COUNT() FROM Contact]);
        Assert.areEqual(800, [SELECT COUNT() FROM Account]);
        Assert.isTrue(stmtsAfter - stmtsBefore <= 4, 'flush is a handful of statements; used ' + (stmtsAfter - stmtsBefore));
        Assert.isTrue(
                cpuAfter - cpuBefore < Limits.getLimitCpuTime() * 0.4,
                'the flush of 1 600 records should stay under 40% of the CPU limit, used ' + (cpuAfter - cpuBefore)
        );
    }
}

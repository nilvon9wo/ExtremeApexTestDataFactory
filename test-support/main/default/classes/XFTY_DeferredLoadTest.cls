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
    private static final Decimal FLUSH_CPU_BUDGET_FRACTION = 0.4;

    @IsTest
    static void testFlush_whenDepthBatched_costsOneInsertPerDepthAndBeatsThePerProviderDefault() {
        // Arrange - a wide Task graph (Account + Contact parents, Contact needs an Account = 3 depths)

        // Act - build it depth-batched, then build a smaller one the per-Provider default way
        Integer batchedStatements;
        Integer defaultStatements;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            batchedStatements = statementsToBuildTaskGraph(300, true);
            defaultStatements = statementsToBuildTaskGraph(50, false);
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(350, [SELECT COUNT() FROM Task]);
        Assert.areEqual(3, batchedStatements, 'one insert per dependency depth (Account -> Contact -> Task)');
        Assert.isTrue(batchedStatements < defaultStatements,
                'depth-batched (' + batchedStatements + ') beats the per-Provider default (' + defaultStatements + ')');
    }

    @IsTest
    static void testFlush_forDeferredWorkAcrossManyCalls_usesABoundedNumberOfStatements() {
        // Arrange - DEFERRED across 8 supplyBundle() calls, 100 Contacts each
        System.runAs(TEST_ADMIN) {
            for (Integer call = 0; call < 8; call++) {
                new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                        .setQuantityPerTemplate(100)
                        .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                        .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                        .supplyBundle();
            }
        }

        // Act
        FlushUsage used;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            used = flushAndMeasure();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(800, [SELECT COUNT() FROM Contact]);
        Assert.areEqual(800, [SELECT COUNT() FROM Account]);
        Assert.isTrue(used.dmlStatements <= 4, 'flush is a handful of statements; used ' + used.dmlStatements);
        Assert.isTrue(used.cpuTime < Limits.getLimitCpuTime() * FLUSH_CPU_BUDGET_FRACTION,
                'the flush of 1 600 records should stay under 40% of the CPU limit, used ' + used.cpuTime);
    }

    // Fixture -------------------------------------------------------------

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

    private static FlushUsage flushAndMeasure() {
        FlushUsage used = new FlushUsage();
        XFTY_DeferredInserter.flush();
        used.recordEnd();
        return used;
    }

    private class FlushUsage {
        private final Integer dmlStatementsStart = Limits.getDmlStatements();
        private final Long cpuTimeStart = Limits.getCpuTime();
        private Integer dmlStatements;
        private Long cpuTime;

        private void recordEnd() {
            this.dmlStatements = Limits.getDmlStatements() - this.dmlStatementsStart;
            this.cpuTime = Limits.getCpuTime() - this.cpuTimeStart;
        }
    }
}

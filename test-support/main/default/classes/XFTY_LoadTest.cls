/**
 * Volume / governor-budget tests for XFTY. These deliberately generate large
 * object graphs and assert that the framework leaves plenty of headroom - CPU,
 * heap, DML statements, rows - for the code actually under test and the rest of a
 * test's setup.
 *
 * Lives in `test-support/` (not the published package): the assertions are
 * budget ceilings that depend on the org being otherwise quiet (no consumer
 * triggers / flows on the generated types), so shipping them would risk failing
 * in a consumer's org - the one thing XFTY must never do. It runs in CI on the
 * clean scratch org.
 *
 * Its own suite (`XFTY_Load`, also in test-support) because it is the slowest and
 * the most likely to need tuning as the engine changes - notably when
 * shared-ancestor generation lands (see docs/roadmap/shared-ancestors.md, which
 * calls for exactly this kind of measurement). Run with:
 *   sf apex run test --suite-names XFTY_Load
 *
 * The numbers below are ceilings, not targets - they should sit well under the
 * platform limits so a regression is caught before it bites anyone.
 */
@IsTest
private class XFTY_LoadTest {
    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    /** 200 Contacts each with a generated Account, MOCK mode: no DML, bounded CPU. */
    @IsTest
    static void mockGenerationOfAWideGraphDoesNoDmlAndStaysUnderCpuBudget() {
        List<SObject> contacts;
        Integer dmlForGeneration;
        Long cpuForGeneration;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            Integer dmlBefore = Limits.getDmlStatements();
            Long cpuBefore = Limits.getCpuTime();
            contacts = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .setQuantityPerTemplate(200)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supplyList();
            dmlForGeneration = Limits.getDmlStatements() - dmlBefore;
            cpuForGeneration = Limits.getCpuTime() - cpuBefore;
            Test.stopTest();
        }

        Assert.areEqual(200, contacts.size());
        Assert.areEqual(0, dmlForGeneration, 'MOCK generation must not touch the database');
        Assert.isTrue(
                cpuForGeneration < 8000,
                'generation CPU should stay well under the 10s synchronous limit, was ' + cpuForGeneration + 'ms'
        );
    }

    /**
     * 100 Contacts + their Accounts inserted with NOW: the engine must batch, not
     * insert per record. Two levels (Account, Contact) => a small, constant number
     * of DML statements regardless of row count.
     */
    @IsTest
    static void nowGenerationBatchesDmlByLevelNotByRecord() {
        Integer dmlBefore;
        Integer dmlAfter;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            dmlBefore = Limits.getDmlStatements();
            new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .setQuantityPerTemplate(100)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .supplyList();
            dmlAfter = Limits.getDmlStatements();
            Test.stopTest();
        }

        Assert.areEqual(100, [SELECT COUNT() FROM Contact]);
        Assert.areEqual(100, [SELECT COUNT() FROM Account]);
        Assert.isTrue(
                (dmlAfter - dmlBefore) <= 4,
                'A two-level graph should cost a handful of DML statements, not one per record; used '
                        + (dmlAfter - dmlBefore)
        );
    }

    /** Generating 1000 primary records in memory must not blow the heap. */
    @IsTest
    static void largeInMemoryGenerationStaysUnderTheHeapBudget() {
        List<SObject> accounts;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            accounts = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                    .setQuantityPerTemplate(1000)
                    .setInclusivity(XFTY_InsertInclusivityEnum.NONE)
                    .setInsertMode(XFTY_InsertModeEnum.NEVER)
                    .supplyList();
            Test.stopTest();
        }

        Assert.areEqual(1000, accounts.size());
        Assert.isTrue(
                Limits.getHeapSize() < 4000000,
                'Heap should stay well under the 6MB synchronous limit, was ' + Limits.getHeapSize()
        );
    }
}

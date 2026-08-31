/**
 * Volume tests: push XFTY generation toward the per-transaction governor limits
 * and record where each one breaks, so the numbers in
 * docs/reference/volume-and-limits.md stay honest.
 *
 * In `test-support/` (not the published package): the assertions are ceilings
 * that assume a quiet org - no consumer triggers / flows on Account / Contact -
 * so shipping them would risk failing in a consumer's org.
 *
 * DML statements / rows and SOQL are exact and machine-independent (Nimbus and
 * Salesforce agree). CPU here is Nimbus's virtual clock locally and real ms on an
 * org; heap is only measured on an org (`Limits.getHeapSize()` is 0 under Nimbus).
 * Run: `sf apex run test --suite-names XFTY_Load`.
 */
@IsTest
private class XFTY_LoadTest {
    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    /**
     * DML rows are the first plain-generation ceiling. A Contact + its Account is
     * 2 rows per primary, so ~5 000 primaries hits the 10 000-row limit. 3 000
     * primaries (6 000 rows) must still leave headroom.
     */
    @IsTest
    static void nowGenerationOfThreeThousandPrimariesStaysUnderTheDmlRowLimit() {
        Integer rowsBefore;
        Integer rowsAfter;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            rowsBefore = Limits.getDmlRows();
            new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .setQuantityPerTemplate(3000)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .supplyList();
            rowsAfter = Limits.getDmlRows();
            Test.stopTest();
        }

        Assert.areEqual(3000, [SELECT COUNT() FROM Contact]);
        Assert.areEqual(6000, rowsAfter - rowsBefore, 'a 2-level graph is 2 DML rows per primary');
        Assert.isTrue(rowsAfter - rowsBefore < Limits.getLimitDmlRows(), 'stays under the 10 000-row limit');
    }

    /**
     * DML *statements* are one per Provider (per level) without `.depthBatched()`.
     * A 3-parent-type graph is 4 statements regardless of row count - nowhere near
     * the 150 limit, which only a graph of >150 distinct Providers could reach.
     */
    @IsTest
    static void wideGraphCostsOneDmlStatementPerProviderNotPerRow() {
        Integer stmtsBefore;
        Integer stmtsAfter;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            stmtsBefore = Limits.getDmlStatements();
            new XFTY_DummySObjectProvider(Task.SObjectType, XFTY_LoadProviders.lookup())
                    .putRequired(Task.WhatId, new XFTY_DummyDefaultRelationship(new Account()))
                    .putRequired(Task.WhoId, new XFTY_DummyDefaultRelationship(new Contact()))
                    .setQuantityPerTemplate(200)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .supplyList();
            stmtsAfter = Limits.getDmlStatements();
            Test.stopTest();
        }

        Assert.areEqual(200, [SELECT COUNT() FROM Task]);
        Assert.isTrue(
                stmtsAfter - stmtsBefore <= 6,
                'Account + Contact + User + Task = a handful of statements for 200 rows; used '
                        + (stmtsAfter - stmtsBefore)
        );
    }

    /**
     * XFTY's own SOQL is a small constant - the admin-user bootstrap and, at most,
     * one record-type query for the whole transaction - not a function of volume.
     */
    @IsTest
    static void generationSoqlDoesNotGrowWithVolume() {
        Integer queriesBefore;
        Integer queriesAfter;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            queriesBefore = Limits.getQueries();
            new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .setQuantityPerTemplate(500)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supplyList();
            queriesAfter = Limits.getQueries();
            Test.stopTest();
        }

        Assert.isTrue(
                queriesAfter - queriesBefore <= 2,
                'MOCK generation of 500 primaries should spend ~0 SOQL; used ' + (queriesAfter - queriesBefore)
        );
    }

    /**
     * Heap ceiling (measured on an org; 0 under Nimbus). 5 000 primaries with a
     * generated parent each, held in memory with no insert, must stay well under
     * the 6 MB synchronous heap limit.
     */
    @IsTest
    static void fiveThousandPrimariesInMemoryStayUnderTheHeapLimit() {
        List<SObject> contacts;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            contacts = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .setQuantityPerTemplate(5000)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.NEVER)
                    .supplyBundle()
                    .primaryRecords();
            Test.stopTest();
        }

        Assert.areEqual(5000, contacts.size());
        Assert.isTrue(
                Limits.getHeapSize() == 0 || Limits.getHeapSize() < Limits.getLimitHeapSize() * 0.75,
                'heap after 5 000 Contact+Account should stay under 75% of the limit, was ' + Limits.getHeapSize()
        );
    }

    /**
     * CPU ceiling. A deep chain (5 Account levels via distinct flavour keys) times
     * 100 primaries - 600 records - is a heavy but legitimate setup. It must land
     * well under the 10 s synchronous CPU limit.
     */
    @IsTest
    static void aDeepChainTimesHundredStaysUnderTheCpuLimit() {
        Long cpuBefore;
        Long cpuAfter;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            cpuBefore = Limits.getCpuTime();
            new XFTY_DummySObjectProvider(XFTY_HierarchyKeys.LEVEL_1, XFTY_HierarchyKeys.lookup())
                    .setQuantityPerTemplate(100)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supplyList();
            cpuAfter = Limits.getCpuTime();
            Test.stopTest();
        }

        Assert.isTrue(
                cpuAfter - cpuBefore < Limits.getLimitCpuTime() * 0.75,
                'a 5-deep chain x 100 should stay under 75% of the CPU limit, used ' + (cpuAfter - cpuBefore)
        );
    }
}

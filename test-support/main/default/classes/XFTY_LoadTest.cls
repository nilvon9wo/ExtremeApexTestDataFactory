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
    private static final Decimal SAFE_FRACTION_OF_LIMIT = 0.75;

    @IsTest
    static void testGenerate_forThreeThousandPrimariesInNowMode_staysUnderTheDmlRowLimit() {
        // Arrange - a Contact + its Account is 2 rows per primary, so 3 000 primaries = 6 000 rows
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setQuantityPerTemplate(3000)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW);

        // Act
        Usage used;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            used = generate(provider);
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(3000, [SELECT COUNT() FROM Contact]);
        Assert.areEqual(6000, used.dmlRows, 'a 2-level graph is 2 DML rows per primary');
        Assert.isTrue(used.dmlRows < Limits.getLimitDmlRows(), 'stays under the 10 000-row limit');
    }

    @IsTest
    static void testGenerate_forAWideGraph_costsOneDmlStatementPerProviderNotPerRow() {
        // Arrange - a Task with an Account, a Contact and a User parent: 4 Provider levels, 200 rows
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Task.SObjectType, XFTY_LoadProviders.lookup())
                .putRequired(Task.WhatId, new XFTY_DummyDefaultRelationship(new Account()))
                .putRequired(Task.WhoId, new XFTY_DummyDefaultRelationship(new Contact()))
                .setQuantityPerTemplate(200)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW);

        // Act
        Usage used;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            used = generate(provider);
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(200, [SELECT COUNT() FROM Task]);
        Assert.isTrue(used.dmlStatements <= 6,
                'Account + Contact + User + Task = a handful of statements for 200 rows; used ' + used.dmlStatements);
    }

    @IsTest
    static void testGenerate_soqlDoesNotGrowWithVolume() {
        // Arrange - MOCK generation of 500 primaries: XFTY's own SOQL is a small constant
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setQuantityPerTemplate(500)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Usage used;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            used = generate(provider);
            Test.stopTest();
        }

        // Assert
        Assert.isTrue(used.queries <= 2,
                'MOCK generation of 500 primaries should spend ~0 SOQL; used ' + used.queries);
    }

    @IsTest
    static void testGenerate_forFiveThousandPrimariesHeldInMemory_staysUnderTheHeapLimit() {
        // Arrange - 5 000 primaries with a generated parent each, held in memory, no insert
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setQuantityPerTemplate(5000)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NEVER);

        // Act
        Usage used;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            used = generateBundlePrimaries(provider);
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(5000, used.records.size());
        Assert.isTrue(
                used.heapAtEnd == 0 || used.heapAtEnd < Limits.getLimitHeapSize() * SAFE_FRACTION_OF_LIMIT,
                'heap after 5 000 Contact+Account should stay under 75% of the limit, was ' + used.heapAtEnd
        );
    }

    @IsTest
    static void testGenerate_forADeepAndWideGraphTimesOneHundred_staysUnderTheCpuLimit() {
        // Arrange - a 5-level Account chain that also generates a User per level (~10 records/primary), x 100
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(
                XFTY_HierarchyKeys.LEVEL_1, XFTY_HierarchyKeys.lookup()
        )
                .setQuantityPerTemplate(100)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Usage used;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            used = generateBundlePrimaries(provider);
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(100, used.records.size());
        Assert.isTrue(
                used.cpuTime < Limits.getLimitCpuTime() * SAFE_FRACTION_OF_LIMIT,
                'a 5-deep, User-at-every-level graph x 100 should stay under 75% of the CPU limit, used ' + used.cpuTime
        );
    }

    @IsTest
    static void testGenerate_downwardGenerationMultipliesRowsButNotStatements() {
        // Arrange - 15 Accounts, 10 Contacts each, 2 Cases per Contact: 15 + 150 + 300 = 465 records
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, XFTY_LoadProviders.lookup())
                .setQuantityPerTemplate(15)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .depthBatched()
                .with(
                        new XFTY_SObjectChildProvider(Contact.AccountId).setQuantity(10)
                                .with(new XFTY_SObjectChildProvider(Case.ContactId).setQuantity(2))
                );

        // Act
        Usage used;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            used = generateBundlePrimaries(provider);
            Test.stopTest();
        }

        // Assert - the row count multiplies, the statement count does not
        Assert.areEqual(15, [SELECT COUNT() FROM Account]);
        Assert.areEqual(150, [SELECT COUNT() FROM Contact]);
        Assert.areEqual(300, [SELECT COUNT() FROM Case]);
        Assert.isTrue(used.dmlStatements <= 8,
                'depth-batched downward generation is a handful of inserts, not one per level per parent, used ' + used.dmlStatements);
        Assert.isTrue(used.cpuTime < Limits.getLimitCpuTime() * SAFE_FRACTION_OF_LIMIT,
                '465 records across three levels stays well under the CPU limit, used ' + used.cpuTime);
    }

    @IsTest
    static void testGenerate_theContextAwareValuePassStaysCheapAtVolume() {
        // Arrange - 3 000 Contacts, each with a sibling copy and a custom context-aware expression.
        // MOCK isolates the value-pass cost from DML.
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setQuantityPerTemplate(3000)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .put(Contact.MailingCity, new XFTY_IncrementingStringExpression('City'))
                .put(Contact.MailingState, new XFTY_CopyFromSiblingExpression(Contact.MailingCity))
                .put(Contact.Description, new CityLabel());

        // Act
        Usage used;
        Test.startTest();
        used = generate(provider);
        Test.stopTest();

        // Assert
        Assert.areEqual(3000, used.records.size());
        Assert.areEqual(0, used.dmlStatements, 'MOCK - the value pass alone');
        Assert.isTrue(used.cpuTime < Limits.getLimitCpuTime() * SAFE_FRACTION_OF_LIMIT,
                'two context-aware expressions per record over 3 000 records stays under 75% of the CPU limit, used ' + used.cpuTime);
    }

    private class CityLabel implements XFTY_ContextAwareExpressionIntf {
        public Object get(XFTY_GenerationContext context) {
            return 'in ' + (String) context.siblingValue(Contact.MailingCity);
        }
    }

    // Fixture -------------------------------------------------------------

    private static Usage generate(XFTY_DummySObjectProvider provider) {
        Usage used = new Usage();
        used.records = provider.supplyList();
        used.recordEnd();
        return used;
    }

    private static Usage generateBundlePrimaries(XFTY_DummySObjectProvider provider) {
        Usage used = new Usage();
        used.records = provider.supplyBundle().primaryRecords();
        used.recordEnd();
        return used;
    }

    /** Governor usage across one generation call: deltas for the metered limits, plus the heap it ended on. */
    private class Usage {
        private final Integer dmlRowsStart = Limits.getDmlRows();
        private final Integer dmlStatementsStart = Limits.getDmlStatements();
        private final Integer queriesStart = Limits.getQueries();
        private final Long cpuTimeStart = Limits.getCpuTime();

        private List<SObject> records;
        private Integer dmlRows;
        private Integer dmlStatements;
        private Integer queries;
        private Long cpuTime;
        private Integer heapAtEnd;

        private void recordEnd() {
            this.dmlRows = Limits.getDmlRows() - this.dmlRowsStart;
            this.dmlStatements = Limits.getDmlStatements() - this.dmlStatementsStart;
            this.queries = Limits.getQueries() - this.queriesStart;
            this.cpuTime = Limits.getCpuTime() - this.cpuTimeStart;
            this.heapAtEnd = Limits.getHeapSize();
        }
    }
}

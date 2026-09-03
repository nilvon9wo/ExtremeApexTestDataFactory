/**
 * Volume tests for serialization enrichment - how far `bundle.injectAll` /
 * `inject` and `XFTY_SObjectInjector` scale before the `JSON.serialize` /
 * `deserialize` round-trip runs into the CPU / heap ceilings.
 *
 * The headline: the enrichment pass does **one round-trip per graph level**, not
 * per record, so cost grows with depth and total payload size, not with primary
 * count on its own.
 *
 * `test-support/` only (ceilings assume a quiet org). CPU is Nimbus's virtual
 * clock locally and real ms on an org; heap is 0 under Nimbus. MOCK generation
 * throughout - no DML - so the numbers are the enrichment cost alone.
 * Run: `sf apex run test --suite-names XFTY_Load`.
 */
@IsTest
private class XFTY_EnrichmentLoadTest {

    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;
    private static final Decimal SAFE_FRACTION_OF_LIMIT = 0.75;

    @IsTest
    static void testInjectAll_overAWideShallowGraph_staysCheapRegardlessOfWidth() {
        // Arrange - 1 000 Contacts, each with its generated Account (1 ancestor level)
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(
                Contact.SObjectType, new XFTY_DefaultSObjectProviderLookup()
        )
                .setQuantityPerTemplate(1000)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .supplyBundle();

        // Act
        Usage used;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            used = enrich(bundle, Contact.Id, XFTY_InjectConfig.everything());
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(1000, used.records.size());
        Assert.isNotNull(((Contact) used.records[0]).Account, 'the ancestor was grafted onto every row');
        Assert.isTrue(used.cpuTime < Limits.getLimitCpuTime() * SAFE_FRACTION_OF_LIMIT,
                '1 000 wide x 1 level stays under 75% of the CPU limit, used ' + used.cpuTime);
    }

    @IsTest
    static void testInjectAll_overADeepAncestorChain_costsOneRoundTripPerLevel() {
        // Arrange - 200 primaries, each pulling a 5-deep Account chain with a User at every level
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(
                XFTY_HierarchyKeys.LEVEL_1, XFTY_HierarchyKeys.lookup()
        )
                .setQuantityPerTemplate(200)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .supplyBundle();

        // Act
        Usage used;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            used = enrich(bundle, Account.Id, XFTY_InjectConfig.allParents());
            Test.stopTest();
        }

        // Assert - the 5-deep Parent chain is walkable off the record
        Account top = (Account) used.records[0];
        Assert.isNotNull(top.Parent.Parent.Parent.Parent, '5 levels grafted');
        Assert.isTrue(used.cpuTime < Limits.getLimitCpuTime() * SAFE_FRACTION_OF_LIMIT,
                '200 x 5-deep (each level also carrying its User) stays under 75% of CPU, used ' + used.cpuTime);
    }

    @IsTest
    static void testInjectAllChildren_overAWideDeepDescendantTree_scalesWithPayloadNotParentCount() {
        // Arrange - 50 Accounts, 15 Contacts each, 2 Cases per Contact: 50 + 750 + 1 500
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, XFTY_LoadProviders.lookup())
                .setQuantityPerTemplate(50)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .with(
                        new XFTY_SObjectChildProvider(Contact.AccountId).setQuantity(15)
                                .with(new XFTY_SObjectChildProvider(Case.ContactId).setQuantity(2))
                )
                .supplyBundle();

        // Act
        Usage used;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            used = enrich(bundle, Account.Id, XFTY_InjectConfig.allChildren());
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(15, ((Account) used.records[0]).Contacts.size(), 'the subquery is on every Account');
        Assert.isTrue(used.cpuTime < Limits.getLimitCpuTime() * SAFE_FRACTION_OF_LIMIT,
                '50 Accounts over a 2 300-record descendant tree stays under 75% of CPU, used ' + used.cpuTime);
    }

    @IsTest
    static void testInjectAll_bothDirectionsAtVolume_staysUnderTheCeiling() {
        // Arrange - 250 Accounts, 15 Contacts each below (the Cases are generated but one level
        // past what a single SOQL subquery could return, so they are not injected)
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, XFTY_LoadProviders.lookup())
                .setQuantityPerTemplate(250)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .with(
                        new XFTY_SObjectChildProvider(Contact.AccountId).setQuantity(15)
                                .with(new XFTY_SObjectChildProvider(Case.ContactId).setQuantity(2))
                )
                .supplyBundle();

        // Act
        Usage used;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            used = enrich(bundle, Account.Id, XFTY_InjectConfig.everything());
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(15, ((Account) used.records[0]).Contacts.size(), 'children grafted');
        Assert.isTrue(used.cpuTime < Limits.getLimitCpuTime() * SAFE_FRACTION_OF_LIMIT,
                '250 Accounts x 15 injected Contacts, everything() pass, under 75% of CPU, used ' + used.cpuTime);
    }

    @IsTest
    static void testSObjectInjector_atHighRowCount_isOneSerializeAndOneDeserialize() {
        // Arrange - 3 000 Contacts, each getting a parent Account and a forced system field
        List<SObject> contacts = new List<SObject>();
        List<SObject> accounts = new List<SObject>();
        for (Integer i = 0; i < 3000; i++) {
            contacts.add(new Contact(LastName = 'Row ' + i));
            accounts.add(new Account(Name = 'Parent ' + i));
        }
        Datetime created = Datetime.newInstance(2020, 1, 1, 0, 0, 0);

        // Act
        Usage used = new Usage();
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            used.records = XFTY_SObjectInjector.inject(contacts)
                    .relationship('Account', accounts)
                    .value(Contact.CreatedDate, created)
                    .result();
            used.recordEnd();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(3000, used.records.size());
        Assert.areEqual('Parent 2999', ((Contact) used.records[2999]).Account.Name);
        Assert.isTrue(used.cpuTime < Limits.getLimitCpuTime() * SAFE_FRACTION_OF_LIMIT,
                'one round-trip over 3 000 rows stays under 75% of CPU, used ' + used.cpuTime);
    }

    // Fixtures ----------------------------------------------------------

    private static Usage enrich(XFTY_DummySObjectBundle bundle, SObjectField field, XFTY_InjectConfig config) {
        Usage used = new Usage();
        used.records = bundle.inject(field, config);
        used.recordEnd();
        return used;
    }

    private class Usage {
        private final Long cpuTimeStart = Limits.getCpuTime();
        private List<SObject> records;
        private Long cpuTime;
        private Integer heapAtEnd;

        private void recordEnd() {
            this.cpuTime = Limits.getCpuTime() - this.cpuTimeStart;
            this.heapAtEnd = Limits.getHeapSize();
        }
    }
}

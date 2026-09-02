/**
 * Shared ancestors at volume: the shared record costs one insert however many
 * children reference it, a deep shared chain stays a handful of statements, and
 * many `supply*()` calls resolve it once.
 *
 * `test-support/` only - the assertions assume a quiet org. See
 * docs/reference/volume-and-limits.md.
 */
@IsTest
private class XFTY_SharedAncestorLoadTest {

    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;
    private static final XFTY_LookupKeyIntf LEVEL1_KEY = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'level1');
    private static final Integer FRUGAL_STATEMENT_CEILING = 4;

    @IsTest
    static void testSupplyList_forFiveHundredChildrenUnderOneSharedAncestor_costsOneParentInsert() {
        // Arrange
        XFTY_SharedAncestor.put('hq', new Account(Name = 'Shared HQ'));

        // Act
        Usage used;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            used = supplyMeasured(500, defaultContactsUnderHq());
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(1, [SELECT COUNT() FROM Account], 'one shared Account, not 500');
        Assert.areEqual(500, [SELECT COUNT() FROM Contact]);
        Assert.areEqual(501, used.rows, '1 Account row + 500 Contact rows');
        Assert.isTrue(used.statements <= FRUGAL_STATEMENT_CEILING,
                'a handful of DML statements for 500 shared-ancestor children, used ' + used.statements);
    }

    @IsTest
    static void testSupply_forADeepSharedChain_staysStatementFrugal() {
        // Arrange - Contact -> shared level1 -> shared root, four leaves
        XFTY_SharedAncestor.put('root', new Account(Name = 'Root'))
                .fromVariant(XFTY_LookupKey.get(Account.SObjectType));
        XFTY_SharedAncestor.put('level1', new Account(Name = 'Level 1'))
                .fromVariant(LEVEL1_KEY);

        // Act
        Usage used;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            used = supplyMeasured(4, deepChainLookup());
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(2, [SELECT COUNT() FROM Account], 'root + level1');
        Assert.areEqual(4, [SELECT COUNT() FROM Contact]);
        Assert.isTrue(used.statements <= FRUGAL_STATEMENT_CEILING,
                'root + level1 + four Contacts should be a handful of statements, used ' + used.statements);
    }

    @IsTest
    static void testSupply_forManyIndependentSharedAncestors_staysStatementFrugal() {
        // Arrange - 12 independent shared Accounts, each referenced by its own Contacts.
        // S2 depth-batches per sub-graph, so this is the "several independent heavy
        // ancestors" case the docs flag as a known limit - it must still be bounded.
        List<String> names = new List<String>();
        for (Integer i = 0; i < 12; i++) {
            String name = 'hq' + i;
            names.add(name);
            XFTY_SharedAncestor.put(name, new Account(Name = 'Shared ' + name));
        }

        // Act
        Usage used;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            used = new Usage();
            for (String name : names) {
                supplyContacts(10, contactsUnder(name));
            }
            used.recordEnd();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(12, [SELECT COUNT() FROM Account], 'one Account per shared ancestor');
        Assert.areEqual(120, [SELECT COUNT() FROM Contact]);
        Assert.isTrue(used.statements <= 12 + 12,
                '12 shared-ancestor inserts + at most one Contact insert per supply call, used ' + used.statements);
        Assert.isTrue(used.cpuMs < 4000, 'well inside the CPU budget, used ' + used.cpuMs + ' ms');
    }

    @IsTest
    static void testSupply_forATenLevelSharedChain_insertsOnePerLevelNotOnePerRecord() {
        // Arrange - Root <- L1 <- ... <- L9, all shared; five leaf Contacts under L9
        configureTenLevelChain();

        // Act
        Usage used;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            used = supplyMeasured(5, tenLevelLookup());
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(10, [SELECT COUNT() FROM Account], 'one row per shared level');
        Assert.areEqual(5, [SELECT COUNT() FROM Contact]);
        Assert.isTrue(used.statements <= 12,
                'the ten-level chain depth-batches - not one insert per record, used ' + used.statements);
        Assert.isTrue(used.cpuMs < 4000, 'used ' + used.cpuMs + ' ms');
    }

    @IsTest
    static void testSupply_forOneSharedAncestorAcrossManyCalls_resolvesItOnce() {
        // Arrange
        XFTY_SharedAncestor.put('hq', new Account(Name = 'Shared HQ'));

        // Act - three separate supply calls
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            supplyContacts(100, defaultContactsUnderHq());
            supplyContacts(100, defaultContactsUnderHq());
            supplyContacts(100, defaultContactsUnderHq());
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(1, [SELECT COUNT() FROM Account], 'still one shared Account across all three calls');
        Assert.areEqual(300, [SELECT COUNT() FROM Contact]);
    }

    // Fixture ---------------------------------------------------------------

    private static Usage supplyMeasured(Integer howMany, XFTY_DummySObjectProviderLookupIntf lookup) {
        Usage used = new Usage();
        supplyContacts(howMany, lookup);
        used.recordEnd();
        return used;
    }

    private static void supplyContacts(Integer howMany, XFTY_DummySObjectProviderLookupIntf lookup) {
        new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
                .setQuantityPerTemplate(howMany)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .supplyList();
    }

    private static XFTY_DummySObjectProviderLookupIntf defaultContactsUnderHq() {
        return contactsUnder('hq');
    }

    private static XFTY_DummySObjectProviderLookupIntf contactsUnder(String sharedName) {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Account.SObjectType) => new XFTY_DefaultAccountDataProvider(),
                XFTY_LookupKey.get(Contact.SObjectType) => new ContactUnderShared(sharedName)
        });
    }

    private static void configureTenLevelChain() {
        XFTY_SharedAncestor.put('L0', new Account(Name = 'Root')).fromVariant(chainKey(0));
        for (Integer level = 1; level <= 9; level++) {
            XFTY_SharedAncestor.put('L' + level, new Account(Name = 'Level ' + level))
                    .fromVariant(chainKey(level))
                    .putRequired(Account.ParentId, XFTY_SharedAncestor.get('L' + (level - 1)))
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED);
        }
    }

    private static XFTY_DummySObjectProviderLookupIntf tenLevelLookup() {
        Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf> byKey =
                new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                        XFTY_LookupKey.get(Account.SObjectType) => new XFTY_DefaultAccountDataProvider(),
                        XFTY_LookupKey.get(Contact.SObjectType) => new ContactUnderShared('L9')
                };
        for (Integer level = 0; level <= 9; level++) {
            byKey.put(chainKey(level), new XFTY_DefaultAccountDataProvider());
        }
        return XFTY_ProviderLookups.of(byKey);
    }

    private static XFTY_LookupKeyIntf chainKey(Integer level) {
        return XFTY_FlavouredLookupKey.get(Account.SObjectType, 'chainL' + level);
    }

    private static XFTY_DummySObjectProviderLookupIntf deepChainLookup() {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Account.SObjectType) => new XFTY_DefaultAccountDataProvider(),
                LEVEL1_KEY => new AccountUnderShared('root'),
                XFTY_LookupKey.get(Contact.SObjectType) => new ContactUnderShared('level1')
        });
    }

    private class Usage {
        private final Integer startStatements = Limits.getDmlStatements();
        private final Integer startRows = Limits.getDmlRows();
        private final Integer startCpu = Limits.getCpuTime();
        private Integer statements;
        private Integer rows;
        private Integer cpuMs;

        private void recordEnd() {
            this.statements = Limits.getDmlStatements() - this.startStatements;
            this.rows = Limits.getDmlRows() - this.startRows;
            this.cpuMs = Limits.getCpuTime() - this.startCpu;
        }
    }

    private class ContactUnderShared implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template;

        private ContactUnderShared(String sharedName) {
            this.template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                    .put(Contact.LastName, new XFTY_IncrementingStringExpression('Leaf'))
                    .putRequired(Contact.AccountId, XFTY_SharedAncestor.get(sharedName));
        }

        public SObjectField getPrimaryTargetField() {
            return Contact.Id;
        }

        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }

        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext context, List<SObject> templates) {
            return XFTY_DummySObjectFactory.createBundle(context, this.template, templates);
        }
    }

    private class AccountUnderShared implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template;

        private AccountUnderShared(String sharedParentName) {
            this.template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                    .put(Account.Name, new XFTY_IncrementingStringExpression('Mid'))
                    .putRequired(Account.ParentId, XFTY_SharedAncestor.get(sharedParentName));
        }

        public SObjectField getPrimaryTargetField() {
            return Account.Id;
        }

        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }

        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext context, List<SObject> templates) {
            return XFTY_DummySObjectFactory.createBundle(context, this.template, templates);
        }
    }
}

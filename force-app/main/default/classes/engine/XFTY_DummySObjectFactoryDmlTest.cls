/**
 * The DML-backed insert modes of `XFTY_DummySObjectFactory` - `NOW` and
 * `RELATED_ONLY` - and `.depthBatched()`, split out from
 * `XFTY_DummySObjectFactoryTest` so the unit suite can skip them. All real DML,
 * so `System.runAs`.
 */
@IsTest
private class XFTY_DummySObjectFactoryDmlTest {

    private static final XFTY_DefaultSObjectProviderLookup DEFAULT_LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    private static XFTY_DummySObjectProviderLookupIntf taskLookup(XFTY_DummySobjectProviderIntf taskProvider) {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Task.SObjectType) => taskProvider,
                XFTY_LookupKey.get(Account.SObjectType) => new LeafProvider(Account.Id, Account.Name),
                XFTY_LookupKey.get(Contact.SObjectType) => new LeafProvider(Contact.Id, Contact.LastName)
        });
    }

    private static XFTY_DummySObjectProvider nowTaskProvider(XFTY_DummySobjectProviderIntf provider) {
        return new XFTY_DummySObjectProvider(Task.SObjectType, taskLookup(provider))
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW);
    }

    // NOW / RELATED_ONLY --------------------------------------

    @IsTest
    static void testSupplyBundle_inNowMode_insertsEveryGeneratedRecordAndPersistsTheFk() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, DEFAULT_LOOKUP)
                .setOverrideTemplate(new Contact(LastName = 'Factory Test'))
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW);

        // Act
        XFTY_DummySObjectBundle bundle;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            bundle = provider.supplyBundle();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(1, [SELECT COUNT() FROM Contact]);
        Assert.areEqual(1, [SELECT COUNT() FROM Account]);
        Assert.areEqual(bundle.getList(Contact.AccountId)[0].Id, [SELECT AccountId FROM Contact LIMIT 1].AccountId);
    }

    @IsTest
    static void testSupplyBundle_inRelatedOnlyMode_insertsTheParentsButNotThePrimaryRecords() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, DEFAULT_LOOKUP)
                .setOverrideTemplate(new Contact(LastName = 'Factory Test'))
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.RELATED_ONLY);

        // Act
        XFTY_DummySObjectBundle bundle;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            bundle = provider.supplyBundle();
            Test.stopTest();
        }

        // Assert
        Assert.isNull(bundle.getList(Contact.Id)[0].Id, 'the requested Contact is left uninserted');
        Assert.isNotNull(bundle.getList(Contact.AccountId)[0].Id, 'the related Account is inserted');
        Assert.areEqual(0, [SELECT COUNT() FROM Contact]);
        Assert.areEqual(1, [SELECT COUNT() FROM Account]);
        Assert.areEqual(
                bundle.getList(Contact.AccountId)[0].Id,
                ((Contact) bundle.getList(Contact.Id)[0]).AccountId
        );
    }

    // How the engine batches insert statements today ---------
    // Each createBundle recursion ends in its own `insert`, so records from one
    // recursion (siblings, N copies) share an insert but a parent of a different
    // SObjectType is a separate recursion, hence a separate insert.

    @IsTest
    static void testSupplyList_inNowMode_withOneParentType_costsTwoInserts() {
        assertInsertCount(nowTaskProvider(new OneParentTaskProvider()), 2, 'Account insert + Task insert');
    }

    @IsTest
    static void testSupplyList_inNowMode_withTwoParentTypes_costsThreeInserts() {
        assertInsertCount(nowTaskProvider(new TwoParentTaskProvider()), 3,
                'a second parent SObjectType adds one insert - the recursion is per Provider');
    }

    @IsTest
    static void testSupplyList_inNowMode_withQuantity_doesNotAddInserts() {
        assertInsertCount(nowTaskProvider(new OneParentTaskProvider()).setQuantityPerTemplate(5), 2,
                'the copies share one createBundle recursion');
    }

    // .depthBatched() - opt-in: one insert per dependency depth --

    @IsTest
    static void testSupplyList_depthBatched_withTwoParentTypes_collapsesToOneInsertPerDepth() {
        assertInsertCount(nowTaskProvider(new TwoParentTaskProvider()).depthBatched(), 2,
                'Account + Contact batch at depth 0, the Task at depth 1 - down from 3');
    }

    @IsTest
    static void testSupplyList_depthBatched_withOneParentType_isUnchangedAtTwoInserts() {
        assertInsertCount(nowTaskProvider(new OneParentTaskProvider()).depthBatched(), 2,
                'a single-parent graph was already 2 inserts');
    }

    @IsTest
    static void testSupplyBundle_depthBatched_insertsEveryRecordAndWiresTheLookups() {
        // Arrange
        XFTY_DummySObjectProvider provider = nowTaskProvider(new TwoParentTaskProvider()).depthBatched();

        // Act
        XFTY_DummySObjectBundle bundle;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            bundle = provider.supplyBundle();
            Test.stopTest();
        }

        // Assert
        SObject generatedTask = bundle.getList(Task.Id)[0];
        Id parentAccountId = bundle.getList(Task.WhatId)[0].Id;
        Id parentContactId = bundle.getList(Task.WhoId)[0].Id;
        Assert.isNotNull(generatedTask.Id, 'the Task is inserted');
        Assert.isNotNull(parentAccountId, 'the Account parent is inserted');
        Assert.isNotNull(parentContactId, 'the Contact parent is inserted');
        Assert.areEqual(parentAccountId, generatedTask.get(Task.WhatId), 'WhatId points at the fresh Account Id');
        Assert.areEqual(parentContactId, generatedTask.get(Task.WhoId), 'WhoId points at the fresh Contact Id');
        Assert.areEqual(
                generatedTask.Id,
                [SELECT Id FROM Task WHERE WhatId = :parentAccountId AND WhoId = :parentContactId].Id
        );
    }

    @IsTest
    static void testSupplyList_depthBatched_inMockMode_doesNoDml() {
        // Arrange
        XFTY_DummySObjectProviderLookupIntf lookup = taskLookup(new TwoParentTaskProvider());
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Task.SObjectType, lookup)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .depthBatched();

        // Act
        Integer dml;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            Integer before = Limits.getDmlStatements();
            provider.supplyList();
            dml = Limits.getDmlStatements() - before;
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(0, dml, 'MOCK does no DML - .depthBatched() has nothing to do');
    }

    // Runner -------------------------------------------------

    static void assertInsertCount(XFTY_DummySObjectProvider provider, Integer expectedInserts, String because) {
        // Arrange - the caller supplies a NOW-mode provider

        // Act
        Integer inserts;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            Integer before = Limits.getDmlStatements();
            provider.supplyList();
            inserts = Limits.getDmlStatements() - before;
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(expectedInserts, inserts, because);
    }

    // In-test Providers ------------------------------------

    private class LeafProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template;
        private LeafProvider(SObjectField idField, SObjectField nameField) {
            this.template = new XFTY_DummySObjectMasterTemplate(idField)
                    .put(nameField, new XFTY_IncrementingStringExpression('Leaf'));
        }
        public SObjectField getPrimaryTargetField() {
            return this.template.primaryTargetField;
        }
        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }
        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext context, List<SObject> templateList) {
            return XFTY_DummySObjectFactory.createBundle(context, this.template, templateList);
        }
    }

    private class OneParentTaskProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Task.Id)
                .put(Task.Subject, new XFTY_IncrementingStringExpression('One Parent Task'))
                .putRequired(Task.WhatId, new XFTY_DummyDefaultRelationship(new Account()));
        public SObjectField getPrimaryTargetField() {
            return Task.Id;
        }
        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }
        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext context, List<SObject> templateList) {
            return XFTY_DummySObjectFactory.createBundle(context, this.template, templateList);
        }
    }

    private class TwoParentTaskProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Task.Id)
                .put(Task.Subject, new XFTY_IncrementingStringExpression('Two Parent Task'))
                .putRequired(Task.WhatId, new XFTY_DummyDefaultRelationship(new Account()))
                .putRequired(Task.WhoId, new XFTY_DummyDefaultRelationship(new Contact()));
        public SObjectField getPrimaryTargetField() {
            return Task.Id;
        }
        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }
        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext context, List<SObject> templateList) {
            return XFTY_DummySObjectFactory.createBundle(context, this.template, templateList);
        }
    }
}

/**
 * The DML-backed insert modes of `XFTY_DummySObjectFactory` - `NOW` and
 * `RELATED_ONLY` - split out from `XFTY_DummySObjectFactoryTest` so the unit
 * suite (`XFTY_Unit`) can run without them. This class is in `XFTY_Integration`.
 *
 * The mode/inclusivity matrix that needs no DML stays in
 * `XFTY_DummySObjectFactoryTest`.
 */
@IsTest
private class XFTY_DummySObjectFactoryDmlTest {
    private static final XFTY_DefaultSObjectProviderLookup DEFAULT_LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    @IsTest
    static void nowInsertsEveryGeneratedRecord() {
        XFTY_DummySObjectBundle bundle = supplyContact(XFTY_InsertModeEnum.NOW);

        Assert.areEqual(1, [SELECT COUNT() FROM Contact]);
        Assert.areEqual(1, [SELECT COUNT() FROM Account]);
        Assert.areEqual(
                bundle.getList(Contact.AccountId)[0].Id,
                [SELECT AccountId FROM Contact LIMIT 1].AccountId
        );
    }

    @IsTest
    static void relatedOnlyInsertsParentsButNotThePrimaryRecords() {
        XFTY_DummySObjectBundle bundle = supplyContact(XFTY_InsertModeEnum.RELATED_ONLY);

        Assert.isNull(bundle.getList(Contact.Id)[0].Id, 'The requested Contact is left uninserted');
        Assert.isNotNull(bundle.getList(Contact.AccountId)[0].Id, 'The related Account is inserted');
        Assert.areEqual(0, [SELECT COUNT() FROM Contact]);
        Assert.areEqual(1, [SELECT COUNT() FROM Account]);
        Assert.areEqual(
                bundle.getList(Contact.AccountId)[0].Id,
                ((Contact) bundle.getList(Contact.Id)[0]).AccountId
        );
    }

    /**
     * How many `insert` statements does a graph with two different SObjectTypes at
     * the same depth cost? A Task under a leaf Account (`WhatId`) *and* a leaf
     * Contact (`WhoId`), `NOW`. Records: Account (depth 1), Contact (depth 1),
     * Task (depth 0).
     *
     * Depth-batched persistence would be 2 (one `insert` for {Account, Contact},
     * one for {Task}). This asserts the actual number so a future depth-batching
     * change shows up as an intended drop.
     */
    @IsTest
    static void insertStatementsForTwoParentTypesAtOneDepth() {
        CustomLookup lookup = new CustomLookup()
                .register(Task.SObjectType, new TwoParentTaskProvider())
                .register(Account.SObjectType, new LeafProvider(Account.Id, Account.Name))
                .register(Contact.SObjectType, new LeafProvider(Contact.Id, Contact.LastName));

        Integer inserts;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            Integer before = Limits.getDmlStatements();
            new XFTY_DummySObjectProvider(Task.SObjectType, lookup)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .supply();
            inserts = Limits.getDmlStatements() - before;
            Test.stopTest();
        }

        Assert.areEqual(1, [SELECT COUNT() FROM Task]);
        Assert.areEqual(1, [SELECT COUNT() FROM Account]);
        Assert.areEqual(1, [SELECT COUNT() FROM Contact]);
        Assert.areEqual(3, inserts,
                'one insert per Provider today - Account, Contact, Task separately');
    }

    private static XFTY_DummySObjectBundle supplyContact(XFTY_InsertModeEnum insertMode) {
        XFTY_DummySObjectBundle bundle;
        System.runAs(TEST_ADMIN) {
            bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, DEFAULT_LOOKUP)
                    .setOverrideTemplate(new Contact(LastName = 'Factory Test'))
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(insertMode)
                    .supplyBundle();
        }
        return bundle;
    }

    // in-test providers ---------------------------------------------------

    private class CustomLookup implements XFTY_DummySObjectProviderLookupIntf {
        private final Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf> providers =
                new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>();
        private CustomLookup register(SObjectType type, XFTY_DummySobjectProviderIntf provider) {
            this.providers.put(XFTY_LookupKey.get(type), provider);
            return this;
        }
        public XFTY_DummySobjectProviderIntf get(SObjectType type) {
            return XFTY_ProviderLookups.get(this.providers, XFTY_LookupKey.get(type));
        }
        public XFTY_DummySobjectProviderIntf get(XFTY_LookupKeyIntf key) {
            return XFTY_ProviderLookups.get(this.providers, key);
        }
        public Set<XFTY_LookupKeyIntf> keysFor(SObject sObj) {
            return XFTY_ProviderLookups.keysFor(this.providers.keySet(), sObj);
        }
    }

    private class LeafProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template;
        private LeafProvider(SObjectField idField, SObjectField nameField) {
            this.template = new XFTY_DummySObjectMasterTemplate(idField)
                    .put(nameField, new XFTY_DummyDefaultValueIncrementingString('Leaf'));
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

    private class TwoParentTaskProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Task.Id)
                .put(Task.Subject, new XFTY_DummyDefaultValueIncrementingString('Two Parent Task'))
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

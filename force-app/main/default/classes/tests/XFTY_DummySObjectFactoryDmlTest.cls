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
     * How the engine batches `insert` statements today, measured three ways.
     *
     * Each `factoryOutlet.createBundle(...)` recursion ends in its own
     * `insert insertSObjectList`, so:
     *
     * - records generated in ONE `createBundle` call (siblings, or N copies from
     *   `setQuantityPerTemplate`) share one `insert` - batched;
     * - a parent of a *different* SObjectType is a separate `createBundle`
     *   recursion, so it gets a separate `insert` - NOT batched across the depth.
     *
     * So "Task with an Account parent and a Contact parent" is 3 inserts
     * (Account, Contact, Task), and adding quantity to a single-parent graph does
     * not add inserts. A future depth-batched persistence pass would collapse the
     * cross-type case; this test pins the current numbers so that shows as an
     * intended change.
     */
    @IsTest
    static void howTheEngineBatchesInsertsToday() {
        Integer oneParentType;
        Integer twoParentTypes;
        Integer oneParentTypeQuantityFive;
        System.runAs(TEST_ADMIN) {
            Test.startTest();

            oneParentType = insertsFor(
                    new CustomLookup()
                            .register(Task.SObjectType, new OneParentTaskProvider())
                            .register(Account.SObjectType, new LeafProvider(Account.Id, Account.Name)),
                    1);

            twoParentTypes = insertsFor(
                    new CustomLookup()
                            .register(Task.SObjectType, new TwoParentTaskProvider())
                            .register(Account.SObjectType, new LeafProvider(Account.Id, Account.Name))
                            .register(Contact.SObjectType, new LeafProvider(Contact.Id, Contact.LastName)),
                    1);

            oneParentTypeQuantityFive = insertsFor(
                    new CustomLookup()
                            .register(Task.SObjectType, new OneParentTaskProvider())
                            .register(Account.SObjectType, new LeafProvider(Account.Id, Account.Name)),
                    5);

            Test.stopTest();
        }

        Assert.areEqual(2, oneParentType, 'Account insert + Task insert');
        Assert.areEqual(3, twoParentTypes, 'a second parent SObjectType adds one insert - the recursion is per Provider');
        Assert.areEqual(2, oneParentTypeQuantityFive, 'quantity does not add inserts - the copies share one createBundle');
    }

    private static Integer insertsFor(XFTY_DummySObjectProviderLookupIntf lookup, Integer quantity) {
        Integer before = Limits.getDmlStatements();
        new XFTY_DummySObjectProvider(Task.SObjectType, lookup)
                .setQuantityPerTemplate(quantity)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .supplyList();
        return Limits.getDmlStatements() - before;
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

    private class OneParentTaskProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Task.Id)
                .put(Task.Subject, new XFTY_DummyDefaultValueIncrementingString('One Parent Task'))
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

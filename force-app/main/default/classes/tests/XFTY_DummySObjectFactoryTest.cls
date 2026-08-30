/**
 * Coverage for `XFTY_DummySObjectFactory` - the engine that turns a Master
 * Template into an object graph.
 *
 * The two axes are exercised independently:
 *   - relationship inclusivity: NONE / REQUIRED / ALL / PREVENT_CASCADE
 *   - insert mode:              NEVER / LATER / MOCK / NOW / RELATED_ONLY
 *
 * Inclusivity behaviour that depends on a multi-level graph uses small in-test
 * Providers wired through a custom Provider Lookup, which also demonstrates the
 * "bring your own lookup" extension point.
 */
@IsTest
private class XFTY_DummySObjectFactoryTest {
    private static final XFTY_DefaultSObjectProviderLookup DEFAULT_LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    // ---------------------------------------------------------------------------
    //  Relationship inclusivity
    // ---------------------------------------------------------------------------

    @IsTest
    static void noneGeneratesNoRelatedRecords() {
        XFTY_DummySObjectBundle bundle = supplyContact(
                DEFAULT_LOOKUP, XFTY_InsertInclusivityEnum.NONE, XFTY_InsertModeEnum.MOCK
        );

        Assert.isNull(bundle.getList(Contact.AccountId), 'No Account should be generated');
        Assert.isNull(((Contact) bundle.getList(Contact.Id)[0]).AccountId);
    }

    @IsTest
    static void requiredGeneratesTheRequiredParentAndWiresTheLookup() {
        XFTY_DummySObjectBundle bundle = supplyContact(
                DEFAULT_LOOKUP, XFTY_InsertInclusivityEnum.REQUIRED, XFTY_InsertModeEnum.MOCK
        );

        List<SObject> accounts = bundle.getList(Contact.AccountId);
        Assert.areEqual(1, accounts.size());
        Assert.areEqual(accounts[0].Id, ((Contact) bundle.getList(Contact.Id)[0]).AccountId);
    }

    @IsTest
    static void allGeneratesOptionalRelationshipsThatRequiredSkips() {
        CustomLookup lookup = new CustomLookup()
                .register(Contact.SObjectType, new OptionalParentContactProvider())
                .register(Account.SObjectType, new LeafAccountProvider());

        XFTY_DummySObjectBundle withRequired = supplyContact(
                lookup, XFTY_InsertInclusivityEnum.REQUIRED, XFTY_InsertModeEnum.MOCK
        );
        Assert.isNull(withRequired.getList(Contact.AccountId), 'Optional relationship is skipped for REQUIRED');

        XFTY_DummySObjectBundle withAll = supplyContact(
                lookup, XFTY_InsertInclusivityEnum.ALL, XFTY_InsertModeEnum.MOCK
        );
        Assert.areEqual(1, withAll.getList(Contact.AccountId).size(), 'Optional relationship is generated for ALL');
    }

    @IsTest
    static void preventCascadeGeneratesDirectRelationshipsButStopsRecursing() {
        CustomLookup lookup = new CustomLookup()
                .register(Contact.SObjectType, new DeepContactProvider())
                .register(Account.SObjectType, new DeepAccountProvider())
                .register(User.SObjectType, new XFTY_DefaultUserDataProvider());

        XFTY_DummySObjectBundle cascaded = supplyContact(
                lookup, XFTY_InsertInclusivityEnum.REQUIRED, XFTY_InsertModeEnum.MOCK
        );
        XFTY_DummySObjectBundle accountBundle = cascaded.getBundle(Contact.AccountId);
        Assert.isNotNull(accountBundle.getList(Account.OwnerId), 'REQUIRED recurses into the grandparent User');

        XFTY_DummySObjectBundle stopped = supplyContact(
                lookup, XFTY_InsertInclusivityEnum.PREVENT_CASCADE, XFTY_InsertModeEnum.MOCK
        );
        Assert.areEqual(1, stopped.getList(Contact.AccountId).size(), 'The direct Account is still generated');
        Assert.isNull(
                stopped.getBundle(Contact.AccountId).getList(Account.OwnerId),
                'PREVENT_CASCADE stops the second level from generating its own relationships'
        );
    }

    @IsTest
    static void aRelationshipCanCopyANonIdFieldFromTheGeneratedParent() {
        CustomLookup lookup = new CustomLookup()
                .register(Contact.SObjectType, new RelatedFieldContactProvider())
                .register(Account.SObjectType, new LeafAccountProvider());

        XFTY_DummySObjectBundle bundle;
        System.runAs(TEST_ADMIN) {
            bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.NEVER)
                    .supplyBundle();
        }

        Contact generated = (Contact) bundle.getList(Contact.Id)[0];
        Assert.areEqual('Wired From Parent', generated.Description,
                'Contact.Description should be copied from the parent Account.Name');
    }

    @IsTest
    static void aLookupFieldAlreadySetOnTheChildTemplateIsNotOverwritten() {
        Id presetAccountId = XFTY_IdMocker.generateId(Account.SObjectType);

        XFTY_DummySObjectBundle bundle;
        System.runAs(TEST_ADMIN) {
            bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, DEFAULT_LOOKUP)
                    .setOverrideTemplate(new Contact(LastName = 'Preset', AccountId = presetAccountId))
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.NEVER)
                    .supplyBundle();
        }

        Contact generated = (Contact) bundle.getList(Contact.Id)[0];
        Assert.areEqual(presetAccountId, generated.AccountId, 'the preset lookup value is kept');
        Assert.isNotNull(bundle.getList(Contact.AccountId), 'the Account is still generated into the bundle');
    }

    @IsTest
    static void quantityGeneratesADistinctParentPerRecord() {
        XFTY_DummySObjectBundle bundle;
        System.runAs(TEST_ADMIN) {
            bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, DEFAULT_LOOKUP)
                    .setQuantityPerTemplate(3)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supplyBundle();
        }

        List<SObject> contacts = bundle.getList(Contact.Id);
        List<SObject> accounts = bundle.getList(Contact.AccountId);
        Assert.areEqual(3, contacts.size());
        Assert.areEqual(3, accounts.size());

        Set<Id> accountIds = new Set<Id>();
        for (Integer i = 0; i < 3; i++) {
            accountIds.add(accounts[i].Id);
            Assert.areEqual(accounts[i].Id, ((Contact) contacts[i]).AccountId, 'row ' + i + ' wired to its own parent');
        }
        Assert.areEqual(3, accountIds.size(), 'Each Contact should get a distinct Account');
    }

    // ---------------------------------------------------------------------------
    //  Insert modes
    // ---------------------------------------------------------------------------

    @IsTest
    static void neverLeavesEveryRecordWithoutAnId() {
        XFTY_DummySObjectBundle bundle = supplyContact(
                DEFAULT_LOOKUP, XFTY_InsertInclusivityEnum.REQUIRED, XFTY_InsertModeEnum.NEVER
        );

        Assert.isNull(bundle.getList(Contact.Id)[0].Id);
        Assert.isNull(bundle.getList(Contact.AccountId)[0].Id);
    }

    @IsTest
    static void laterBehavesLikeNever() {
        XFTY_DummySObjectBundle bundle = supplyContact(
                DEFAULT_LOOKUP, XFTY_InsertInclusivityEnum.REQUIRED, XFTY_InsertModeEnum.LATER
        );

        Assert.isNull(bundle.getList(Contact.Id)[0].Id);
        Assert.isNull(bundle.getList(Contact.AccountId)[0].Id);
    }

    @IsTest
    static void mockAssignsIdsWithoutTouchingTheDatabase() {
        XFTY_DummySObjectBundle bundle;
        Integer dmlForGeneration;
        System.runAs(TEST_ADMIN) {
            Integer dmlBefore = Limits.getDmlStatements();
            bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, DEFAULT_LOOKUP)
                    .setOverrideTemplate(new Contact(LastName = 'Factory Test'))
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supplyBundle();
            dmlForGeneration = Limits.getDmlStatements() - dmlBefore;
        }

        Assert.isNotNull(bundle.getList(Contact.Id)[0].Id);
        Assert.isNotNull(bundle.getList(Contact.AccountId)[0].Id);
        Assert.areEqual(0, [SELECT COUNT() FROM Contact]);
        Assert.areEqual(0, [SELECT COUNT() FROM Account]);
        Assert.areEqual(0, dmlForGeneration,
                'MOCK generation must not spend a DML statement - not even an empty insert per level');
    }

    // The DML-backed insert modes (NOW / RELATED_ONLY) live in
    // XFTY_DummySObjectFactoryDmlTest so the unit suite can skip them.

    // ---------------------------------------------------------------------------
    //  Helpers
    // ---------------------------------------------------------------------------

    private static XFTY_DummySObjectBundle supplyContact(
            XFTY_DummySObjectProviderLookupIntf lookup,
            XFTY_InsertInclusivityEnum inclusivity,
            XFTY_InsertModeEnum insertMode
    ) {
        XFTY_DummySObjectBundle bundle;
        System.runAs(TEST_ADMIN) {
            bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
                    .setOverrideTemplate(new Contact(LastName = 'Factory Test'))
                    .setInclusivity(inclusivity)
                    .setInsertMode(insertMode)
                    .supplyBundle();
        }
        return bundle;
    }

    // ---------------------------------------------------------------------------
    //  In-test Providers and Lookup
    // ---------------------------------------------------------------------------

    /** A tiny mutable map builder over {@link XFTY_ProviderLookups} for tests. */
    private class CustomLookup implements XFTY_DummySObjectProviderLookupIntf {
        private final Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf> providers =
                new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>();

        private CustomLookup register(SObjectType type, XFTY_DummySobjectProviderIntf provider) {
            this.providers.put(XFTY_LookupKey.get(type), provider);
            return this;
        }

        public XFTY_DummySobjectProviderIntf get(SObjectType sObjectType) {
            return XFTY_ProviderLookups.get(this.providers, XFTY_LookupKey.get(sObjectType));
        }

        public XFTY_DummySobjectProviderIntf get(XFTY_LookupKeyIntf lookupKey) {
            return XFTY_ProviderLookups.get(this.providers, lookupKey);
        }

        public Set<XFTY_LookupKeyIntf> keysFor(SObject sObj) {
            return XFTY_ProviderLookups.keysFor(this.providers.keySet(), sObj);
        }
    }

    private abstract class BaseProvider implements XFTY_DummySobjectProviderIntf {
        protected XFTY_DummySObjectMasterTemplate template;

        public SObjectField getPrimaryTargetField() {
            return this.template.primaryTargetField;
        }

        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }

        public XFTY_DummySObjectBundle createBundle(
                XFTY_GenerationContext context,
                List<SObject> templateSObjectList
        ) {
            return XFTY_DummySObjectFactory.createBundle(context, this.template, templateSObjectList);
        }
    }

    private class LeafAccountProvider extends BaseProvider {
        private LeafAccountProvider() {
            this.template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                    .put(Account.Name, new XFTY_DummyDefaultValueIncrementingString('Leaf Account'));
        }
    }

    private class OptionalParentContactProvider extends BaseProvider {
        private OptionalParentContactProvider() {
            this.template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                    .put(Contact.LastName, new XFTY_DummyDefaultValueIncrementingString('Optional Parent Contact'))
                    .putOptional(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account()));
        }
    }

    private class DeepAccountProvider extends BaseProvider {
        private DeepAccountProvider() {
            this.template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                    .put(Account.Name, new XFTY_DummyDefaultValueIncrementingString('Deep Account'))
                    .putRequired(Account.OwnerId, new XFTY_DummyDefaultRelationship(new User()));
        }
    }

    private class DeepContactProvider extends BaseProvider {
        private DeepContactProvider() {
            this.template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                    .put(Contact.LastName, new XFTY_DummyDefaultValueIncrementingString('Deep Contact'))
                    .putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account()));
        }
    }

    private class RelatedFieldContactProvider extends BaseProvider {
        private RelatedFieldContactProvider() {
            this.template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                    .put(Contact.LastName, new XFTY_DummyDefaultValueIncrementingString('Related Field Contact'))
                    .putRequired(
                            Contact.Description,
                            new XFTY_DummyDefaultRelationship(new Account(Name = 'Wired From Parent'), Account.Name)
                    );
        }
    }

    private class OptionalOwnerAccountProvider extends BaseProvider {
        private OptionalOwnerAccountProvider() {
            this.template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                    .put(Account.Name, new XFTY_DummyDefaultValueIncrementingString('Opt Owner Account'))
                    .putOptional(Account.OwnerId, new XFTY_DummyDefaultRelationship(new User()));
        }
    }

    // includeOptionalAncestor -----------------------------------------------

    private static CustomLookup optionalChainLookup() {
        return new CustomLookup()
                .register(Contact.SObjectType, new OptionalParentContactProvider())
                .register(Account.SObjectType, new OptionalOwnerAccountProvider())
                .register(User.SObjectType, new XFTY_DefaultUserDataProvider());
    }

    @IsTest
    static void includeOptionalAncestorForcesAOneStepPath() {
        XFTY_DummySObjectBundle bundle;
        System.runAs(TEST_ADMIN) {
            bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, optionalChainLookup())
                    .includeOptionalAncestor(new List<SObjectField>{ Contact.AccountId })
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supplyBundle();
        }

        Assert.areEqual(1, bundle.getList(Contact.AccountId).size(), 'the optional Account is forced');
        Assert.isNull(bundle.getBundle(Contact.AccountId).getList(Account.OwnerId),
                'but not the Account Owner - the path stopped at one step');
    }

    @IsTest
    static void includeOptionalAncestorForcesAMultiStepPath() {
        XFTY_DummySObjectBundle bundle;
        System.runAs(TEST_ADMIN) {
            bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, optionalChainLookup())
                    .includeOptionalAncestor(new List<SObjectField>{ Contact.AccountId, Account.OwnerId })
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supplyBundle();
        }

        Assert.areEqual(1, bundle.getList(Contact.AccountId).size(), 'the optional Account is forced');
        Assert.areEqual(1, bundle.getBundle(Contact.AccountId).getList(Account.OwnerId).size(),
                'and its optional Owner, one step deeper');
    }

    @IsTest
    static void withoutIncludeOptionalAncestorTheChainIsNotGenerated() {
        XFTY_DummySObjectBundle bundle;
        System.runAs(TEST_ADMIN) {
            bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, optionalChainLookup())
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supplyBundle();
        }

        Assert.isNull(bundle.getList(Contact.AccountId), 'optional relationship skipped under REQUIRED');
    }

    @IsTest
    static void includeOptionalAncestorRejectsAStepThatIsNotARelationship() {
        System.runAs(TEST_ADMIN) {
            try {
                new XFTY_DummySObjectProvider(Contact.SObjectType, optionalChainLookup())
                        .includeOptionalAncestor(new List<SObjectField>{ Contact.FirstName })
                        .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                        .setInsertMode(XFTY_InsertModeEnum.MOCK)
                        .supplyBundle();
                Assert.fail('Expected an exception');
            } catch (XFTY_DummySObjectFtyProviderException ex) {
                Assert.isTrue(ex.getMessage().contains('not a relationship'), ex.getMessage());
            }
        }
    }

    @IsTest
    static void includeOptionalAncestorRejectsAnEmptyPath() {
        try {
            new XFTY_DummySObjectProvider(Contact.SObjectType, DEFAULT_LOOKUP)
                    .includeOptionalAncestor(new List<SObjectField>());
            Assert.fail('Expected a SanityException');
        } catch (XFTY_DummySObjectProvider.SanityException ex) {
            Assert.isTrue(ex.getMessage().contains('at least one relationship field'), ex.getMessage());
        }
    }

    @IsTest
    static void includeOptionalAncestorRejectsANullPath() {
        try {
            new XFTY_DummySObjectProvider(Contact.SObjectType, DEFAULT_LOOKUP)
                    .includeOptionalAncestor(null);
            Assert.fail('Expected a SanityException');
        } catch (XFTY_DummySObjectProvider.SanityException ex) {
            Assert.isTrue(ex.getMessage().contains('at least one relationship field'), ex.getMessage());
        }
    }

    @IsTest
    static void includeOptionalAncestorRejectsANullStep() {
        try {
            new XFTY_DummySObjectProvider(Contact.SObjectType, DEFAULT_LOOKUP)
                    .includeOptionalAncestor(new List<SObjectField>{ Contact.AccountId, null });
            Assert.fail('Expected a SanityException');
        } catch (XFTY_DummySObjectProvider.SanityException ex) {
            Assert.isTrue(ex.getMessage().contains('cannot be null'), ex.getMessage());
        }
    }
}

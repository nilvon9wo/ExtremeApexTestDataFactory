/**
 * Proves `XFTY_DummySObjectFactory` - the engine that turns a Master Template
 * into an object graph - along its two axes:
 *   - relationship inclusivity: NONE / REQUIRED / ALL / PREVENT_CASCADE
 *   - insert mode:              NEVER / LATER / MOCK
 *
 * MOCK / NEVER mode throughout - no DML, so no `System.runAs` (the one test that
 * queries record counts is the exception). The DML-backed modes (NOW /
 * RELATED_ONLY) live in `XFTY_DummySObjectFactoryDmlTest`.
 */
@IsTest
private class XFTY_DummySObjectFactoryTest {

    private static final XFTY_DefaultSObjectProviderLookup DEFAULT_LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    private static XFTY_DummySObjectProviderLookupIntf lookupOf(
            Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf> providers
    ) {
        return XFTY_ProviderLookups.of(providers);
    }

    private static XFTY_DummySObjectProviderLookupIntf optionalChainLookup() {
        return lookupOf(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Contact.SObjectType) => new OptionalParentContactProvider(),
                XFTY_LookupKey.get(Account.SObjectType) => new OptionalOwnerAccountProvider(),
                XFTY_LookupKey.get(User.SObjectType) => new XFTY_DefaultUserDataProvider()
        });
    }

    // Relationship inclusivity ------------------------------------

    @IsTest
    static void testSupplyBundle_atNoneInclusivity_generatesNoRelatedRecords() {
        // Arrange
        XFTY_DummySObjectProvider provider = contactProvider(DEFAULT_LOOKUP)
                .setInclusivity(XFTY_InsertInclusivityEnum.NONE)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Assert.isNull(bundle.getList(Contact.AccountId), 'no Account is generated');
        Assert.isNull(((Contact) bundle.getList(Contact.Id)[0]).AccountId);
    }

    @IsTest
    static void testSupplyBundle_atRequiredInclusivity_generatesTheRequiredParentAndWiresTheLookup() {
        // Arrange
        XFTY_DummySObjectProvider provider = contactProvider(DEFAULT_LOOKUP)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        List<SObject> accounts = bundle.getList(Contact.AccountId);
        Assert.areEqual(1, accounts.size());
        Assert.areEqual(accounts[0].Id, ((Contact) bundle.getList(Contact.Id)[0]).AccountId);
    }

    @IsTest
    static void testSupplyBundle_atRequiredInclusivity_skipsAnOptionalRelationship() {
        // Arrange
        XFTY_DummySObjectProvider provider = optionalParentContactProvider(XFTY_InsertInclusivityEnum.REQUIRED);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Assert.isNull(bundle.getList(Contact.AccountId), 'an optional relationship is skipped for REQUIRED');
    }

    @IsTest
    static void testSupplyBundle_atAllInclusivity_generatesAnOptionalRelationship() {
        // Arrange
        XFTY_DummySObjectProvider provider = optionalParentContactProvider(XFTY_InsertInclusivityEnum.ALL);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Assert.areEqual(1, bundle.getList(Contact.AccountId).size(), 'an optional relationship is generated for ALL');
    }

    @IsTest
    static void testSupplyBundle_atRequiredInclusivity_recursesIntoTheGrandparent() {
        // Arrange
        XFTY_DummySObjectProvider provider = contactProvider(deepChainLookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Assert.isNotNull(bundle.getBundle(Contact.AccountId).getList(Account.OwnerId),
                'REQUIRED recurses into the grandparent User');
    }

    @IsTest
    static void testSupplyBundle_atPreventCascadeInclusivity_generatesDirectRelationshipsButStopsRecursing() {
        // Arrange
        XFTY_DummySObjectProvider provider = contactProvider(deepChainLookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.PREVENT_CASCADE)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Assert.areEqual(1, bundle.getList(Contact.AccountId).size(), 'the direct Account is still generated');
        Assert.isNull(bundle.getBundle(Contact.AccountId).getList(Account.OwnerId),
                'PREVENT_CASCADE stops the second level generating its own relationships');
    }

    @IsTest
    static void testSupplyBundle_whenARelationshipCopiesANonIdField_wiresItFromTheGeneratedParent() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(
                Contact.SObjectType,
                lookupOf(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                        XFTY_LookupKey.get(Contact.SObjectType) => new RelatedFieldContactProvider(),
                        XFTY_LookupKey.get(Account.SObjectType) => new LeafAccountProvider()
                })
        )
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NEVER);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Assert.areEqual('Wired From Parent', ((Contact) bundle.getList(Contact.Id)[0]).Description,
                'Contact.Description is copied from the parent Account.Name');
    }

    @IsTest
    static void testSupplyBundle_whenALookupFieldIsAlreadySetOnTheChildTemplate_doesNotOverwriteIt() {
        // Arrange
        Id presetAccountId = XFTY_IdMocker.generateId(Account.SObjectType);
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, DEFAULT_LOOKUP)
                .setOverrideTemplate(new Contact(LastName = 'Preset', AccountId = presetAccountId))
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NEVER);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Assert.areEqual(presetAccountId, ((Contact) bundle.getList(Contact.Id)[0]).AccountId, 'the preset lookup value is kept');
        Assert.isNotNull(bundle.getList(Contact.AccountId), 'the Account is still generated into the bundle');
    }

    @IsTest
    static void testSupplyBundle_withQuantity_generatesADistinctParentPerRecordEachWired() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, DEFAULT_LOOKUP)
                .setQuantityPerTemplate(3)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        List<SObject> contacts = bundle.getList(Contact.Id);
        List<SObject> accounts = bundle.getList(Contact.AccountId);
        Assert.areEqual(3, contacts.size());
        Assert.areEqual(3, accounts.size());
        Set<Id> accountIds = new Set<Id>();
        for (Integer i = 0; i < 3; i++) {
            accountIds.add(accounts[i].Id);
            Assert.areEqual(accounts[i].Id, ((Contact) contacts[i]).AccountId, 'row ' + i + ' wired to its own parent');
        }
        Assert.areEqual(3, accountIds.size(), 'each Contact gets a distinct Account');
    }

    // Insert modes ---------------------------------------------

    @IsTest
    static void testSupplyBundle_inNeverMode_leavesEveryRecordWithoutAnId() {
        assertNoIdsGenerated(XFTY_InsertModeEnum.NEVER);
    }

    @IsTest
    static void testSupplyBundle_inLaterMode_leavesEveryRecordWithoutAnId() {
        assertNoIdsGenerated(XFTY_InsertModeEnum.LATER);
    }

    @IsTest
    static void testSupplyBundle_inMockMode_assignsIdsToEveryRecord() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, DEFAULT_LOOKUP)
                .setOverrideTemplate(new Contact(LastName = 'Factory Test'))
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Assert.isNotNull(bundle.getList(Contact.Id)[0].Id);
        Assert.isNotNull(bundle.getList(Contact.AccountId)[0].Id);
    }

    @IsTest
    static void testSupplyBundle_inMockMode_spendsNoDmlAndTouchesNoRecords() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, DEFAULT_LOOKUP)
                .setOverrideTemplate(new Contact(LastName = 'Factory Test'))
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Integer dmlForGeneration;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            Integer dmlBefore = Limits.getDmlStatements();
            provider.supplyBundle();
            dmlForGeneration = Limits.getDmlStatements() - dmlBefore;
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(0, dmlForGeneration, 'MOCK generation spends no DML - not even an empty insert per level');
        Assert.areEqual(0, [SELECT COUNT() FROM Contact]);
        Assert.areEqual(0, [SELECT COUNT() FROM Account]);
    }

    // includeOptional ----------------------------------------

    @IsTest
    static void testIncludeOptional_forAOneStepPath_forcesThatOptionalRelationshipButNoDeeper() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, optionalChainLookup())
                .includeOptional(new List<SObjectField>{ Contact.AccountId })
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Assert.areEqual(1, bundle.getList(Contact.AccountId).size(), 'the optional Account is forced');
        Assert.isNull(bundle.getBundle(Contact.AccountId).getList(Account.OwnerId),
                'but not the Account Owner - the path stopped at one step');
    }

    @IsTest
    static void testIncludeOptional_forAMultiStepPath_forcesEveryStep() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, optionalChainLookup())
                .includeOptional(new List<SObjectField>{ Contact.AccountId, Account.OwnerId })
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Assert.areEqual(1, bundle.getList(Contact.AccountId).size(), 'the optional Account is forced');
        Assert.areEqual(1, bundle.getBundle(Contact.AccountId).getList(Account.OwnerId).size(),
                'and its optional Owner, one step deeper');
    }

    @IsTest
    static void testSupplyBundle_withoutIncludeOptional_leavesTheOptionalChainUngenerated() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, optionalChainLookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Assert.isNull(bundle.getList(Contact.AccountId), 'optional relationship skipped under REQUIRED');
    }

    @IsTest
    static void testIncludeOptional_whenAStepIsNotARelationship_throws() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, optionalChainLookup())
                .includeOptional(new List<SObjectField>{ Contact.FirstName })
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            provider.supplyBundle();
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('not a relationship'), thrown.getMessage());
    }

    @IsTest
    static void testIncludeOptional_whenGivenAnEmptyPath_throws() {
        assertIncludeOptionalRejects(new List<SObjectField>(), 'at least one relationship field');
    }

    @IsTest
    static void testIncludeOptional_whenGivenANullPath_throws() {
        assertIncludeOptionalRejects(null, 'at least one relationship field');
    }

    @IsTest
    static void testIncludeOptional_whenGivenANullStep_throws() {
        assertIncludeOptionalRejects(new List<SObjectField>{ Contact.AccountId, null }, 'cannot be null');
    }

    // Runners + helpers -------------------------------------

    private static XFTY_DummySObjectProvider contactProvider(XFTY_DummySObjectProviderLookupIntf lookup) {
        return new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
                .setOverrideTemplate(new Contact(LastName = 'Factory Test'));
    }

    private static XFTY_DummySObjectProviderLookupIntf deepChainLookup() {
        return lookupOf(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Contact.SObjectType) => new DeepContactProvider(),
                XFTY_LookupKey.get(Account.SObjectType) => new DeepAccountProvider(),
                XFTY_LookupKey.get(User.SObjectType) => new XFTY_DefaultUserDataProvider()
        });
    }

    private static XFTY_DummySObjectProvider optionalParentContactProvider(XFTY_InsertInclusivityEnum inclusivity) {
        return contactProvider(
                lookupOf(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                        XFTY_LookupKey.get(Contact.SObjectType) => new OptionalParentContactProvider(),
                        XFTY_LookupKey.get(Account.SObjectType) => new LeafAccountProvider()
                })
        )
                .setInclusivity(inclusivity)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);
    }

    static void assertNoIdsGenerated(XFTY_InsertModeEnum insertMode) {
        // Arrange
        XFTY_DummySObjectProvider provider = contactProvider(DEFAULT_LOOKUP)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(insertMode);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Assert.isNull(bundle.getList(Contact.Id)[0].Id);
        Assert.isNull(bundle.getList(Contact.AccountId)[0].Id);
    }

    static void assertIncludeOptionalRejects(List<SObjectField> path, String expectedMessagePart) {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, DEFAULT_LOOKUP);

        // Act
        XFTY_DummySObjectProvider.SanityException thrown;
        Test.startTest();
        try {
            provider.includeOptional(path);
        } catch (XFTY_DummySObjectProvider.SanityException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains(expectedMessagePart), thrown.getMessage());
    }

    // In-test Providers ------------------------------------

    private abstract class BaseProvider implements XFTY_DummySobjectProviderIntf {
        protected XFTY_DummySObjectMasterTemplate template;

        public SObjectField getPrimaryTargetField() {
            return this.template.primaryTargetField;
        }
        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }
        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext context, List<SObject> templateSObjectList) {
            return XFTY_DummySObjectFactory.createBundle(context, this.template, templateSObjectList);
        }
    }

    private class LeafAccountProvider extends BaseProvider {
        private LeafAccountProvider() {
            this.template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                    .put(Account.Name, new XFTY_IncrementingStringExpression('Leaf Account'));
        }
    }

    private class OptionalParentContactProvider extends BaseProvider {
        private OptionalParentContactProvider() {
            this.template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                    .put(Contact.LastName, new XFTY_IncrementingStringExpression('Optional Parent Contact'))
                    .putOptional(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account()));
        }
    }

    private class DeepAccountProvider extends BaseProvider {
        private DeepAccountProvider() {
            this.template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                    .put(Account.Name, new XFTY_IncrementingStringExpression('Deep Account'))
                    .putRequired(Account.OwnerId, new XFTY_DummyDefaultRelationship(new User()));
        }
    }

    private class DeepContactProvider extends BaseProvider {
        private DeepContactProvider() {
            this.template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                    .put(Contact.LastName, new XFTY_IncrementingStringExpression('Deep Contact'))
                    .putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account()));
        }
    }

    private class RelatedFieldContactProvider extends BaseProvider {
        private RelatedFieldContactProvider() {
            this.template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                    .put(Contact.LastName, new XFTY_IncrementingStringExpression('Related Field Contact'))
                    .putRequired(
                            Contact.Description,
                            new XFTY_DummyDefaultRelationship(new Account(Name = 'Wired From Parent'), Account.Name)
                    );
        }
    }

    private class OptionalOwnerAccountProvider extends BaseProvider {
        private OptionalOwnerAccountProvider() {
            this.template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                    .put(Account.Name, new XFTY_IncrementingStringExpression('Opt Owner Account'))
                    .putOptional(Account.OwnerId, new XFTY_DummyDefaultRelationship(new User()));
        }
    }
}

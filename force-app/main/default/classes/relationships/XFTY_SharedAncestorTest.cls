/**
 * Coverage for `XFTY_SharedAncestor` - one generated record shared by every
 * child, `put(...)` / `putAsTemplate` / `putAsValue` / `putIfAbsent` / `getId(...)`,
 * the configuration guards, `fromVariant` / `copyingRelatedField`, and cycle
 * detection. Deep chains and the
 * batched pre-phase are in `XFTY_SharedAncestorHierarchyTest`.
 *
 * See docs/use/shared-ancestors.md.
 */
@IsTest
private class XFTY_SharedAncestorTest {

    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    @IsTest
    static void testSupplyList_whenFiftyChildrenShareOneSharedAncestor_insertsTheAccountOnce() {
        // Arrange
        XFTY_SharedAncestor.put('acme-hq', new Account(Name = 'ACME HQ'));

        // Act
        List<Contact> contacts;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            contacts = (List<Contact>) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('acme-hq'))
                    .setQuantityPerTemplate(50)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .supplyList();
            Test.stopTest();
        }

        // Assert - 50 Contacts, ONE generated Account, ONE Account insert
        Assert.areEqual(50, contacts.size());
        Assert.areEqual(1, [SELECT COUNT() FROM Account]);
    }

    @IsTest
    static void testSupplyBundle_whenManyChildrenShareASharedAncestor_theyAllPointAtOneParent() {
        // Arrange
        XFTY_SharedAncestor.put('hq', new Account(Name = 'Shared HQ'));

        // Act
        XFTY_DummySObjectBundle bundle;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('hq'))
                    .setQuantityPerTemplate(5)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supplyBundle();
            Test.stopTest();
        }

        // Assert
        List<SObject> contacts = bundle.getList(Contact.Id);
        Assert.areEqual(5, contacts.size());
        Assert.areEqual(5, bundle.getList(Contact.AccountId).size());
        Set<Id> accountIds = new Set<Id>();
        for (SObject contactRecord : contacts) {
            accountIds.add((Id) contactRecord.get(Contact.AccountId));
        }
        Assert.areEqual(1, accountIds.size(), 'every Contact points at the one shared Account');
        Assert.areEqual(bundle.getList(Contact.AccountId)[0].Id, accountIds.iterator().next());
    }

    @IsTest
    static void testSupplyList_inNowMode_insertsTheSharedParentExactlyOnce() {
        // Arrange
        XFTY_SharedAncestor.put('hq', new Account(Name = 'Shared HQ'));

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('hq'))
                    .setQuantityPerTemplate(4)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .supplyList();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(1, [SELECT COUNT() FROM Account], 'one shared Account inserted');
        Assert.areEqual(4, [SELECT COUNT() FROM Contact]);
        Assert.areEqual(1, [SELECT COUNT(Id) FROM Contact GROUP BY AccountId].size(),
                'all four Contacts on the same Account');
    }

    @IsTest
    static void testSupplyBundle_exposesTheSharedRecordInBothTheListAndTheSubBundle() {
        // Arrange
        XFTY_SharedAncestor.put('hq', new Account(Name = 'Shared HQ'));

        // Act
        XFTY_DummySObjectBundle bundle;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('hq'))
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supplyBundle();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual('Shared HQ', bundle.getList(Contact.AccountId)[0].get(Account.Name));
        Assert.isNotNull(bundle.getBundle(Contact.AccountId), 'the shared ancestor has a sub-bundle');
        Assert.areEqual('Shared HQ',
                bundle.getBundle(Contact.AccountId).getList(Account.Id)[0].get(Account.Name));
    }

    @IsTest
    static void testSupply_whenAMockResolvedSharedAncestorIsReferencedFromANowCall_throws() {
        // Arrange - resolve 'hq' in MOCK mode first, so it has a mock (not real) Id
        XFTY_SharedAncestor.put('hq', new Account(Name = 'Shared HQ'));
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('hq'))
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supply();

            // Act - a NOW call that would carry the mock Id onto inserted Contacts
            XFTY_DummySObjectFtyProviderException thrown;
            try {
                new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                        .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('hq'))
                        .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                        .setInsertMode(XFTY_InsertModeEnum.NOW)
                        .supply();
            } catch (XFTY_DummySObjectFtyProviderException ex) {
                thrown = ex;
            }
            Test.stopTest();

            // Assert
            Assert.isNotNull(thrown, 'a MOCK-then-NOW mix must throw, not drift a mock Id into real DML');
            Assert.isTrue(thrown.getMessage().contains('consistent insert mode'), thrown.getMessage());
        }
    }

    @IsTest
    static void testSupplyList_whenTheSharedAncestorIsAPreInsertedRecord_acceptsNowReferences() {
        // Arrange - the test inserts its own HQ and registers it
        Account inserted = new Account(Name = 'Real HQ');
        System.runAs(TEST_ADMIN) {
            insert inserted;
        }
        XFTY_SharedAncestor.put('hq', inserted);

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('hq'))
                    .setQuantityPerTemplate(3)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .supplyList();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(3, [SELECT COUNT() FROM Contact WHERE AccountId = :inserted.Id]);
    }

    @IsTest
    static void testGetBundle_forAPutSharedAncestor_returnsIt() {
        // Arrange
        XFTY_SharedAncestor.put('hq', new Account(Name = 'Supplied HQ'));

        // Act
        XFTY_DummySObjectBundle bundle;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('hq'))
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supplyBundle();
            Test.stopTest();
        }

        // Assert
        Assert.isNotNull(bundle.getBundle(Contact.AccountId),
                'getBundle is populated even for a put(...) record');
        Assert.areEqual('Supplied HQ',
                bundle.getBundle(Contact.AccountId).getList(Account.Id)[0].get(Account.Name));
        Assert.areEqual(
                bundle.getList(Contact.AccountId)[0],
                bundle.getBundle(Contact.AccountId).getList(Account.Id)[0],
                'getList and getBundle expose the same shared instance');
    }

    @IsTest
    static void testSupply_reusesTheSameSharedAncestorAcrossSeparateSupplyCalls() {
        // Arrange
        XFTY_SharedAncestor.put('hq', new Account(Name = 'Shared HQ'));

        // Act - two independent supply calls
        Contact fromFirstCall;
        Contact fromSecondCall;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            fromFirstCall = supplyOneContactUnderHq();
            fromSecondCall = supplyOneContactUnderHq();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(fromFirstCall.AccountId, fromSecondCall.AccountId,
                'the shared record survives between supply() calls');
    }

    @IsTest
    static void testGetId_afterResolution_returnsTheResolvedRecordsId() {
        // Arrange
        XFTY_SharedAncestor.put('hq', new Account(Name = 'Shared HQ'));

        // Act
        Contact result;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = supplyOneContactUnderHq();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(result.AccountId, XFTY_SharedAncestor.getId('hq'));
    }

    @IsTest
    static void testGetId_beforeResolution_throws() {
        // Arrange
        XFTY_SharedAncestor.put('hq', new Account(Name = 'x'));

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        try {
            XFTY_SharedAncestor.getId('hq');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }

        // Assert
        Assert.isNotNull(thrown, 'getId before resolution must throw');
        Assert.isTrue(thrown.getMessage().contains('not resolved yet'), thrown.getMessage());
    }

    @IsTest
    static void testPut_registersATestSuppliedRecord() {
        // Arrange
        Account preMade = new Account(Name = 'Pre Made', Id = XFTY_IdMocker.generateId(Account.SObjectType));
        XFTY_SharedAncestor.put('hq', preMade);

        // Act
        Contact result;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = supplyOneContactUnderHq();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(preMade.Id, result.AccountId, 'the pre-made record is used, nothing generated');
        Assert.areEqual(0, [SELECT COUNT() FROM Account]);
    }

    @IsTest
    static void testSupply_whenCopyingRelatedField_copiesThatFieldInsteadOfTheId() {
        // Arrange
        XFTY_SharedAncestor.put('hq', new Account(Name = 'Named HQ'))
                .copyingRelatedField(Account.Name);

        // Act
        Contact result;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .putRequired(Contact.Description, XFTY_SharedAncestor.get('hq'))
                    .removeFromMasterTemplate(Contact.AccountId)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supply();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual('Named HQ', result.Description);
    }

    @IsTest
    static void testSupply_whenFromVariantIsUsed_pinsTheProviderVariant() {
        // Arrange
        XFTY_SharedAncestor.put('acct', new Account())
                .fromVariant(XFTY_LookupKey.get(Account.SObjectType));

        // Act
        Contact result;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('acct'))
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supply();
            Test.stopTest();
        }

        // Assert
        Assert.isNotNull(result.AccountId);
    }

    @IsTest
    static void testGetNameAndGetTemplate_exposeWhatTheSharedAncestorWasConfiguredWith() {
        // Arrange
        // nothing to arrange - configuration is the act

        // Act
        XFTY_SharedAncestor.put('hq', new Account(Name = 'Configured')).copyingRelatedField(Account.Name);

        // Assert
        XFTY_SharedAncestor ancestor = XFTY_SharedAncestor.get('hq');
        Assert.areEqual('hq', ancestor.getSharedName());
        Assert.areEqual('Configured', (String) ancestor.getOverrideTemplate().get(Account.Name));
        Assert.areEqual(Account.Name, ancestor.getRelatedField());
    }

    // Guards ---------------------------------------------------------------

    @IsTest
    static void testGet_whenTheNameIsBlank_throws() {
        // Arrange
        // nothing to arrange - the blank name is the act

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        try {
            XFTY_SharedAncestor.get('   ');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }

        // Assert
        Assert.isNotNull(thrown, 'a blank name must be rejected');
        Assert.isTrue(thrown.getMessage().contains('non-blank name'), thrown.getMessage());
    }

    @IsTest
    static void testSupply_whenASharedAncestorIsUnregistered_throws() {
        // Arrange
        // nothing to arrange - 'never-registered' is referenced but never given a template

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        System.runAs(TEST_ADMIN) {
            try {
                new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                        .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('never-registered'))
                        .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                        .setInsertMode(XFTY_InsertModeEnum.MOCK)
                        .supply();
            } catch (XFTY_DummySObjectFtyProviderException ex) {
                thrown = ex;
            }
        }

        // Assert
        Assert.isNotNull(thrown, 'an unregistered shared ancestor must throw when generation reaches it');
        Assert.isTrue(thrown.getMessage().contains('never registered'), thrown.getMessage());
    }

    @IsTest
    static void testSupply_whenDepthBatched_resolvesTheSharedAncestorUpFront() {
        // Arrange
        XFTY_SharedAncestor.put('hq', new Account(Name = 'Shared HQ'));

        // Act
        Contact result;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('hq'))
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .depthBatched()
                    .supply();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(1, [SELECT COUNT() FROM Account], 'the shared ancestor was resolved once, up front');
        Assert.areEqual(XFTY_SharedAncestor.getId('hq'), result.AccountId);
    }

    @IsTest
    static void testPut_whenReconfiguringAnAlreadyResolvedSharedAncestor_throws() {
        // Arrange - resolve 'hq', then try to reconfigure it
        XFTY_SharedAncestor.put('hq', new Account(Name = 'First'));
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            supplyOneContactUnderHq();
            Test.stopTest();
        }

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        try {
            XFTY_SharedAncestor.put('hq', new Account(Name = 'Second'));
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }

        // Assert
        Assert.isNotNull(thrown, 'reconfiguring a resolved shared ancestor must throw');
        Assert.isTrue(thrown.getMessage().contains('already resolved'), thrown.getMessage());
    }

    @IsTest
    static void testSupply_whenASharedAncestorIsSelfReferential_throwsInsteadOfRecursing() {
        // Arrange - the 'loop' Account's own ParentId is the 'loop' shared ancestor
        XFTY_SharedAncestor.put('loop', new Account(Name = 'Loop'));
        XFTY_DummySObjectProviderLookupIntf loopy = XFTY_ProviderLookups.of(
                new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                        XFTY_LookupKey.get(Account.SObjectType) => new SelfReferencingAccountProvider(),
                        XFTY_LookupKey.get(Contact.SObjectType) => new XFTY_DefaultContactDataProvider()
                }
        );

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        System.runAs(TEST_ADMIN) {
            try {
                new XFTY_DummySObjectProvider(Contact.SObjectType, loopy)
                        .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('loop'))
                        .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                        .setInsertMode(XFTY_InsertModeEnum.MOCK)
                        .supply();
            } catch (XFTY_DummySObjectFtyProviderException ex) {
                thrown = ex;
            }
        }

        // Assert
        Assert.isNotNull(thrown, 'a self-referential shared ancestor must throw, not stack-overflow');
        Assert.isTrue(thrown.getMessage().containsIgnoreCase('cycle'), thrown.getMessage());
    }

    @IsTest
    static void testSupply_whenThreeSharedAncestorsFormAnIndirectCycle_throws() {
        // Arrange - tom -> dick -> harry -> tom
        XFTY_LookupKeyIntf tomKey = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'tom');
        XFTY_LookupKeyIntf dickKey = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'dick');
        XFTY_LookupKeyIntf harryKey = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'harry');
        XFTY_SharedAncestor.put('tom', new Account(Name = 'Tom')).fromVariant(tomKey);
        XFTY_SharedAncestor.put('dick', new Account(Name = 'Dick')).fromVariant(dickKey);
        XFTY_SharedAncestor.put('harry', new Account(Name = 'Harry')).fromVariant(harryKey);
        XFTY_DummySObjectProviderLookupIntf ring = XFTY_ProviderLookups.of(
                new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                        tomKey => new ParentedAccountProvider('dick'),
                        dickKey => new ParentedAccountProvider('harry'),
                        harryKey => new ParentedAccountProvider('tom'),
                        XFTY_LookupKey.get(Contact.SObjectType) => new XFTY_DefaultContactDataProvider()
                }
        );

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        System.runAs(TEST_ADMIN) {
            try {
                new XFTY_DummySObjectProvider(Contact.SObjectType, ring)
                        .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('tom'))
                        .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                        .setInsertMode(XFTY_InsertModeEnum.MOCK)
                        .supply();
            } catch (XFTY_DummySObjectFtyProviderException ex) {
                thrown = ex;
            }
        }

        // Assert
        Assert.isNotNull(thrown, 'a three-way shared-ancestor cycle must throw');
        Assert.isTrue(thrown.getMessage().containsIgnoreCase('cycle'), thrown.getMessage());
    }

    @IsTest
    static void testPut_overAResolvedSharedAncestorWithADifferentRecord_warnsButSucceeds() {
        // Arrange - resolve 'hq', then put a different record over it
        XFTY_SharedAncestor.put('hq', new Account(Name = 'Generated'));
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            supplyOneContactUnderHq();
            Test.stopTest();
        }
        Account replacement = new Account(Name = 'Replacement', Id = XFTY_IdMocker.generateId(Account.SObjectType));

        // Act
        XFTY_SharedAncestor.put('hq', replacement);   // logs a WARN, does not throw

        // Assert
        Assert.areEqual(replacement.Id, XFTY_SharedAncestor.getId('hq'));
    }

    // Fixture ------------------------------------------------------------

    private static Contact supplyOneContactUnderHq() {
        return (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('hq'))
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
    }

    private class SelfReferencingAccountProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                .put(Account.Name, new XFTY_IncrementingStringExpression('Loop'))
                .putRequired(Account.ParentId, XFTY_SharedAncestor.get('loop'));

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

    /** An Account Provider whose `ParentId` is the named shared ancestor - for the cycle tests. */
    private class ParentedAccountProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template;

        private ParentedAccountProvider(String parentSharedName) {
            this.template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                    .put(Account.Name, new XFTY_IncrementingStringExpression('Ring'))
                    .putRequired(Account.ParentId, XFTY_SharedAncestor.get(parentSharedName));
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

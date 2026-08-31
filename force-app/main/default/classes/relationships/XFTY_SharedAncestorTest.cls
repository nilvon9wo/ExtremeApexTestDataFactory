/**
 * Coverage for `XFTY_SharedAncestor` - the on-demand shared-ancestor path:
 * one generated record shared by every child, `put(...)` / `getId(...)`, the
 * configuration guards, and `withKey` / `copyingRelatedField`.
 *
 * See docs/roadmap/shared-ancestors.md.
 */
@IsTest
private class XFTY_SharedAncestorTest {
    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    @IsTest
    static void manyChildrenShareOneGeneratedParent() {
        XFTY_SharedAncestor.get('hq').of(new Account(Name = 'Shared HQ'));

        List<SObject> contacts;
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
        contacts = bundle.getList(Contact.Id);

        Assert.areEqual(5, contacts.size());
        Assert.areEqual(5, bundle.getList(Contact.AccountId).size());
        Set<Id> accountIds = new Set<Id>();
        for (SObject c : contacts) {
            accountIds.add((Id) c.get(Contact.AccountId));
        }
        Assert.areEqual(1, accountIds.size(), 'every Contact points at the one shared Account');
        Assert.areEqual(
                bundle.getList(Contact.AccountId)[0].Id,
                accountIds.iterator().next()
        );
    }

    @IsTest
    static void nowModeInsertsTheSharedParentOnce() {
        XFTY_SharedAncestor.get('hq').of(new Account(Name = 'Shared HQ'));

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

        Assert.areEqual(1, [SELECT COUNT() FROM Account], 'one shared Account inserted');
        Assert.areEqual(4, [SELECT COUNT() FROM Contact]);
        Assert.areEqual(1, [SELECT COUNT(Id) FROM Contact GROUP BY AccountId].size(),
                'all four Contacts on the same Account');
    }

    @IsTest
    static void theSharedRecordAppearsInBothTheListAndTheSubBundle() {
        XFTY_SharedAncestor.get('hq').of(new Account(Name = 'Shared HQ'));

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

        Assert.areEqual('Shared HQ', bundle.getList(Contact.AccountId)[0].get(Account.Name));
        Assert.isNotNull(bundle.getBundle(Contact.AccountId), 'the shared ancestor has a sub-bundle');
        Assert.areEqual('Shared HQ',
                bundle.getBundle(Contact.AccountId).getList(Account.Id)[0].get(Account.Name));
    }

    @IsTest
    static void referencingAMockResolvedSharedAncestorFromANowCallThrows() {
        XFTY_SharedAncestor.get('hq').of(new Account(Name = 'Shared HQ'));

        System.runAs(TEST_ADMIN) {
            Test.startTest();
            // first: resolve it in MOCK mode -> mock Id, not persisted
            new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('hq'))
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supply();
            // then: a NOW call that would carry that mock Id onto inserted Contacts
            try {
                new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                        .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('hq'))
                        .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                        .setInsertMode(XFTY_InsertModeEnum.NOW)
                        .supply();
                Assert.fail('Expected an exception');
            } catch (XFTY_DummySObjectFtyProviderException ex) {
                Assert.isTrue(ex.getMessage().contains('consistent insert mode'), ex.getMessage());
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void putAnInsertedRecordAndItAcceptsNowReferences() {
        Account inserted = new Account(Name = 'Real HQ');
        System.runAs(TEST_ADMIN) {
            insert inserted;
        }
        XFTY_SharedAncestor.put('hq', inserted);

        List<SObject> contacts;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            contacts = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('hq'))
                    .setQuantityPerTemplate(3)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .supplyList();
            Test.stopTest();
        }

        Assert.areEqual(3, [SELECT COUNT() FROM Contact WHERE AccountId = :inserted.Id]);
    }

    @IsTest
    static void aPutRecordIsAvailableThroughGetBundleNotJustGetList() {
        XFTY_SharedAncestor.put('hq', new Account(Name = 'Supplied HQ'));

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
    static void theSameSharedAncestorIsReusedAcrossSeparateSupplyCalls() {
        XFTY_SharedAncestor.get('hq').of(new Account(Name = 'Shared HQ'));

        Id firstRunAccountId;
        Id secondRunAccountId;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            firstRunAccountId = (Id) ((Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('hq'))
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supply()).AccountId;
            secondRunAccountId = (Id) ((Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('hq'))
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supply()).AccountId;
            Test.stopTest();
        }

        Assert.areEqual(firstRunAccountId, secondRunAccountId, 'the shared record survives between supply() calls');
    }

    @IsTest
    static void getIdReturnsTheResolvedRecordsId() {
        XFTY_SharedAncestor.get('hq').of(new Account(Name = 'Shared HQ'));

        Contact result;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('hq'))
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supply();
            Test.stopTest();
        }

        Assert.areEqual(result.AccountId, XFTY_SharedAncestor.getId('hq'));
    }

    @IsTest
    static void getIdBeforeResolutionThrows() {
        XFTY_SharedAncestor.get('hq').of(new Account(Name = 'x'));
        try {
            XFTY_SharedAncestor.getId('hq');
            Assert.fail('Expected an exception');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            Assert.isTrue(ex.getMessage().contains('not resolved yet'), ex.getMessage());
        }
    }

    @IsTest
    static void putRegistersATestSuppliedRecord() {
        Account preMade = new Account(Name = 'Pre Made');
        preMade.Id = XFTY_IdMocker.generateId(Account.SObjectType);
        XFTY_SharedAncestor.put('hq', preMade);

        Contact result;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('hq'))
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supply();
            Test.stopTest();
        }

        Assert.areEqual(preMade.Id, result.AccountId, 'the pre-made record is used, nothing generated');
        Assert.areEqual(0, [SELECT COUNT() FROM Account]);
    }

    @IsTest
    static void copyingRelatedFieldCopiesThatFieldInsteadOfTheId() {
        XFTY_SharedAncestor.get('hq')
                .of(new Account(Name = 'Named HQ'))
                .copyingRelatedField(Account.Name);

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

        Assert.areEqual('Named HQ', result.Description);
    }

    @IsTest
    static void withKeyPinsTheProviderVariant() {
        XFTY_SharedAncestor.get('acct')
                .of(new Account())
                .withKey(XFTY_LookupKey.get(Account.SObjectType));

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

        Assert.isNotNull(result.AccountId);
    }

    @IsTest
    static void aSharedAncestorExposesItsNameAndConfiguredTemplate() {
        XFTY_SharedAncestor ancestor = XFTY_SharedAncestor.get('hq')
                .of(new Account(Name = 'Configured'))
                .copyingRelatedField(Account.Name);

        Assert.areEqual('hq', ancestor.getSharedName());
        Assert.areEqual('Configured', (String) ancestor.getOverrideTemplate().get(Account.Name));
        Assert.areEqual(Account.Name, ancestor.getRelatedField());
    }

    // Guards ---------------------------------------------------------------

    @IsTest
    static void getRejectsABlankName() {
        try {
            XFTY_SharedAncestor.get('   ');
            Assert.fail('Expected an exception');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            Assert.isTrue(ex.getMessage().contains('non-blank name'), ex.getMessage());
        }
    }

    @IsTest
    static void anUnconfiguredSharedAncestorThrowsWhenGenerated() {
        System.runAs(TEST_ADMIN) {
            try {
                new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                        .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('never-configured'))
                        .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                        .setInsertMode(XFTY_InsertModeEnum.MOCK)
                        .supply();
                Assert.fail('Expected an exception');
            } catch (XFTY_DummySObjectFtyProviderException ex) {
                Assert.isTrue(ex.getMessage().contains('never configured'), ex.getMessage());
            }
        }
    }

    @IsTest
    static void depthBatchedWithASharedAncestorThrows() {
        XFTY_SharedAncestor.get('hq').of(new Account(Name = 'Shared HQ'));
        System.runAs(TEST_ADMIN) {
            try {
                new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                        .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('hq'))
                        .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                        .setInsertMode(XFTY_InsertModeEnum.NOW)
                        .depthBatched()
                        .supply();
                Assert.fail('Expected an exception');
            } catch (XFTY_DummySObjectFtyProviderException ex) {
                Assert.isTrue(ex.getMessage().contains('not supported together'), ex.getMessage());
            }
        }
    }

    @IsTest
    static void reconfiguringAResolvedSharedAncestorThrows() {
        XFTY_SharedAncestor.get('hq').of(new Account(Name = 'First'));
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('hq'))
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supply();
            Test.stopTest();
        }

        try {
            XFTY_SharedAncestor.get('hq').of(new Account(Name = 'Second'));
            Assert.fail('Expected an exception');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            Assert.isTrue(ex.getMessage().contains('already resolved'), ex.getMessage());
        }
    }

    @IsTest
    static void aSelfReferentialSharedAncestorThrowsInsteadOfRecursing() {
        XFTY_SharedAncestor.get('loop').of(new Account(Name = 'Loop'));
        XFTY_DummySObjectProviderLookupIntf loopy = XFTY_ProviderLookups.of(
                new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                        XFTY_LookupKey.get(Account.SObjectType) => new SelfReferencingAccountProvider(),
                        XFTY_LookupKey.get(Contact.SObjectType) => new XFTY_DefaultContactDataProvider()
                }
        );

        System.runAs(TEST_ADMIN) {
            try {
                new XFTY_DummySObjectProvider(Contact.SObjectType, loopy)
                        .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('loop'))
                        .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                        .setInsertMode(XFTY_InsertModeEnum.MOCK)
                        .supply();
                Assert.fail('Expected a self-reference exception');
            } catch (XFTY_DummySObjectFtyProviderException ex) {
                Assert.isTrue(ex.getMessage().contains('references itself'), ex.getMessage());
            }
        }
    }

    private class SelfReferencingAccountProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                .put(Account.Name, new XFTY_DummyDefaultValueIncrementingString('Loop'))
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

    @IsTest
    static void putOverAResolvedDifferentRecordWarnsButSucceeds() {
        XFTY_SharedAncestor.get('hq').of(new Account(Name = 'Generated'));
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('hq'))
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supply();
            Test.stopTest();
        }

        Account replacement = new Account(Name = 'Replacement');
        replacement.Id = XFTY_IdMocker.generateId(Account.SObjectType);
        XFTY_SharedAncestor.put('hq', replacement); // logs a WARN, does not throw

        Assert.areEqual(replacement.Id, XFTY_SharedAncestor.getId('hq'));
    }
}

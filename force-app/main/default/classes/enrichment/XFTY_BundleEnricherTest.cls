/**
 * Proves `XFTY_BundleEnricher` end to end - a generated graph re-expressed in the
 * shape `record.put(...)` rejects. MOCK generation only, so no `System.runAs`
 * (no DML/SOQL).
 */
@IsTest
private class XFTY_BundleEnricherTest {

    private static XFTY_DummySObjectProviderLookupIntf lookup() {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Account.SObjectType) => new AccountWithParentProvider(),
                XFTY_LookupKey.get(Contact.SObjectType) => new XFTY_DefaultContactDataProvider()
        });
    }

    @IsTest
    static void testInjectAll_forThePrimary_graftsTheGeneratedAncestorOntoEveryRecord() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setQuantityPerTemplate(2)
                .supplyBundle();

        // Act
        Test.startTest();
        List<SObject> enriched = bundle.injectAll(Contact.Id);
        Test.stopTest();

        // Assert
        List<Contact> contacts = (List<Contact>) enriched;
        Assert.isNotNull(contacts[0].Account, 'row 0 Account grafted');
        Assert.isNotNull(contacts[1].Account.Name, 'row 1 Account grafted with fields');
    }

    @IsTest
    static void testInject_withParentDepthTwo_graftsTheWholeAncestorChain() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .includeOptional(new List<SObjectField>{ Contact.AccountId, Account.ParentId })
                .allowAncestorCycles()
                .supplyBundle();
        XFTY_InjectConfig config = XFTY_InjectConfig.allParents();

        // Act
        Test.startTest();
        List<SObject> enriched = bundle.inject(Contact.Id, config);
        Test.stopTest();

        // Assert
        Contact enrichedContact = (Contact) enriched[0];
        Assert.isNotNull(enrichedContact.Account.Parent, 'the grandparent Account is on the chain');
    }

    @IsTest
    static void testInject_withParentDepthOne_stopsBeforeTheGrandparent() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .includeOptional(new List<SObjectField>{ Contact.AccountId, Account.ParentId })
                .allowAncestorCycles()
                .supplyBundle();
        XFTY_InjectConfig config = XFTY_InjectConfig.allParents().parentDepth(1);

        // Act
        Test.startTest();
        List<SObject> enriched = bundle.inject(Contact.Id, config);
        Test.stopTest();

        // Assert
        Contact enrichedContact = (Contact) enriched[0];
        Assert.isNotNull(enrichedContact.Account, 'depth 1 still grafts the Account');
        Assert.isNull(enrichedContact.Account.Parent, 'depth 1 stops before the grandparent');
    }

    @IsTest
    static void testInjectAllChildren_forThePrimary_graftsTheChildSubquery() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .withChildren(Contact.AccountId, 3)
                .supplyBundle();

        // Act
        Test.startTest();
        List<SObject> enriched = bundle.injectAllChildren(Account.Id);
        Test.stopTest();

        // Assert
        Account enrichedAccount = (Account) enriched[0];
        Assert.areEqual(3, enrichedAccount.Contacts.size());
    }

    @IsTest
    static void testInjectAll_forAGeneratedAncestorField_graftsTheInverseChildren() {
        // Arrange - two Contacts, each generates its own Account
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setQuantityPerTemplate(2)
                .supplyBundle();

        // Act
        Test.startTest();
        List<SObject> enriched = bundle.injectAll(Contact.AccountId);
        Test.stopTest();

        // Assert
        Account firstAccount = (Account) enriched[0];
        Assert.areEqual(1, firstAccount.Contacts.size(), 'the Account carries the Contact that generated it');
    }

    @IsTest
    static void testInject_withInjectValueOnTheRecord_forcesTheScalar() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .supplyBundle();
        Datetime forced = Datetime.newInstance(2020, 1, 1, 0, 0, 0);
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing().injectValue(Contact.CreatedDate, forced);

        // Act
        Test.startTest();
        List<SObject> enriched = bundle.inject(Contact.Id, config);
        Test.stopTest();

        // Assert
        Assert.areEqual(forced, ((Contact) enriched[0]).CreatedDate);
    }

    @IsTest
    static void testInject_withAnAncestorPathValue_forcesAScalarSeveralHopsUp() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .supplyBundle();
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing().injectValue(
                new List<SObjectField>{ Contact.AccountId, Account.AnnualRevenue }, 9999
        );

        // Act
        Test.startTest();
        List<SObject> enriched = bundle.inject(Contact.Id, config);
        Test.stopTest();

        // Assert
        Assert.areEqual(9999, ((Contact) enriched[0]).Account.AnnualRevenue);
    }

    @IsTest
    static void testInject_withExcludeParent_skipsThatAncestor() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .supplyBundle();
        XFTY_InjectConfig config = XFTY_InjectConfig.everything()
                .excludeParent(new List<SObjectField>{ Contact.AccountId });

        // Act
        Test.startTest();
        List<SObject> enriched = bundle.inject(Contact.Id, config);
        Test.stopTest();

        // Assert
        Assert.isNull(((Contact) enriched[0]).Account, 'the excluded ancestor was not grafted');
    }

    @IsTest
    static void testInjectAll_forAFieldTheBundleDoesNotHold_throws() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.NONE)
                .supplyBundle();

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            bundle.injectAll(Contact.Id);
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown, 'nothing generated - injectAll has nothing to inject');
    }

    @IsTest
    static void testInject_always_leavesTheOriginalBundleUntouched() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .supplyBundle();

        // Act
        Test.startTest();
        bundle.injectAll(Contact.Id);
        Test.stopTest();

        // Assert
        Assert.isNull(((Contact) bundle.primaryRecords()[0]).Account, 'the source record was not mutated');
    }

    @IsTest
    static void testInject_whenBreakSoqlLimitsIsNotSet_rejectsAnOverDeepParentDepth() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .supplyBundle();
        XFTY_InjectConfig config = XFTY_InjectConfig.allParents().parentDepth(9);

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            bundle.inject(Contact.Id, config);
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('breakSoqlLimits'), 'the error points at the escape hatch');
    }

    private class AccountWithParentProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                .put(Account.Name, new XFTY_IncrementingStringExpression('Enricher Account'))
                .putOptional(Account.ParentId, new XFTY_DummyDefaultRelationship(new Account(Name = 'Parent Co')));

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

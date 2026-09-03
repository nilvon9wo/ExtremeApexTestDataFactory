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
                XFTY_LookupKey.get(Contact.SObjectType) => new XFTY_DefaultContactDataProvider(),
                XFTY_LookupKey.get(Case.SObjectType) => new CaseProvider()
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

    @IsTest
    static void testInjectAll_forThePrimary_alsoPutsTheAncestorsInverseChildOntoIt() {
        // Arrange - one Contact; injectAll should give it contact.Account and contact.Account.Contacts
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .supplyBundle();

        // Act
        Test.startTest();
        List<SObject> enriched = bundle.injectAll(Contact.Id);
        Test.stopTest();

        // Assert
        Contact enrichedContact = (Contact) enriched[0];
        Assert.areEqual(1, enrichedContact.Account.Contacts.size(), 'the ancestor carries the Contact that generated it');
    }

    @IsTest
    static void testInjectAll_forThePrimary_givesEachDownwardChildItsOwnAncestor() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .withChildren(Contact.AccountId, 2)
                .supplyBundle();

        // Act - everything() covers ancestors at every position, including inside a subquery
        Test.startTest();
        List<SObject> enriched = bundle.injectAll(Account.Id);
        Test.stopTest();

        // Assert
        Assert.isNotNull(((Account) enriched[0]).Contacts[0].Account, 'the child Contact carries its generated Account');
    }

    @IsTest
    static void testInject_withChildDepthTwoAndBreakSoqlLimits_graftsGrandchildren() {
        // Arrange - Account -> 2 Contacts -> 3 Cases each
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .with(
                        new XFTY_SObjectChildProvider(Contact.AccountId).setQuantity(2)
                                .with(new XFTY_SObjectChildProvider(Case.ContactId).setQuantity(3))
                )
                .supplyBundle();
        XFTY_InjectConfig config = XFTY_InjectConfig.allChildren().childDepth(2).breakSoqlLimits();

        // Act
        Test.startTest();
        List<SObject> enriched = bundle.inject(Account.Id, config);
        Test.stopTest();

        // Assert
        Assert.areEqual(3, ((Account) enriched[0]).Contacts[0].Cases.size(), 'the nested subquery is grafted');
    }

    @IsTest
    static void testInject_withChildDepthTwoButNoBreakSoqlLimits_throws() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .withChildren(Contact.AccountId, 1)
                .supplyBundle();
        XFTY_InjectConfig config = XFTY_InjectConfig.allChildren().childDepth(2);

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            bundle.inject(Account.Id, config);
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
    }

    @IsTest
    static void testInject_withInjectChildValue_forcesTheScalarOnEveryChild() {
        // Arrange - Account with 3 Contacts
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .withChildren(Contact.AccountId, 3)
                .supplyBundle();
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing()
                .injectChildValue(Contact.AccountId, Contact.LastActivityDate, Date.newInstance(2021, 6, 1));

        // Act
        Test.startTest();
        List<SObject> enriched = bundle.inject(Account.Id, config);
        Test.stopTest();

        // Assert
        List<Contact> children = ((Account) enriched[0]).Contacts;
        Assert.areEqual(Date.newInstance(2021, 6, 1), children[0].LastActivityDate);
        Assert.areEqual(Date.newInstance(2021, 6, 1), children[2].LastActivityDate);
    }

    @IsTest
    static void testInject_withInjectChildValueExpression_givesEachChildADistinctValue() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .withChildren(Contact.AccountId, 3)
                .supplyBundle();
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing().injectChildValue(
                Contact.AccountId, Contact.Description, new XFTY_IncrementingStringExpression('note')
        );

        // Act
        Test.startTest();
        List<SObject> enriched = bundle.inject(Account.Id, config);
        Test.stopTest();

        // Assert
        List<Contact> children = ((Account) enriched[0]).Contacts;
        Set<String> distinct = new Set<String>{ children[0].Description, children[1].Description, children[2].Description };
        Assert.areEqual(3, distinct.size(), 'the expression resolved fresh for each child');
    }

    @IsTest
    static void testInject_onASelfHierarchy_childValueTargetsTheChildrenAndPathValueTheParent() {
        // Arrange - a middle Account, one parent Account and two child Accounts, all via Account.ParentId
        XFTY_DummySObjectBundle parentSub = new XFTY_DummySObjectBundle();
        parentSub.putPrimaries(Account.Id, new List<SObject>{ new Account(Name = 'original parent') });
        XFTY_DummySObjectBundle childrenSub = new XFTY_DummySObjectBundle();
        childrenSub.putPrimaries(Account.Id, new List<SObject>{
                new Account(Name = 'original c0'), new Account(Name = 'original c1')
        });
        XFTY_DummySObjectBundle middle = new XFTY_DummySObjectBundle();
        middle.putPrimaries(Account.Id, new List<SObject>{ new Account(Name = 'Middle') });
        middle.put(Account.ParentId, parentSub.primaryRecords());
        middle.put(Account.ParentId, parentSub);
        middle.putChild(Account.ParentId, childrenSub, new List<Integer>{ 0, 0 });
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing()
                .injectValue(new List<SObjectField>{ Account.ParentId, Account.Name }, 'parent name')
                .injectChildValue(Account.ParentId, Account.Name, 'child name');

        // Act
        Test.startTest();
        List<SObject> enriched = middle.inject(Account.Id, config);
        Test.stopTest();

        // Assert
        Account enrichedMiddle = (Account) enriched[0];
        Assert.areEqual('parent name', enrichedMiddle.Parent.Name, 'injectValue(path) walked up to the parent');
        Assert.areEqual('child name', enrichedMiddle.ChildAccounts[0].Name, 'injectChildValue walked down to the children');
        Assert.areEqual('child name', enrichedMiddle.ChildAccounts[1].Name);
    }

    @IsTest
    static void testInject_withAnInjectChildValuePathTheGraphNeverProduced_throws() {
        // Arrange - no Cases generated, so the injectChildValue path is never reached
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .withChildren(Contact.AccountId, 1)
                .supplyBundle();
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing()
                .injectChildValue(Case.ContactId, Case.Subject, 'x');

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            bundle.inject(Account.Id, config);
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('injectChildValue'), 'the error names the unreached path');
    }

    @IsTest
    static void testInject_withAnInjectChildValueDeeperThanChildDepth_throws() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .withChildren(Contact.AccountId, 1)
                .supplyBundle();
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing().injectChildValue(
                new List<SObjectField>{ Contact.AccountId, Case.ContactId, Case.Subject }, 'x'
        );

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            bundle.inject(Account.Id, config);
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('childDepth'), 'the error points at childDepth');
    }

    @IsTest
    static void testInject_returnsThePlainListOfEnrichedTargetRecords() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setQuantityPerTemplate(2)
                .supplyBundle();

        // Act
        Test.startTest();
        List<SObject> enriched = bundle.inject(Contact.Id, XFTY_InjectConfig.allParents());
        Test.stopTest();

        // Assert
        Assert.areEqual(2, enriched.size());
        Assert.isInstanceOfType(enriched[0], Contact.class);
    }

    private class CaseProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Case.Id)
                .put(Case.Subject, new XFTY_IncrementingStringExpression('Enricher Case'));

        public SObjectField getPrimaryTargetField() {
            return Case.Id;
        }

        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }

        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext context, List<SObject> templates) {
            return XFTY_DummySObjectFactory.createBundle(context, this.template, templates);
        }
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

/**
 * Runnable proof for docs/use/enrichment.md - every `@IsTest` method is one
 * fenced example from that page. MOCK generation only, so no `System.runAs`.
 */
@IsTest
private class XFTY_Ex_EnrichmentTest {

    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();

    private static XFTY_DummySObjectProviderLookupIntf withCases() {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Account.SObjectType) => new XFTY_DefaultAccountDataProvider(),
                XFTY_LookupKey.get(Contact.SObjectType) => new XFTY_DefaultContactDataProvider(),
                XFTY_LookupKey.get(Case.SObjectType) => new BlankCaseProvider()
        });
    }

    @IsTest
    static void testInjectAll_putsTheGeneratedAncestorOntoTheRecord() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setQuantityPerTemplate(2)
                .supplyBundle();

        // Act
        Test.startTest();
        List<SObject> enriched = bundle.injectAll(Contact.Id);
        Test.stopTest();

        // Assert - code under test can now navigate contact.Account.Name off the SObject
        List<Contact> contacts = (List<Contact>) enriched;
        Assert.isNotNull(contacts[0].Account.Name);
        Assert.isNotNull(contacts[1].Account.Name);
    }

    @IsTest
    static void testInjectAllChildren_putsTheChildSubqueryOntoTheRecord() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
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
    static void testInjectAll_onAGeneratedAncestor_putsTheInverseChildrenOntoIt() {
        // Arrange - each Contact generated its own Account; that Account's Contacts subquery is the Contact
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .supplyBundle();

        // Act
        Test.startTest();
        List<SObject> enriched = bundle.injectAll(Contact.AccountId);
        Test.stopTest();

        // Assert
        Account generatedAccount = (Account) enriched[0];
        Assert.areEqual(1, generatedAccount.Contacts.size(), 'the Account carries the Contact that generated it');
    }

    @IsTest
    static void testInject_withInjectChild_namesExactlyOneChildCollection() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .withChildren(Contact.AccountId, 2)
                .supplyBundle();
        // Act
        Test.startTest();
        List<SObject> enriched = bundle.inject(Account.Id, XFTY_InjectConfig.nothing().injectChild(Contact.AccountId));
        Test.stopTest();

        // Assert
        Assert.areEqual(2, ((Account) enriched[0]).Contacts.size());
    }

    @IsTest
    static void testInject_withAForcedScalar_writesAFieldPutWouldReject() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .supplyBundle();
        Datetime lastActivity = Datetime.newInstance(2021, 3, 1, 0, 0, 0);
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing()
                .injectValue(Contact.LastActivityDate, lastActivity.date())
                .injectValue(new List<SObjectField>{ Contact.AccountId, Account.AnnualRevenue }, 7500000);

        // Act
        Test.startTest();
        List<SObject> enriched = bundle.inject(Contact.Id, config);
        Test.stopTest();

        // Assert
        Contact enrichedContact = (Contact) enriched[0];
        Assert.areEqual(lastActivity.date(), enrichedContact.LastActivityDate);
        Assert.areEqual(7500000, enrichedContact.Account.AnnualRevenue);
    }

    @IsTest
    static void testInject_withACappedBreadthAndAnExcludedParent_honoursBoth() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .supplyBundle();
        XFTY_InjectConfig config = XFTY_InjectConfig.everything()
                .parentDepth(2)
                .excludeParent(new List<SObjectField>{ Contact.AccountId });

        // Act
        Test.startTest();
        List<SObject> enriched = bundle.inject(Contact.Id, config);
        Test.stopTest();

        // Assert
        Assert.isNull(((Contact) enriched[0]).Account, 'the excluded ancestor is not grafted');
    }

    @IsTest
    static void testInject_withABreadthStart_configuresWhatInjectAllParentsWouldDo() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .supplyBundle();

        // Act
        Test.startTest();
        List<SObject> enriched = bundle.inject(Contact.Id, XFTY_InjectConfig.allParents().parentDepth(2));
        Test.stopTest();

        // Assert
        Assert.isNotNull(((Contact) enriched[0]).Account, 'the ancestor within depth 2 is grafted');
    }

    @IsTest
    static void testInjectAll_putsTheGeneratedAncestorsInverseChildBackOntoIt() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .supplyBundle();

        // Act
        Test.startTest();
        List<Contact> contacts = (List<Contact>) bundle.injectAll(Contact.Id);
        Test.stopTest();

        // Assert
        Assert.areEqual(1, contacts[0].Account.Contacts.size(), 'the generated Account carries the Contact back');
    }

    @IsTest
    static void testInject_withChildDepthTwoAndBreakSoqlLimits_graftsGrandchildren() {
        // Arrange - Account -> 2 Contacts -> 3 Cases each
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, withCases())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .with(
                        new XFTY_SObjectChildProvider(Contact.AccountId).setQuantity(2)
                                .with(new XFTY_SObjectChildProvider(Case.ContactId).setQuantity(3))
                )
                .supplyBundle();

        // Act
        Test.startTest();
        List<Account> accounts = (List<Account>) bundle.inject(
                Account.Id, XFTY_InjectConfig.allChildren().childDepth(2).breakSoqlLimits()
        );
        Test.stopTest();

        // Assert
        Assert.areEqual(3, accounts[0].Contacts[0].Cases.size());
    }

    @IsTest
    static void testInject_withInjectChildValue_forcesADistinctScalarOnEveryChild() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .withChildren(Contact.AccountId, 3)
                .supplyBundle();
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing()
                .injectChildValue(Contact.AccountId, Contact.Description, new XFTY_IncrementingStringExpression('note'));

        // Act
        Test.startTest();
        List<SObject> enriched = bundle.inject(Account.Id, config);
        Test.stopTest();

        // Assert - each child got its own resolution of the expression
        List<Contact> children = ((Account) enriched[0]).Contacts;
        Assert.areEqual('note 1', children[0].Description);
        Assert.areEqual('note 3', children[2].Description);
    }

    @IsTest
    static void testInject_withAValueComputedFromTheGraph_readsTheInputsFirstThenForcesALiteral() {
        // Arrange - the workaround for "an injected value can't feed a context-aware value"
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .supplyBundle();
        String parentName = (String) bundle.getValue(new List<SObjectField>{ Contact.AccountId, Account.Name });
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing()
                .injectValue(Contact.Description, parentName + ' (contact)');

        // Act
        Test.startTest();
        List<SObject> enriched = bundle.inject(Contact.Id, config);
        Test.stopTest();

        // Assert
        Assert.areEqual(parentName + ' (contact)', ((Contact) enriched[0]).Description);
    }

    @IsTest
    static void testInject_withACompoundFieldValue_readsBackThroughTheCompound() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .supplyBundle();
        XFTY_InjectConfig config = XFTY_InjectConfig.nothing()
                .injectValue(Contact.MailingAddress, new Map<String, Object>{ 'city' => 'Portland', 'street' => '2 Oak St' });

        // Act
        Test.startTest();
        List<Contact> contacts = (List<Contact>) bundle.inject(Contact.Id, config);
        Test.stopTest();

        // Assert
        Assert.areEqual('Portland', ((Address) contacts[0].MailingAddress).getCity());
    }

    @IsTest
    static void testInject_usingXftySObjectInjectorDirectly_needsNoBundle() {
        // Arrange
        List<Contact> contacts = new List<Contact>{ new Contact(LastName = 'Standalone') };
        List<SObject> accounts = new List<SObject>{ new Account(Name = 'Grafted directly') };

        // Act
        Test.startTest();
        List<Contact> enriched = (List<Contact>) XFTY_SObjectInjector.inject(contacts)
                .relationship('Account', accounts)
                .value(Contact.CreatedDate, Datetime.newInstance(2020, 1, 1, 0, 0, 0))
                .result();
        Test.stopTest();

        // Assert
        Assert.areEqual('Grafted directly', enriched[0].Account.Name);
    }

    private class BlankCaseProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Case.Id)
                .put(Case.Subject, new XFTY_IncrementingStringExpression('Example Case'));

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
}

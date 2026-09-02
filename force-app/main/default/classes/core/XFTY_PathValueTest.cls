/**
 * Proves `put(List<SObjectField> path, value)` - path-scoped value overrides that
 * land on a generated ancestor, forcing every relationship on the way (like
 * `includeOptional`). MOCK mode throughout - no DML, so no `System.runAs`.
 */
@IsTest
private class XFTY_PathValueTest {

    // MGR_KEY / SKIP_KEY are declared before DEEP_LOOKUP on purpose: Apex
    // initialises statics in source order, and the deep lookup's map is built
    // from these keys - declared lower they would still be null when it runs,
    // collapsing the chain onto the base User key and tripping the ancestor-cycle
    // guard on a real org (the local runtime is more forgiving about init order).
    private static final XFTY_LookupKeyIntf MGR_KEY = XFTY_FlavouredLookupKey.get(User.SObjectType, 'mgr');
    private static final XFTY_LookupKeyIntf SKIP_KEY = XFTY_FlavouredLookupKey.get(User.SObjectType, 'skip');

    private static XFTY_DummySObjectProviderLookupIntf lookup() {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Account.SObjectType) => new XFTY_DefaultAccountDataProvider(),
                XFTY_LookupKey.get(Contact.SObjectType) => new ContactWithOptionalManagerProvider(),
                XFTY_LookupKey.get(User.SObjectType) => new XFTY_DefaultUserDataProvider(),
                XFTY_LookupKey.get(Case.SObjectType) => new CaseProvider()
        });
    }

    private static XFTY_DummySObjectProviderLookupIntf deepLookup() {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Account.SObjectType) => new XFTY_DefaultAccountDataProvider(),
                XFTY_LookupKey.get(Contact.SObjectType) => new ContactWithOptionalManagerProvider(),
                XFTY_LookupKey.get(User.SObjectType) => new ChainedUserProvider(MGR_KEY),
                MGR_KEY => new ChainedUserProvider(SKIP_KEY),
                SKIP_KEY => new LeafUserProvider()
        });
    }

    private static XFTY_DummySObjectProviderLookupIntf sharedParentLookup() {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Account.SObjectType) => new XFTY_DefaultAccountDataProvider(),
                XFTY_LookupKey.get(Contact.SObjectType) => new ContactUnderSharedAccountProvider()
        });
    }

    // A value landing on the generated ancestor ----------------------

    @IsTest
    static void testPut_withALiteralPathValue_landsItOnTheGeneratedAncestor() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .put(new List<SObjectField>{ Contact.AccountId, Account.Industry }, 'Aerospace');

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Account generatedAccount = (Account) bundle.getBundle(Contact.AccountId).primaryRecords()[0];
        Assert.areEqual('Aerospace', generatedAccount.Industry, 'the path literal overrode the Account Provider default');
    }

    @IsTest
    static void testPut_withAValueExpressionPathValue_runsItOncePerGeneratedAncestor() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup())
                .setQuantityPerTemplate(3)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .put(new List<SObjectField>{ Contact.AccountId, Account.Name },
                        new XFTY_IncrementingStringExpression('Path Account'));

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        List<SObject> accounts = bundle.getBundle(Contact.AccountId).primaryRecords();
        Assert.areEqual(3, accounts.size());
        Set<String> names = new Set<String>();
        for (SObject account : accounts) {
            names.add((String) account.get('Name'));
        }
        Assert.areEqual(3, names.size(), 'the incrementing strategy ran once per generated Account');
    }

    @IsTest
    static void testPut_withAContextAwarePathValue_evaluatesItOnTheGeneratedAncestor() {
        // Arrange - the generated Account's Site copies its own Name (a sibling on the ancestor)
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .put(new List<SObjectField>{ Contact.AccountId, Account.Site }, new XFTY_CopyFromSiblingExpression(Account.Name));

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Account generatedAccount = (Account) bundle.getBundle(Contact.AccountId).primaryRecords()[0];
        Assert.areEqual(generatedAccount.Name, generatedAccount.Site, 'context-aware value evaluated on the ancestor');
    }

    @IsTest
    static void testPutRequired_withARelationshipPathValue_givesTheAncestorItsOwnGeneratedParent() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .putRequired(new List<SObjectField>{ Contact.AccountId, Account.OwnerId },
                        new XFTY_DummyDefaultRelationship(new User()));

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Account generatedAccount = (Account) bundle.getBundle(Contact.AccountId).primaryRecords()[0];
        Assert.isNotNull(generatedAccount.OwnerId, 'the Account got a generated Owner via the path');
    }

    @IsTest
    static void testPut_withADeepTwoRelationshipPath_walksBothHopsAndSetsTheTargetField() {
        // Arrange - Case -> Contact (Case.ContactId) -> Account (Contact.AccountId), set the Account's Industry
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Case.SObjectType, lookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .put(new List<SObjectField>{ Case.ContactId, Contact.AccountId, Account.Industry }, 'DeepValue');

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Contact generatedContact = (Contact) bundle.getBundle(Case.ContactId).primaryRecords()[0];
        Account generatedAccount = (Account) bundle.getBundle(Case.ContactId)
                .getBundle(Contact.AccountId).primaryRecords()[0];
        Assert.isNotNull(generatedContact.Id);
        Assert.areEqual('DeepValue', generatedAccount.Industry);
    }

    @IsTest
    static void testPut_atTheDefaultNoneInclusivity_stillForcesTheNamedAncestor() {
        // Arrange - naming Contact.AccountId in a path value forces that ancestor even at NONE
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .put(new List<SObjectField>{ Contact.AccountId, Account.Industry }, 'Aerospace');

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Account generatedAccount = (Account) bundle.getBundle(Contact.AccountId).primaryRecords()[0];
        Assert.areEqual('Aerospace', generatedAccount.Industry);
    }

    @IsTest
    static void testPutRequired_withARelationshipPathValue_drivesAnEntireDeepAncestorHierarchy() {
        // Arrange - Contact -> Account (path) -> Account.OwnerId := User (path value) -> that User's
        // own required Manager (distinct Provider) -> that Manager's required skip-level Manager.
        // Every level generates at the DEFAULT (NONE) inclusivity because each step is named.
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, deepLookup())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .putRequired(
                        new List<SObjectField>{ Contact.AccountId, Account.OwnerId },
                        new XFTY_DummyDefaultRelationship(new User())
                );

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert - every level of the chain generated
        XFTY_DummySObjectBundle accountBundle = bundle.getBundle(Contact.AccountId);
        Assert.isNotNull(accountBundle, 'Account forced by the path');
        Account generatedAccount = (Account) accountBundle.primaryRecords()[0];
        Assert.isNotNull(generatedAccount.OwnerId, 'Account.OwnerId forced by the relationship path value');

        XFTY_DummySObjectBundle ownerBundle = accountBundle.getBundle(Account.OwnerId);
        Assert.isNotNull(ownerBundle, 'the owner User generated');
        Assert.isNotNull(((User) ownerBundle.primaryRecords()[0]).ManagerId, 'the owner generated its own Manager');

        XFTY_DummySObjectBundle managerBundle = ownerBundle.getBundle(User.ManagerId);
        Assert.isNotNull(managerBundle, 'the Manager User (distinct Provider) generated');
        Assert.isNotNull(((User) managerBundle.primaryRecords()[0]).ManagerId, 'the Manager generated its skip-level Manager');
        Assert.isNotNull(managerBundle.getBundle(User.ManagerId), 'and that skip-level User is in the bundle');
    }

    @IsTest
    static void testPut_whenAnOptionalRelationshipIsNamedByAPathValue_forcesItAndSetsAFieldOnIt() {
        // Arrange - Contact.ReportsToId is optional on this Provider
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .put(new List<SObjectField>{ Contact.ReportsToId, Contact.Department }, 'Exec');

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        Contact manager = (Contact) bundle.getBundle(Contact.ReportsToId).primaryRecords()[0];
        Assert.areEqual('Exec', manager.Department);
    }

    // Loud errors --------------------------------------------------

    @IsTest
    static void testPut_whenAPathFieldIsNotARelationship_throws() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup())
                .put(new List<SObjectField>{ Contact.FirstName, Account.Industry }, 'x');

        // Act
        Exception thrown;
        Test.startTest();
        try {
            provider.supplyBundle();
        } catch (Exception ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown, 'a non-relationship path field is a loud error, not a silent no-op');
        Assert.isTrue(thrown.getMessage().containsIgnoreCase('relationship'), thrown.getMessage());
    }

    @IsTest
    static void testPut_whenThePathTargetsASharedAncestor_throws() {
        // Arrange
        XFTY_SharedAncestor.put('shared-acct', new Account(Name = 'Shared HQ'));
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, sharedParentLookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .put(new List<SObjectField>{ Contact.AccountId, Account.Industry }, 'Aerospace');

        // Act
        Exception thrown;
        Test.startTest();
        try {
            provider.supplyBundle();
        } catch (Exception ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown, 'a path value into a shared ancestor is a loud error, not a dropped value');
        Assert.isTrue(thrown.getMessage().containsIgnoreCase('shared ancestor'), thrown.getMessage());
    }

    @IsTest
    static void testPut_whenThePathHasNoRelationshipHop_throws() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup());

        // Act
        Exception thrown;
        Test.startTest();
        try {
            provider.put(new List<SObjectField>{ Account.Industry }, 'x');
        } catch (Exception ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown, 'a one-element path has no relationship to walk');
        Assert.isTrue(thrown.getMessage().contains('at least one relationship'), thrown.getMessage());
    }

    // In-test Providers ------------------------------------------

    private class ContactWithOptionalManagerProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                .put(Contact.LastName, new XFTY_IncrementingStringExpression('Contact'))
                .put(Contact.Email, new XFTY_UniqueEmailExpression('test.contact'))
                .putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account()))
                .putOptional(Contact.ReportsToId, new XFTY_DummyDefaultRelationship(new Contact()));

        public SObjectField getPrimaryTargetField() {
            return Contact.Id;
        }
        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }
        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext context, List<SObject> templateSObjectList) {
            return XFTY_DummySObjectFactory.createBundle(context, this.template, templateSObjectList);
        }
    }

    private class ContactUnderSharedAccountProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                .put(Contact.LastName, new XFTY_IncrementingStringExpression('Contact'))
                .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('shared-acct'));
        public SObjectField getPrimaryTargetField() {
            return Contact.Id;
        }
        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }
        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext context, List<SObject> templateSObjectList) {
            return XFTY_DummySObjectFactory.createBundle(context, this.template, templateSObjectList);
        }
    }

    private class CaseProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Case.Id)
                .put(Case.Subject, new XFTY_IncrementingStringExpression('Case'))
                .putRequired(Case.ContactId, new XFTY_DummyDefaultRelationship(new Contact()));

        public SObjectField getPrimaryTargetField() {
            return Case.Id;
        }
        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }
        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext context, List<SObject> templateSObjectList) {
            return XFTY_DummySObjectFactory.createBundle(context, this.template, templateSObjectList);
        }
    }

    /** A User that requires a Manager generated by `nextKey`. */
    private class ChainedUserProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template;
        private ChainedUserProvider(XFTY_LookupKeyIntf nextKey) {
            this.template = leafUserTemplate()
                    .putRequired(User.ManagerId, new XFTY_DummyDefaultRelationship(nextKey, new User()));
        }
        public SObjectField getPrimaryTargetField() {
            return User.Id;
        }
        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }
        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext context, List<SObject> templateSObjectList) {
            return XFTY_DummySObjectFactory.createBundle(context, this.template, templateSObjectList);
        }
    }

    private class LeafUserProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = leafUserTemplate();
        public SObjectField getPrimaryTargetField() {
            return User.Id;
        }
        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }
        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext context, List<SObject> templateSObjectList) {
            return XFTY_DummySObjectFactory.createBundle(context, this.template, templateSObjectList);
        }
    }

    private static XFTY_DummySObjectMasterTemplate leafUserTemplate() {
        return new XFTY_DummySObjectMasterTemplate(User.Id)
                .put(User.LastName, new XFTY_IncrementingStringExpression('User'))
                .put(User.Alias, new XFTY_IncrementingStringExpression('a'))
                .put(User.Email, new XFTY_UniqueEmailExpression('test.user'))
                .put(User.Username, new XFTY_UniqueEmailExpression('test.user.name'))
                .put(User.EmailEncodingKey, new XFTY_LiteralExpression('ISO-8859-1'))
                .put(User.LanguageLocaleKey, new XFTY_LiteralExpression('en_US'))
                .put(User.LocaleSidKey, new XFTY_LiteralExpression('en_US'))
                .put(User.TimeZoneSidKey, new XFTY_LiteralExpression('GMT'))
                .put(User.ProfileId, new XFTY_LiteralExpression(XFTY_DefaultUserDataProvider.profileIdFor('System Administrator')));
    }
}

/**
 * `put(List<SObjectField> path, value)` - path-scoped value overrides that land
 * on a generated ancestor. Pairs with `setInclusivity(REQUIRED)` / `ALL` (the
 * ancestor still has to be generated, exactly like `includeOptional`).
 */
@IsTest
private class XFTY_PathValueTest {
    private static final XFTY_DummySObjectProviderLookupIntf LOOKUP = new PathTestLookup();
    private static final XFTY_DummySObjectProviderLookupIntf DEEP_LOOKUP = new DeepLookup();

    @IsTest
    static void literalLandsOnTheGeneratedAncestor() {
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .put(new List<SObjectField>{ Contact.AccountId, Account.Industry }, 'Aerospace')
                .supplyBundle();

        Account generatedAccount = (Account) bundle.getBundle(Contact.AccountId).primaryRecords()[0];
        System.assertEquals('Aerospace', generatedAccount.Industry, 'path literal overrode the Account Provider default');
    }

    @IsTest
    static void valueStrategyLandsOnTheGeneratedAncestor() {
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setQuantityPerTemplate(3)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .put(new List<SObjectField>{ Contact.AccountId, Account.Name },
                        new XFTY_IncrementingStringExpression('Path Account'))
                .supplyBundle();

        List<SObject> accounts = bundle.getBundle(Contact.AccountId).primaryRecords();
        System.assertEquals(3, accounts.size());
        Set<String> names = new Set<String>();
        for (SObject a : accounts) {
            names.add((String) a.get('Name'));
        }
        System.assertEquals(3, names.size(), 'the incrementing strategy ran once per generated Account');
        for (String name : names) {
            System.assert(name.startsWith('Path Account'), name);
        }
    }

    @IsTest
    static void contextAwareValueRunsOnTheGeneratedAncestor() {
        // The generated Account's Site copies its own Name (a sibling on the ancestor).
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .put(new List<SObjectField>{ Contact.AccountId, Account.Site }, new XFTY_CopyFromSiblingExpression(Account.Name))
                .supplyBundle();

        Account generatedAccount = (Account) bundle.getBundle(Contact.AccountId).primaryRecords()[0];
        System.assertEquals(generatedAccount.Name, generatedAccount.Site, 'context-aware value evaluated on the ancestor');
    }

    @IsTest
    static void relationshipValueGivesTheAncestorItsOwnGeneratedParent() {
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .putRequired(new List<SObjectField>{ Contact.AccountId, Account.OwnerId },
                        new XFTY_DummyDefaultRelationship(new User()))
                .supplyBundle();

        Account generatedAccount = (Account) bundle.getBundle(Contact.AccountId).primaryRecords()[0];
        System.assertNotEquals(null, generatedAccount.OwnerId, 'the Account got a generated Owner via the path');
    }

    @IsTest
    static void aRelationshipPathValueDrivesADeepAncestorHierarchy() {
        // Contact -> Account (path) -> Account.OwnerId := User (path value) -> that User's
        // own required Manager (a distinct Provider) -> that Manager's required Profile-holder.
        // Every level must generate, at the DEFAULT (NONE) inclusivity, because each step is
        // named explicitly.
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, DEEP_LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .putRequired(
                        new List<SObjectField>{ Contact.AccountId, Account.OwnerId },
                        new XFTY_DummyDefaultRelationship(new User())
                )
                .supplyBundle();

        XFTY_DummySObjectBundle accountBundle = bundle.getBundle(Contact.AccountId);
        System.assertNotEquals(null, accountBundle, 'Account forced by the path');
        Account generatedAccount = (Account) accountBundle.primaryRecords()[0];
        System.assertNotEquals(null, generatedAccount.OwnerId, 'Account.OwnerId forced by the relationship path value');

        XFTY_DummySObjectBundle ownerBundle = accountBundle.getBundle(Account.OwnerId);
        System.assertNotEquals(null, ownerBundle, 'the owner User generated');
        User owner = (User) ownerBundle.primaryRecords()[0];
        System.assertNotEquals(null, owner.ManagerId, 'the owner User generated its own required Manager');

        XFTY_DummySObjectBundle managerBundle = ownerBundle.getBundle(User.ManagerId);
        System.assertNotEquals(null, managerBundle, 'the Manager User (distinct Provider) generated');
        User manager = (User) managerBundle.primaryRecords()[0];
        System.assertNotEquals(null, manager.ManagerId, 'the Manager generated its own skip-level Manager - full depth');

        System.assertNotEquals(
                null,
                managerBundle.getBundle(User.ManagerId),
                'and that skip-level User is in the bundle'
        );
    }

    @IsTest
    static void deepPathWalksTwoRelationships() {
        // Case -> Contact (Case.ContactId) -> Account (Contact.AccountId), set the Account's Industry.
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Case.SObjectType, LOOKUP)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .put(new List<SObjectField>{ Case.ContactId, Contact.AccountId, Account.Industry }, 'DeepValue')
                .supplyBundle();

        Contact generatedContact = (Contact) bundle.getBundle(Case.ContactId).primaryRecords()[0];
        Account generatedAccount = (Account) bundle.getBundle(Case.ContactId)
                .getBundle(Contact.AccountId).primaryRecords()[0];
        System.assertNotEquals(null, generatedContact.Id);
        System.assertEquals('DeepValue', generatedAccount.Industry);
    }

    @IsTest
    static void pathValueForcesItsAncestorEvenAtNoneInclusivity() {
        // Default inclusivity is NONE, but naming Contact.AccountId in a path value
        // forces that ancestor - the same way includeOptional(...) forces a path.
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .put(new List<SObjectField>{ Contact.AccountId, Account.Industry }, 'Aerospace')
                .supplyBundle();

        Account generatedAccount = (Account) bundle.getBundle(Contact.AccountId).primaryRecords()[0];
        System.assertEquals('Aerospace', generatedAccount.Industry);
    }

    @IsTest
    static void aPathFieldThatIsNotARelationshipThrowsLoudly() {
        try {
            new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .put(new List<SObjectField>{ Contact.FirstName, Account.Industry }, 'x') // FirstName is not a relationship
                    .supplyBundle();
            System.assert(false, 'expected a loud exception, not a silent no-op');
        } catch (Exception e) {
            System.assert(e.getMessage().containsIgnoreCase('relationship'), e.getMessage());
        }
    }

    @IsTest
    static void aPathValueIntoASharedAncestorThrowsLoudly() {
        XFTY_SharedAncestor.get('shared-acct').of(new Account(Name = 'Shared HQ'));
        try {
            new XFTY_DummySObjectProvider(Contact.SObjectType, new SharedParentLookup())
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .put(new List<SObjectField>{ Contact.AccountId, Account.Industry }, 'Aerospace')
                    .supplyBundle();
            System.assert(false, 'expected a loud error, not a dropped value');
        } catch (Exception e) {
            System.assert(e.getMessage().containsIgnoreCase('shared ancestor'), e.getMessage());
        }
    }

    @IsTest
    static void pathNeedsAtLeastARelationshipAndATarget() {
        try {
            new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .put(new List<SObjectField>{ Account.Industry }, 'x');
            System.assert(false, 'expected an exception for a one-element path');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('at least one relationship'), e.getMessage());
        }
    }

    @IsTest
    static void includeOptionalAndPathValueOnTheSameOptionalRelationshipCooperate() {
        // Contact.ReportsToId is optional on this Provider - the path value forces it and sets a field on it.
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .put(new List<SObjectField>{ Contact.ReportsToId, Contact.Department }, 'Exec')
                .supplyBundle();

        Contact manager = (Contact) bundle.getBundle(Contact.ReportsToId).primaryRecords()[0];
        System.assertEquals('Exec', manager.Department);
    }

    // ------------------------------------------------------------------------------

    private class PathTestLookup implements XFTY_DummySObjectProviderLookupIntf {
        private final Map<SObjectType, XFTY_DummySobjectProviderIntf> byType
                = new Map<SObjectType, XFTY_DummySobjectProviderIntf>{
                        Account.SObjectType => new XFTY_DefaultAccountDataProvider(),
                        Contact.SObjectType => new ContactWithOptionalManagerProvider(),
                        User.SObjectType => new XFTY_DefaultUserDataProvider(),
                        Case.SObjectType => new CaseProvider()
                };
        public XFTY_DummySobjectProviderIntf get(SObjectType sObjectType) {
            return this.byType.get(sObjectType);
        }
        public XFTY_DummySobjectProviderIntf get(XFTY_LookupKeyIntf lookupKey) {
            return this.byType.get(lookupKey.getSObjectType());
        }
        public Set<XFTY_LookupKeyIntf> keysFor(SObject sObj) {
            return new Set<XFTY_LookupKeyIntf>{ XFTY_LookupKey.get(sObj.getSObjectType()) };
        }
    }

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

    private class SharedParentLookup implements XFTY_DummySObjectProviderLookupIntf {
        private final Map<SObjectType, XFTY_DummySobjectProviderIntf> byType
                = new Map<SObjectType, XFTY_DummySobjectProviderIntf>{
                        Account.SObjectType => new XFTY_DefaultAccountDataProvider(),
                        Contact.SObjectType => new ContactUnderSharedAccountProvider()
                };
        public XFTY_DummySobjectProviderIntf get(SObjectType sObjectType) {
            return this.byType.get(sObjectType);
        }
        public XFTY_DummySobjectProviderIntf get(XFTY_LookupKeyIntf lookupKey) {
            return this.byType.get(lookupKey.getSObjectType());
        }
        public Set<XFTY_LookupKeyIntf> keysFor(SObject sObj) {
            return new Set<XFTY_LookupKeyIntf>{ XFTY_LookupKey.get(sObj.getSObjectType()) };
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

    // A deep chain for the relationship-path-value test:
    // Contact -> Account -> User(owner) -> User(manager, flavour 'mgr') -> User(skip, flavour 'skip')

    private static final XFTY_LookupKeyIntf MGR_KEY = XFTY_FlavouredLookupKey.get(User.SObjectType, 'mgr');
    private static final XFTY_LookupKeyIntf SKIP_KEY = XFTY_FlavouredLookupKey.get(User.SObjectType, 'skip');

    private class DeepLookup implements XFTY_DummySObjectProviderLookupIntf {
        private final Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf> byKey
                = new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                        XFTY_LookupKey.get(Account.SObjectType) => new XFTY_DefaultAccountDataProvider(),
                        XFTY_LookupKey.get(Contact.SObjectType) => new ContactWithOptionalManagerProvider(),
                        XFTY_LookupKey.get(User.SObjectType) => new ChainedUserProvider(MGR_KEY),
                        MGR_KEY => new ChainedUserProvider(SKIP_KEY),
                        SKIP_KEY => new LeafUserProvider()
                };
        public XFTY_DummySobjectProviderIntf get(SObjectType sObjectType) {
            return this.byKey.get(XFTY_LookupKey.get(sObjectType));
        }
        public XFTY_DummySobjectProviderIntf get(XFTY_LookupKeyIntf lookupKey) {
            return this.byKey.get(lookupKey);
        }
        public Set<XFTY_LookupKeyIntf> keysFor(SObject sObj) {
            return new Set<XFTY_LookupKeyIntf>{ XFTY_LookupKey.get(sObj.getSObjectType()) };
        }
    }

    /** A User that requires a Manager generated by `nextKey`. */
    private class ChainedUserProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template;
        ChainedUserProvider(XFTY_LookupKeyIntf nextKey) {
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

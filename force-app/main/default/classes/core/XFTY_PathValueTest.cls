/**
 * `put(List<SObjectField> path, value)` - path-scoped value overrides that land
 * on a generated ancestor. Pairs with `setInclusivity(REQUIRED)` / `ALL` (the
 * ancestor still has to be generated, exactly like `includeOptional`).
 */
@IsTest
private class XFTY_PathValueTest {
    private static final XFTY_DummySObjectProviderLookupIntf LOOKUP = new PathTestLookup();

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
                        new XFTY_DummyDefaultValueIncrementingString('Path Account'))
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
                .put(new List<SObjectField>{ Contact.AccountId, Account.Site }, new XFTY_CopyFromSibling(Account.Name))
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
    static void pathValueOnAnUngeneratedAncestorIsANoOp() {
        // Default inclusivity NONE: no ancestor is generated, so the path value simply does not apply.
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .put(new List<SObjectField>{ Contact.AccountId, Account.Industry }, 'Aerospace')
                .supplyBundle();

        System.assertEquals(null, bundle.getBundle(Contact.AccountId), 'no Account generated at NONE inclusivity');
        System.assertNotEquals(null, bundle.primaryRecords()[0].Id);
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
                .put(Contact.LastName, new XFTY_DummyDefaultValueIncrementingString('Contact'))
                .put(Contact.Email, new XFTY_DummyDefaultValueUniqueEmail('test.contact'))
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

    private class CaseProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template = new XFTY_DummySObjectMasterTemplate(Case.Id)
                .put(Case.Subject, new XFTY_DummyDefaultValueIncrementingString('Case'))
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
}

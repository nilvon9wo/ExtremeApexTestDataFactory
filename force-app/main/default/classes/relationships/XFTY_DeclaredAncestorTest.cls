/**
 * Declared shared ancestors: `XFTY_SharedAncestor.declared(name)` +
 * `.require(...)` + the S0-S2 batched pre-phase.
 */
@IsTest
private class XFTY_DeclaredAncestorTest {

    private static final XFTY_LookupKeyIntf LEVEL1_KEY = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'level1');

    // Basic -------------------------------------------------------------------

    @IsTest
    static void aRequiredDeclaredAncestorIsSharedByEveryChildInOneInsert() {
        XFTY_SharedAncestor.declared('hq').of(new Account(Name = 'HQ'));
        XFTY_SharedAncestor.require('hq');

        Integer dmlBefore;
        List<Contact> contacts;
        Test.startTest();
        dmlBefore = Limits.getDmlStatements();
        contacts = (List<Contact>) new XFTY_DummySObjectProvider(Contact.SObjectType, new ContactUnderHqLookup())
                .setQuantityPerTemplate(5)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .supplyList();
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Account]);
        Account hq = [SELECT Id, Name FROM Account];
        System.assertEquals('HQ', hq.Name);
        for (Contact contact : contacts) {
            System.assertEquals(hq.Id, contact.AccountId);
        }
        // the HQ Account + the 5 Contacts = 2 insert statements, not 6
        System.assert(Limits.getDmlStatements() - dmlBefore <= 3, 'DML frugal: ' + (Limits.getDmlStatements() - dmlBefore));
    }

    @IsTest
    static void reachingADeclaredAncestorTheTestDidNotRequireThrows() {
        XFTY_SharedAncestor.declared('hq').of(new Account(Name = 'HQ'));
        // note: no require('hq')

        try {
            new XFTY_DummySObjectProvider(Contact.SObjectType, new ContactUnderHqLookup())
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supply();
            System.assert(false, 'expected a "not required" error');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('did not require'), e.getMessage());
            System.assert(e.getMessage().contains('hq'), e.getMessage());
        }
    }

    @IsTest
    static void getIdOnADeclaredNotRequiredAncestorThrows() {
        XFTY_SharedAncestor.declared('hq').of(new Account());
        try {
            XFTY_SharedAncestor.getId('hq');
            System.assert(false, 'expected a "not required" error');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('did not require'), e.getMessage());
        }
    }

    // Context / insert mode -------------------------------------------------

    @IsTest
    static void contextModeFixesTheResolutionMode() {
        XFTY_SharedAncestor.declared('hq').of(new Account(Name = 'HQ'));
        XFTY_SharedAncestor.context(XFTY_InsertModeEnum.MOCK).require('hq');

        Test.startTest();
        new XFTY_DummySObjectProvider(Contact.SObjectType, new ContactUnderHqLookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NEVER)   // the call's mode; the ancestor uses MOCK
                .supplyList();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Account], 'MOCK - no DML');
        System.assertNotEquals(null, XFTY_SharedAncestor.getId('hq'), 'but it has a (mock) Id');
    }

    @IsTest
    static void resolveDeclaredLetsGetIdRunBeforeAnySupplyCall() {
        XFTY_SharedAncestor.declared('hq').of(new Account(Name = 'HQ'));
        XFTY_SharedAncestor.context(XFTY_InsertModeEnum.NOW).require('hq');

        Test.startTest();
        XFTY_SharedAncestor.resolveDeclared(new ContactUnderHqLookup());
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Account]);
        System.assertEquals(XFTY_SharedAncestor.getId('hq'), [SELECT Id FROM Account].Id);
    }

    // Nested / deep -------------------------------------------------------

    @IsTest
    static void requiringOneDeclaredAncestorPullsInItsNestedDeclaredAncestors() {
        XFTY_SharedAncestor.declared('root').of(new Account(Name = 'Root'))
                .withKey(XFTY_LookupKey.get(Account.SObjectType));
        XFTY_SharedAncestor.declared('level1').of(new Account(Name = 'Level 1'))
                .withKey(LEVEL1_KEY);
        XFTY_SharedAncestor.require('level1');   // 'root' is only reached through level1's template

        Test.startTest();
        new XFTY_DummySObjectProvider(Contact.SObjectType, new DeepLookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .supplyList();
        Test.stopTest();

        Account root = [SELECT Id FROM Account WHERE Name = 'Root'];
        Account level1 = [SELECT Id, ParentId FROM Account WHERE Name = 'Level 1'];
        System.assertEquals(root.Id, level1.ParentId, 'nested declared ancestor wired');
        System.assertEquals(2, [SELECT COUNT() FROM Account]);
    }

    @IsTest
    static void twoSupplyCallsForDifferentChildrenConvergeOnTheSameDeclaredRoot() {
        XFTY_SharedAncestor.declared('root').of(new Account(Name = 'Singleton Root'));
        XFTY_SharedAncestor.require('root');

        Test.startTest();
        Contact a = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, new ContactUnderRootLookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED).setInsertMode(XFTY_InsertModeEnum.NOW).supply();
        Contact b = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, new ContactUnderRootLookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED).setInsertMode(XFTY_InsertModeEnum.NOW).supply();
        Test.stopTest();

        System.assertEquals(a.AccountId, b.AccountId, 'both chains share the one Root');
        System.assertEquals(1, [SELECT COUNT() FROM Account], 'the singleton Root was inserted once');
    }

    @IsTest
    static void declaredAncestorsInACycleThrow() {
        XFTY_SharedAncestor.declared('a').of(new Account()).withKey(XFTY_FlavouredLookupKey.get(Account.SObjectType, 'a'));
        XFTY_SharedAncestor.declared('b').of(new Account()).withKey(XFTY_FlavouredLookupKey.get(Account.SObjectType, 'b'));
        XFTY_SharedAncestor.require('a');

        try {
            new XFTY_DummySObjectProvider(Contact.SObjectType, new CycleLookup())
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supply();
            System.assert(false, 'expected a cycle error');
        } catch (Exception e) {
            System.assert(e.getMessage().containsIgnoreCase('cycle'), e.getMessage());
        }
    }

    @IsTest
    static void declaredAncestorWorksWithDepthBatchedMainBuild() {
        XFTY_SharedAncestor.declared('hq').of(new Account(Name = 'HQ'));
        XFTY_SharedAncestor.require('hq');

        Test.startTest();
        new XFTY_DummySObjectProvider(Contact.SObjectType, new ContactUnderHqLookup())
                .setQuantityPerTemplate(3)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .depthBatched()
                .supplyList();
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Account]);
        System.assertEquals(3, [SELECT COUNT() FROM Contact]);
    }

    // Path-scoped value + on-demand shared ancestor (no registration) --------

    @IsTest
    static void aPathValueCanWireInAnOnDemandSharedAncestorWithoutRequire() {
        XFTY_SharedAncestor.get('shared-owner').of(new User(
                Alias = 'shOwn', Email = 'sh.owner@example.com', Username = 'sh.owner@example.com.xfty',
                LastName = 'Owner', EmailEncodingKey = 'ISO-8859-1', LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US', TimeZoneSidKey = 'GMT',
                ProfileId = XFTY_DefaultUserDataProvider.profileIdFor('System Administrator')
        ));

        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, new PathLookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .putRequired(
                        new List<SObjectField>{ Contact.AccountId, Account.OwnerId },
                        XFTY_SharedAncestor.get('shared-owner')
                )
                .supplyBundle();

        Account account = (Account) bundle.getBundle(Contact.AccountId).primaryRecords()[0];
        System.assertEquals(XFTY_SharedAncestor.getId('shared-owner'), account.OwnerId,
                'on-demand shared ancestor wired in via a path value, no require() needed');
    }

    // Providers -------------------------------------------------------------

    private class ContactUnderHqLookup implements XFTY_DummySObjectProviderLookupIntf {
        public XFTY_DummySobjectProviderIntf get(SObjectType t) {
            return t == Account.SObjectType ? new XFTY_DefaultAccountDataProvider() : (XFTY_DummySobjectProviderIntf) new ContactSharedParentProvider('hq');
        }
        public XFTY_DummySobjectProviderIntf get(XFTY_LookupKeyIntf k) {
            return this.get(k.getSObjectType());
        }
        public Set<XFTY_LookupKeyIntf> keysFor(SObject s) {
            return new Set<XFTY_LookupKeyIntf>{ XFTY_LookupKey.get(s.getSObjectType()) };
        }
    }

    private class ContactUnderRootLookup implements XFTY_DummySObjectProviderLookupIntf {
        public XFTY_DummySobjectProviderIntf get(SObjectType t) {
            return t == Account.SObjectType ? new XFTY_DefaultAccountDataProvider() : (XFTY_DummySobjectProviderIntf) new ContactSharedParentProvider('root');
        }
        public XFTY_DummySobjectProviderIntf get(XFTY_LookupKeyIntf k) {
            return this.get(k.getSObjectType());
        }
        public Set<XFTY_LookupKeyIntf> keysFor(SObject s) {
            return new Set<XFTY_LookupKeyIntf>{ XFTY_LookupKey.get(s.getSObjectType()) };
        }
    }

    private class DeepLookup implements XFTY_DummySObjectProviderLookupIntf {
        private final Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf> byKey
                = new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                        XFTY_LookupKey.get(Account.SObjectType) => new XFTY_DefaultAccountDataProvider(),
                        LEVEL1_KEY => new AccountWithSharedParentProvider('root'),
                        XFTY_LookupKey.get(Contact.SObjectType) => new ContactSharedParentProvider('level1')
                };
        public XFTY_DummySobjectProviderIntf get(SObjectType t) {
            return this.byKey.get(XFTY_LookupKey.get(t));
        }
        public XFTY_DummySobjectProviderIntf get(XFTY_LookupKeyIntf k) {
            return this.byKey.get(k);
        }
        public Set<XFTY_LookupKeyIntf> keysFor(SObject s) {
            return new Set<XFTY_LookupKeyIntf>{ XFTY_LookupKey.get(s.getSObjectType()) };
        }
    }

    private class CycleLookup implements XFTY_DummySObjectProviderLookupIntf {
        private final Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf> byKey
                = new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                        XFTY_FlavouredLookupKey.get(Account.SObjectType, 'a') => new AccountWithSharedParentProvider('b'),
                        XFTY_FlavouredLookupKey.get(Account.SObjectType, 'b') => new AccountWithSharedParentProvider('a'),
                        XFTY_LookupKey.get(Contact.SObjectType) => new ContactSharedParentProvider('a')
                };
        public XFTY_DummySobjectProviderIntf get(SObjectType t) {
            return this.byKey.get(XFTY_LookupKey.get(t));
        }
        public XFTY_DummySobjectProviderIntf get(XFTY_LookupKeyIntf k) {
            return this.byKey.get(k);
        }
        public Set<XFTY_LookupKeyIntf> keysFor(SObject s) {
            return new Set<XFTY_LookupKeyIntf>{ XFTY_LookupKey.get(s.getSObjectType()) };
        }
    }

    private class PathLookup implements XFTY_DummySObjectProviderLookupIntf {
        private final Map<SObjectType, XFTY_DummySobjectProviderIntf> byType
                = new Map<SObjectType, XFTY_DummySobjectProviderIntf>{
                        Account.SObjectType => new XFTY_DefaultAccountDataProvider(),
                        Contact.SObjectType => new XFTY_DefaultContactDataProvider(),
                        User.SObjectType => new XFTY_DefaultUserDataProvider()
                };
        public XFTY_DummySobjectProviderIntf get(SObjectType t) {
            return this.byType.get(t);
        }
        public XFTY_DummySobjectProviderIntf get(XFTY_LookupKeyIntf k) {
            return this.byType.get(k.getSObjectType());
        }
        public Set<XFTY_LookupKeyIntf> keysFor(SObject s) {
            return new Set<XFTY_LookupKeyIntf>{ XFTY_LookupKey.get(s.getSObjectType()) };
        }
    }

    private class ContactSharedParentProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template;
        ContactSharedParentProvider(String sharedName) {
            this.template = new XFTY_DummySObjectMasterTemplate(Contact.Id)
                    .put(Contact.LastName, new XFTY_DummyDefaultValueIncrementingString('Contact'))
                    .putRequired(Contact.AccountId, XFTY_SharedAncestor.get(sharedName));
        }
        public SObjectField getPrimaryTargetField() {
            return Contact.Id;
        }
        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }
        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext c, List<SObject> t) {
            return XFTY_DummySObjectFactory.createBundle(c, this.template, t);
        }
    }

    private class AccountWithSharedParentProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template;
        AccountWithSharedParentProvider(String sharedParentName) {
            this.template = new XFTY_DummySObjectMasterTemplate(Account.Id)
                    .put(Account.Name, new XFTY_DummyDefaultValueIncrementingString('Acct'))
                    .putRequired(Account.ParentId, XFTY_SharedAncestor.get(sharedParentName));
        }
        public SObjectField getPrimaryTargetField() {
            return Account.Id;
        }
        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }
        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext c, List<SObject> t) {
            return XFTY_DummySObjectFactory.createBundle(c, this.template, t);
        }
    }
}

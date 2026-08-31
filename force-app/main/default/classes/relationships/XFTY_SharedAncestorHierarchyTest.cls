/**
 * Shared ancestors with hierarchies of their own: automatic deep-vs-flat
 * resolution, the depth-batched pre-phase, nested shared ancestors, cycle
 * detection, `resolveNow(...)`, `getOrElse(...)`, and `.depthBatched()` /
 * `DEFERRED` compatibility.
 *
 * See docs/use/shared-ancestors.md.
 */
@IsTest
private class XFTY_SharedAncestorHierarchyTest {

    private static final XFTY_LookupKeyIntf LEVEL1_KEY = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'level1');

    // Flat -----------------------------------------------------------------

    @IsTest
    static void everyChildSharesOneConfiguredAncestorInOneInsert() {
        XFTY_SharedAncestor.get('hq').of(new Account(Name = 'HQ'));

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
        // the HQ Account + the 5 Contacts = a couple of insert statements, not 6
        System.assert(Limits.getDmlStatements() - dmlBefore <= 3, 'DML frugal: ' + (Limits.getDmlStatements() - dmlBefore));
    }

    @IsTest
    static void reachingADeepSharedAncestorResolvesItAutomatically() {
        // no declare, no require - just configure and reference
        XFTY_SharedAncestor.get('root').of(new Account(Name = 'Root'))
                .withKey(XFTY_LookupKey.get(Account.SObjectType));
        XFTY_SharedAncestor.get('level1').of(new Account(Name = 'Level 1')).withKey(LEVEL1_KEY);

        Test.startTest();
        Contact c = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, new DeepLookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .supply();
        Test.stopTest();

        Account root = [SELECT Id FROM Account WHERE Name = 'Root'];
        Account level1 = [SELECT Id, ParentId FROM Account WHERE Name = 'Level 1'];
        System.assertEquals(root.Id, level1.ParentId, 'nested shared ancestor wired');
        System.assertEquals(level1.Id, c.AccountId);
        System.assertEquals(2, [SELECT COUNT() FROM Account]);
    }

    // resolveNow / getId --------------------------------------------------

    @IsTest
    static void getIdBeforeResolutionThrows() {
        XFTY_SharedAncestor.get('hq').of(new Account());
        try {
            XFTY_SharedAncestor.getId('hq');
            System.assert(false, 'expected a "not resolved" error');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('not resolved yet'), e.getMessage());
        }
    }

    @IsTest
    static void resolveNowLetsGetIdRunBeforeAnySupplyCall() {
        XFTY_SharedAncestor.get('hq').of(new Account(Name = 'HQ'));

        Test.startTest();
        XFTY_SharedAncestor.get('hq').resolveNow(new ContactUnderHqLookup(), XFTY_InsertModeEnum.NOW);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Account]);
        System.assertEquals(XFTY_SharedAncestor.getId('hq'), [SELECT Id FROM Account].Id);
    }

    @IsTest
    static void resolveNowWithMockGivesAMockIdAndNoDml() {
        XFTY_SharedAncestor.get('hq').of(new Account(Name = 'HQ'));

        Test.startTest();
        XFTY_SharedAncestor.get('hq').resolveNow(new ContactUnderHqLookup(), XFTY_InsertModeEnum.MOCK);
        // the call's own mode differs - the ancestor keeps the mock Id it already has
        new XFTY_DummySObjectProvider(Contact.SObjectType, new ContactUnderHqLookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NEVER)
                .supplyList();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Account], 'MOCK - no DML');
        System.assertNotEquals(null, XFTY_SharedAncestor.getId('hq'), 'but it has a (mock) Id');
    }

    // Nested / deep ------------------------------------------------------

    @IsTest
    static void twoSupplyCallsForDifferentChildrenConvergeOnTheSameRoot() {
        XFTY_SharedAncestor.get('root').of(new Account(Name = 'Singleton Root'));

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
    static void deepSharedAncestorChainStaysDmlFrugal() {
        XFTY_SharedAncestor.get('root').of(new Account(Name = 'Root'))
                .withKey(XFTY_LookupKey.get(Account.SObjectType));
        XFTY_SharedAncestor.get('level1').of(new Account(Name = 'Level 1')).withKey(LEVEL1_KEY);

        Integer dmlBefore;
        Test.startTest();
        dmlBefore = Limits.getDmlStatements();
        new XFTY_DummySObjectProvider(Contact.SObjectType, new DeepLookup())
                .setQuantityPerTemplate(4)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .supplyList();
        Test.stopTest();

        Integer dml = Limits.getDmlStatements() - dmlBefore;
        // root, level1, 4 contacts - a handful of statements, not one per record per level
        System.assert(dml <= 4, 'deep chain DML: ' + dml);
        System.assertEquals(2, [SELECT COUNT() FROM Account]);
        System.assertEquals(4, [SELECT COUNT() FROM Contact]);
    }

    // Cycles -----------------------------------------------------------

    @IsTest
    static void sharedAncestorsInACycleThrow() {
        XFTY_SharedAncestor.get('a').of(new Account()).withKey(XFTY_FlavouredLookupKey.get(Account.SObjectType, 'a'));
        XFTY_SharedAncestor.get('b').of(new Account()).withKey(XFTY_FlavouredLookupKey.get(Account.SObjectType, 'b'));

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
    static void preRegisteringOneSideBreaksACycle() {
        XFTY_SharedAncestor.get('a').of(new Account())
                .withKey(XFTY_FlavouredLookupKey.get(Account.SObjectType, 'a'));
        XFTY_SharedAncestor.get('b').of(new Account())
                .withKey(XFTY_FlavouredLookupKey.get(Account.SObjectType, 'b'));
        // break the a<->b cycle by handing 'b' a record up front
        Account existingB = new Account(Name = 'Pre-made B', Id = XFTY_IdMocker.generateId(Account.SObjectType));
        XFTY_SharedAncestor.put('b', existingB);

        Test.startTest();
        Contact c = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, new CycleLookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        System.assertNotEquals(null, c.AccountId, 'the chain resolved - the cycle was broken');
        System.assertEquals(existingB.Id, XFTY_SharedAncestor.getId('b'));
    }

    // Batched / deferred main build ------------------------------------

    @IsTest
    static void worksWithDepthBatchedMainBuild() {
        XFTY_SharedAncestor.get('hq').of(new Account(Name = 'HQ'));

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

    @IsTest
    static void worksWithDeferredMainBuild() {
        XFTY_SharedAncestor.get('hq').of(new Account(Name = 'HQ'));

        Test.startTest();
        new XFTY_DummySObjectProvider(Contact.SObjectType, new ContactUnderHqLookup())
                .setQuantityPerTemplate(2)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                .supplyList();
        XFTY_DeferredInserter.flush();
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Account], 'the shared ancestor resolved up front');
        System.assertEquals(2, [SELECT COUNT() FROM Contact]);
        Account hq = [SELECT Id FROM Account];
        for (Contact c : [SELECT AccountId FROM Contact]) {
            System.assertEquals(hq.Id, c.AccountId);
        }
    }

    // getOrElse ------------------------------------------------------

    @IsTest
    static void getOrElseConfiguresOnlyWhenUnconfigured() {
        XFTY_SharedAncestor.getOrElse('hq', new Account(Name = 'First'));
        XFTY_SharedAncestor.getOrElse('hq', new Account(Name = 'Second'));   // ignored

        Test.startTest();
        new XFTY_DummySObjectProvider(Contact.SObjectType, new ContactUnderHqLookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .supply();
        Test.stopTest();

        System.assertEquals('First', [SELECT Name FROM Account].Name);
    }

    // suppliedBy - the full Provider API describes the shared record ------

    @IsTest
    static void suppliedByShapesTheSharedRecordWithValueStrategies() {
        XFTY_SharedAncestor.get('hq').suppliedBy(
                new XFTY_DummySObjectProvider(Account.SObjectType, new ContactUnderHqLookup())
                        .setOverrideTemplate(new Account(Name = 'HQ Ltd'))
                        .put(Account.Site, 'Berlin')
        );

        Test.startTest();
        Contact c = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, new ContactUnderHqLookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .supply();
        Test.stopTest();

        Account hq = [SELECT Name, Site FROM Account];
        System.assertEquals('HQ Ltd', hq.Name);
        System.assertEquals('Berlin', hq.Site, 'a put(...) strategy on the suppliedBy Provider landed on the shared record');
        System.assertEquals(hq.Id, c.AccountId);
    }

    @IsTest
    static void suppliedByCanShapeTheSharedRecordsOwnAncestors() {
        XFTY_SharedAncestor.get('hq').suppliedBy(
                new XFTY_DummySObjectProvider(Account.SObjectType, new ContactUnderHqLookup())
                        .setOverrideTemplate(new Account(Name = 'HQ'))
                        .putRequired(Account.ParentId, new XFTY_DummyDefaultRelationship(new Account(Name = 'HQ Parent')))
                        .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
        );

        Test.startTest();
        new XFTY_DummySObjectProvider(Contact.SObjectType, new ContactUnderHqLookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .supply();
        Test.stopTest();

        Account hq = [SELECT ParentId FROM Account WHERE Name = 'HQ'];
        Account parent = [SELECT Id FROM Account WHERE Name = 'HQ Parent'];
        System.assertEquals(parent.Id, hq.ParentId, 'the shared record got the parent configured via suppliedBy');
        System.assertEquals(2, [SELECT COUNT() FROM Account]);
    }

    @IsTest
    static void suppliedByRejectsKnobsThatMakeNoSenseForOneRecord() {
        XFTY_SharedAncestor.get('hq').suppliedBy(
                new XFTY_DummySObjectProvider(Account.SObjectType, new ContactUnderHqLookup())
                        .setOverrideTemplate(new Account(Name = 'HQ'))
                        .setQuantityPerTemplate(2)
        );
        try {
            new XFTY_DummySObjectProvider(Contact.SObjectType, new ContactUnderHqLookup())
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supply();
            System.assert(false, 'expected a "one record" error');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('one record'), e.getMessage());
        }
    }

    @IsTest
    static void suppliedByRejectsAnExplicitInsertModeOnTheProvider() {
        XFTY_SharedAncestor.get('hq').suppliedBy(
                new XFTY_DummySObjectProvider(Account.SObjectType, new ContactUnderHqLookup())
                        .setOverrideTemplate(new Account(Name = 'HQ'))
                        .setInsertMode(XFTY_InsertModeEnum.NOW)
        );
        try {
            new XFTY_DummySObjectProvider(Contact.SObjectType, new ContactUnderHqLookup())
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supply();
            System.assert(false, 'expected an insert-mode error');
        } catch (Exception e) {
            System.assert(e.getMessage().containsIgnoreCase('insert mode') || e.getMessage().contains('setInsertMode'),
                    e.getMessage());
        }
    }

    @IsTest
    static void suppliedByAndOfAreMutuallyExclusive() {
        try {
            XFTY_SharedAncestor.get('x').of(new Account()).suppliedBy(
                    new XFTY_DummySObjectProvider(Account.SObjectType, new ContactUnderHqLookup()));
            System.assert(false, 'expected a mutual-exclusion error');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('not both'), e.getMessage());
        }
        try {
            XFTY_SharedAncestor.get('y')
                    .suppliedBy(new XFTY_DummySObjectProvider(Account.SObjectType, new ContactUnderHqLookup()))
                    .of(new Account());
            System.assert(false, 'expected a mutual-exclusion error');
        } catch (Exception e) {
            System.assert(e.getMessage().containsIgnoreCase('suppliedby'), e.getMessage());
        }
    }

    // Path-scoped value + shared ancestor, no special setup ------------

    @IsTest
    static void aPathValueCanWireInASharedAncestorWithNoSpecialSetup() {
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
                'shared ancestor wired in via a path value, nothing to declare');
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

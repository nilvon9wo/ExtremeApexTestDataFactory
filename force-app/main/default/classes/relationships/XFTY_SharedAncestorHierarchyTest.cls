/**
 * Shared ancestors that have hierarchies of their own: automatic deep-vs-flat
 * resolution, the depth-batched pre-phase, nested shared ancestors, cycle
 * detection, `resolveNow(...)`, `getOrElse(...)`, `suppliedBy(...)`, and the
 * `.depthBatched()` / `DEFERRED` main build. Also the end-to-end proof: a
 * three-level all-shared spine, built once, wired everywhere.
 *
 * The plain one-record case is in `XFTY_SharedAncestorTest`; volume in
 * `XFTY_SharedAncestorLoadTest`. See docs/use/shared-ancestors.md.
 */
@IsTest
private class XFTY_SharedAncestorHierarchyTest {

    private static final XFTY_LookupKeyIntf LEVEL1_KEY = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'level1');
    private static final XFTY_LookupKeyIntf KEY_A = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'a');
    private static final XFTY_LookupKeyIntf KEY_B = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'b');

    // Flat --------------------------------------------------------------------

    @IsTest
    static void everyChildSharesOneConfiguredAncestor() {
        XFTY_SharedAncestor.get('hq').of(new Account(Name = 'HQ'));

        Integer statementsBefore;
        List<Contact> contacts;
        Test.startTest();
        statementsBefore = Limits.getDmlStatements();
        contacts = (List<Contact>) new XFTY_DummySObjectProvider(Contact.SObjectType, contactsUnder('hq'))
                .setQuantityPerTemplate(5)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .supplyList();
        Test.stopTest();

        Integer statements = Limits.getDmlStatements() - statementsBefore;
        Account hq = [SELECT Id, Name FROM Account];
        Assert.areEqual('HQ', hq.Name);
        Assert.areEqual(1, [SELECT COUNT() FROM Account]);
        for (Contact each : contacts) {
            Assert.areEqual(hq.Id, each.AccountId);
        }
        Assert.isTrue(statements <= 3, 'one Account insert + one Contact insert, not one per record: ' + statements);
    }

    // Deep ------------------------------------------------------------------

    @IsTest
    static void aDeepSharedAncestorResolvesAutomatically() {
        XFTY_SharedAncestor.get('root').of(new Account(Name = 'Root'))
                .withKey(XFTY_LookupKey.get(Account.SObjectType));
        XFTY_SharedAncestor.get('level1').of(new Account(Name = 'Level 1'))
                .withKey(LEVEL1_KEY);

        Test.startTest();
        Contact leaf = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, deepChainLookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .supply();
        Test.stopTest();

        Account root = [SELECT Id FROM Account WHERE Name = 'Root'];
        Account level1 = [SELECT Id, ParentId FROM Account WHERE Name = 'Level 1'];
        Assert.areEqual(root.Id, level1.ParentId, 'the nested shared ancestor was wired');
        Assert.areEqual(level1.Id, leaf.AccountId);
        Assert.areEqual(2, [SELECT COUNT() FROM Account]);
    }

    @IsTest
    static void aDeepChainStaysDmlFrugal() {
        XFTY_SharedAncestor.get('root').of(new Account(Name = 'Root'))
                .withKey(XFTY_LookupKey.get(Account.SObjectType));
        XFTY_SharedAncestor.get('level1').of(new Account(Name = 'Level 1'))
                .withKey(LEVEL1_KEY);

        Integer statementsBefore;
        Test.startTest();
        statementsBefore = Limits.getDmlStatements();
        new XFTY_DummySObjectProvider(Contact.SObjectType, deepChainLookup())
                .setQuantityPerTemplate(4)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .supplyList();
        Test.stopTest();

        Integer statements = Limits.getDmlStatements() - statementsBefore;
        Assert.isTrue(statements <= 4, 'root + level1 + four Contacts should be a handful of statements: ' + statements);
        Assert.areEqual(2, [SELECT COUNT() FROM Account]);
        Assert.areEqual(4, [SELECT COUNT() FROM Contact]);
    }

    @IsTest
    static void twoSupplyCallsConvergeOnTheSameRoot() {
        XFTY_SharedAncestor.get('root').of(new Account(Name = 'Singleton Root'));

        Test.startTest();
        Contact first = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, contactsUnder('root'))
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .supply();
        Contact second = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, contactsUnder('root'))
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .supply();
        Test.stopTest();

        Assert.areEqual(first.AccountId, second.AccountId, 'both calls share the one Root');
        Assert.areEqual(1, [SELECT COUNT() FROM Account]);
    }

    // resolveNow / getId --------------------------------------------------

    @IsTest
    static void getIdBeforeResolutionThrows() {
        XFTY_SharedAncestor.get('hq').of(new Account());

        try {
            XFTY_SharedAncestor.getId('hq');
            Assert.fail('expected a "not resolved" error');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            Assert.isTrue(ex.getMessage().contains('not resolved yet'), ex.getMessage());
        }
    }

    @IsTest
    static void resolveNowLetsGetIdRunBeforeAnySupplyCall() {
        XFTY_SharedAncestor.get('hq').of(new Account(Name = 'HQ'));

        Test.startTest();
        XFTY_SharedAncestor.get('hq').resolveNow(contactsUnder('hq'), XFTY_InsertModeEnum.NOW);
        Test.stopTest();

        Assert.areEqual(1, [SELECT COUNT() FROM Account]);
        Assert.areEqual([SELECT Id FROM Account].Id, XFTY_SharedAncestor.getId('hq'));
    }

    @IsTest
    static void resolveNowPinsTheAncestorsOwnModeAheadOfTheCall() {
        XFTY_SharedAncestor.get('hq').of(new Account(Name = 'HQ'));

        Test.startTest();
        XFTY_SharedAncestor.get('hq').resolveNow(contactsUnder('hq'), XFTY_InsertModeEnum.MOCK);
        new XFTY_DummySObjectProvider(Contact.SObjectType, contactsUnder('hq'))
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NEVER)
                .supplyList();
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM Account], 'MOCK - no DML');
        Assert.isNotNull(XFTY_SharedAncestor.getId('hq'), 'but it has a mock Id');
    }

    @IsTest
    static void getIdFeedsAnOverrideTemplateDirectly() {
        XFTY_SharedAncestor.get('hq').of(new Account(Name = 'HQ'));
        XFTY_SharedAncestor.get('hq').resolveNow(contactsUnder('hq'), XFTY_InsertModeEnum.NOW);

        Test.startTest();
        Contact leaf = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, contactsUnder('hq'))
                .setOverrideTemplate(new Contact(LastName = 'Direct', AccountId = XFTY_SharedAncestor.getId('hq')))
                .setInclusivity(XFTY_InsertInclusivityEnum.NONE)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .supply();
        Test.stopTest();

        Assert.areEqual(1, [SELECT COUNT() FROM Account], 'only the record resolveNow built');
        Assert.areEqual(XFTY_SharedAncestor.getId('hq'), leaf.AccountId);
    }

    // getOrElse ---------------------------------------------------------

    @IsTest
    static void getOrElseConfiguresOnlyWhenUnconfigured() {
        XFTY_SharedAncestor.getOrElse('hq', new Account(Name = 'First'));
        XFTY_SharedAncestor.getOrElse('hq', new Account(Name = 'Second'));

        Test.startTest();
        new XFTY_DummySObjectProvider(Contact.SObjectType, contactsUnder('hq'))
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .supply();
        Test.stopTest();

        Assert.areEqual('First', [SELECT Name FROM Account].Name, 'the second getOrElse was ignored');
    }

    // Cycles ---------------------------------------------------------

    @IsTest
    static void sharedAncestorsInACycleThrow() {
        XFTY_SharedAncestor.get('a').of(new Account()).withKey(KEY_A);
        XFTY_SharedAncestor.get('b').of(new Account()).withKey(KEY_B);

        try {
            new XFTY_DummySObjectProvider(Contact.SObjectType, cycleLookup())
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supply();
            Assert.fail('expected a cycle error');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            Assert.isTrue(ex.getMessage().containsIgnoreCase('cycle'), ex.getMessage());
        }
    }

    @IsTest
    static void preRegisteringOneSideBreaksACycle() {
        XFTY_SharedAncestor.get('a').of(new Account()).withKey(KEY_A);
        XFTY_SharedAncestor.get('b').of(new Account()).withKey(KEY_B);
        Account premadeB = new Account(Name = 'Pre-made B', Id = XFTY_IdMocker.generateId(Account.SObjectType));
        XFTY_SharedAncestor.put('b', premadeB);

        Test.startTest();
        Contact leaf = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, cycleLookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        Assert.isNotNull(leaf.AccountId, 'the chain resolved because the cycle was broken');
        Assert.areEqual(premadeB.Id, XFTY_SharedAncestor.getId('b'));
    }

    // Batched / deferred main build ----------------------------------

    @IsTest
    static void resolvesUpFrontUnderDepthBatched() {
        XFTY_SharedAncestor.get('hq').of(new Account(Name = 'HQ'));

        Test.startTest();
        new XFTY_DummySObjectProvider(Contact.SObjectType, contactsUnder('hq'))
                .setQuantityPerTemplate(3)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .depthBatched()
                .supplyList();
        Test.stopTest();

        Assert.areEqual(1, [SELECT COUNT() FROM Account]);
        Assert.areEqual(3, [SELECT COUNT() FROM Contact]);
    }

    @IsTest
    static void resolvesUpFrontUnderDeferred() {
        XFTY_SharedAncestor.get('hq').of(new Account(Name = 'HQ'));

        Test.startTest();
        new XFTY_DummySObjectProvider(Contact.SObjectType, contactsUnder('hq'))
                .setQuantityPerTemplate(2)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
                .supplyList();
        XFTY_DeferredInserter.flush();
        Test.stopTest();

        Account hq = [SELECT Id FROM Account];
        Assert.areEqual(1, [SELECT COUNT() FROM Account], 'the shared ancestor resolved before the deferred flush');
        Assert.areEqual(2, [SELECT COUNT() FROM Contact]);
        for (Contact each : [SELECT AccountId FROM Contact]) {
            Assert.areEqual(hq.Id, each.AccountId);
        }
    }

    // suppliedBy - the full generation API for one shared record --------

    @IsTest
    static void suppliedByShapesTheSharedRecordWithValueStrategies() {
        XFTY_SharedAncestor.get('hq').suppliedBy(
                accountProvider()
                        .setOverrideTemplate(new Account(Name = 'HQ Ltd'))
                        .put(Account.Site, 'Berlin')
                        .put(Account.Description, new XFTY_CopyFromSibling(Account.Name))
        );

        Test.startTest();
        Contact leaf = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, contactsUnder('hq'))
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .supply();
        Test.stopTest();

        Account hq = [SELECT Id, Name, Site, Description FROM Account];
        Assert.areEqual('HQ Ltd', hq.Name);
        Assert.areEqual('Berlin', hq.Site, 'a literal strategy on the suppliedBy Provider landed on the shared record');
        Assert.areEqual('HQ Ltd', hq.Description, 'a context-aware value on the suppliedBy Provider ran on the shared record');
        Assert.areEqual(hq.Id, leaf.AccountId);
    }

    @IsTest
    static void suppliedByShapesTheSharedRecordsOwnAncestor() {
        XFTY_SharedAncestor.get('hq').suppliedBy(
                accountProvider()
                        .setOverrideTemplate(new Account(Name = 'HQ'))
                        .putRequired(Account.ParentId, new XFTY_DummyDefaultRelationship(new Account(Name = 'HQ Parent')))
                        .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
        );

        Test.startTest();
        new XFTY_DummySObjectProvider(Contact.SObjectType, contactsUnder('hq'))
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .supply();
        Test.stopTest();

        Account hq = [SELECT ParentId FROM Account WHERE Name = 'HQ'];
        Account parent = [SELECT Id FROM Account WHERE Name = 'HQ Parent'];
        Assert.areEqual(parent.Id, hq.ParentId, 'the shared record got the parent configured via suppliedBy');
        Assert.areEqual(2, [SELECT COUNT() FROM Account]);
    }

    @IsTest
    static void suppliedByRejectsAKnobThatMeansMoreThanOneRecord() {
        XFTY_SharedAncestor.get('hq').suppliedBy(
                accountProvider()
                        .setOverrideTemplate(new Account(Name = 'HQ'))
                        .setQuantityPerTemplate(2)
        );

        try {
            supplyOneContactUnder('hq');
            Assert.fail('expected a "one record" error');
        } catch (XFTY_DummySObjectProvider.SanityException ex) {
            Assert.isTrue(ex.getMessage().contains('one record'), ex.getMessage());
        }
    }

    @IsTest
    static void suppliedByRejectsAnExplicitInsertModeOnTheProvider() {
        XFTY_SharedAncestor.get('hq').suppliedBy(
                accountProvider()
                        .setOverrideTemplate(new Account(Name = 'HQ'))
                        .setInsertMode(XFTY_InsertModeEnum.NOW)
        );

        try {
            supplyOneContactUnder('hq');
            Assert.fail('expected an insert-mode error');
        } catch (XFTY_DummySObjectProvider.SanityException ex) {
            Assert.isTrue(ex.getMessage().contains('setInsertMode'), ex.getMessage());
        }
    }

    @IsTest
    static void suppliedByAndOfAreMutuallyExclusive() {
        try {
            XFTY_SharedAncestor.get('x').of(new Account()).suppliedBy(accountProvider());
            Assert.fail('expected a mutual-exclusion error');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            Assert.isTrue(ex.getMessage().contains('not both'), ex.getMessage());
        }
    }

    @IsTest
    static void ofAfterSuppliedByIsAlsoMutuallyExclusive() {
        try {
            XFTY_SharedAncestor.get('y').suppliedBy(accountProvider()).of(new Account());
            Assert.fail('expected a mutual-exclusion error');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            Assert.isTrue(ex.getMessage().containsIgnoreCase('suppliedby'), ex.getMessage());
        }
    }

    // Path-scoped value wires in a shared ancestor -------------------

    @IsTest
    static void aPathValueCanWireInASharedAncestorWithNoSpecialSetup() {
        XFTY_SharedAncestor.get('shared-owner').of(adminUser());

        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, defaultTypesLookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .putRequired(
                        new List<SObjectField>{ Contact.AccountId, Account.OwnerId },
                        XFTY_SharedAncestor.get('shared-owner')
                )
                .supplyBundle();

        Account account = (Account) bundle.getBundle(Contact.AccountId).primaryRecords()[0];
        Assert.areEqual(XFTY_SharedAncestor.getId('shared-owner'), account.OwnerId,
                'the shared ancestor was wired in through a path value, nothing declared');
    }

    // Cross-SObject - one record, two child types -----------------

    @IsTest
    static void oneSharedRecordServesTwoDifferentChildSObjects() {
        XFTY_SharedAncestor.get('hq').of(new Account(Name = 'Shared HQ'));
        XFTY_DummySObjectProviderLookupIntf lookup = XFTY_ProviderLookups.of(
                new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                        XFTY_LookupKey.get(Account.SObjectType) => new XFTY_DefaultAccountDataProvider(),
                        XFTY_LookupKey.get(Contact.SObjectType) => childProvider(Contact.Id, Contact.AccountId, Contact.LastName, 'hq'),
                        XFTY_LookupKey.get(Case.SObjectType) => childProvider(Case.Id, Case.AccountId, null, 'hq')
                }
        );

        Test.startTest();
        Contact contact = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .supply();
        Case supportCase = (Case) new XFTY_DummySObjectProvider(Case.SObjectType, lookup)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .supply();
        Test.stopTest();

        Assert.areEqual(1, [SELECT COUNT() FROM Account], 'one HQ for both the Contact and the Case');
        Assert.areEqual(contact.AccountId, supportCase.AccountId);
        Assert.areEqual(XFTY_SharedAncestor.getId('hq'), supportCase.AccountId);
    }

    // End to end - a three-level all-shared spine -------------------

    @IsTest
    static void anAllSharedSpineIsBuiltOnceAndEveryLeafLandsOnIt() {
        configureAllSharedSpine();

        Test.startTest();
        List<Contact> east = supplyContactsUnderRegion(3);
        List<Contact> west = supplyContactsUnderRegion(2);
        Test.stopTest();

        Account root = [SELECT Id FROM Account WHERE Name = 'Global Root'];
        Account division = [SELECT Id, ParentId FROM Account WHERE Name = 'Division'];
        Account region = [SELECT Id, ParentId FROM Account WHERE Name = 'Region'];

        Assert.areEqual(3, [SELECT COUNT() FROM Account], 'one row per shared level, no matter the leaves or calls');
        Assert.areEqual(root.Id, division.ParentId, 'division -> root');
        Assert.areEqual(division.Id, region.ParentId, 'region -> division');
        for (Contact each : east) {
            Assert.areEqual(region.Id, each.AccountId);
        }
        for (Contact each : west) {
            Assert.areEqual(region.Id, each.AccountId);
        }
        Assert.areEqual(root.Id, XFTY_SharedAncestor.getId('root'));
        Assert.areEqual(division.Id, XFTY_SharedAncestor.getId('division'));
        Assert.areEqual(region.Id, XFTY_SharedAncestor.getId('region'));
    }

    @IsTest
    static void anAllSharedSpineIsReachableAllTheWayDownTheBundle() {
        configureAllSharedSpine();

        Test.startTest();
        XFTY_DummySObjectBundle leaf = new XFTY_DummySObjectProvider(Contact.SObjectType, contactsUnder('region'))
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .supplyBundle();
        Test.stopTest();

        XFTY_DummySObjectBundle regionBundle = leaf.getBundle(Contact.AccountId);
        XFTY_DummySObjectBundle divisionBundle = regionBundle.getBundle(Account.ParentId);
        XFTY_DummySObjectBundle rootBundle = divisionBundle.getBundle(Account.ParentId);

        Assert.areEqual('Region', firstAccount(regionBundle).Name);
        Assert.areEqual('Division', firstAccount(divisionBundle).Name, 'invariant 4: the shared record is present two levels down');
        Assert.areEqual('Global Root', firstAccount(rootBundle).Name, 'and three levels down');
    }

    // Fixture -----------------------------------------------------

    private static void configureAllSharedSpine() {
        XFTY_SharedAncestor.get('root').of(new Account(Name = 'Global Root'));
        XFTY_SharedAncestor.get('division').suppliedBy(
                accountProvider()
                        .setOverrideTemplate(new Account(Name = 'Division'))
                        .putRequired(Account.ParentId, XFTY_SharedAncestor.get('root'))
                        .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
        );
        XFTY_SharedAncestor.get('region').suppliedBy(
                accountProvider()
                        .setOverrideTemplate(new Account(Name = 'Region'))
                        .putRequired(Account.ParentId, XFTY_SharedAncestor.get('division'))
                        .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
        );
    }

    private static List<Contact> supplyContactsUnderRegion(Integer howMany) {
        return (List<Contact>) new XFTY_DummySObjectProvider(Contact.SObjectType, contactsUnder('region'))
                .setQuantityPerTemplate(howMany)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .supplyList();
    }

    private static void supplyOneContactUnder(String sharedName) {
        new XFTY_DummySObjectProvider(Contact.SObjectType, contactsUnder(sharedName))
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
    }

    private static Account firstAccount(XFTY_DummySObjectBundle bundle) {
        return (Account) bundle.primaryRecords()[0];
    }

    private static User adminUser() {
        return new User(
                Alias = 'shOwn', Email = 'sh.owner@example.com', Username = 'sh.owner@example.com.xfty',
                LastName = 'Owner', EmailEncodingKey = 'ISO-8859-1', LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US', TimeZoneSidKey = 'GMT',
                ProfileId = XFTY_DefaultUserDataProvider.profileIdFor('System Administrator')
        );
    }

    // Fixture - lookups + Provider doubles --------------------------

    private static XFTY_DummySObjectProvider accountProvider() {
        return new XFTY_DummySObjectProvider(Account.SObjectType, defaultTypesLookup());
    }

    /** Accounts + a Contact Provider whose only lookup is a required shared ancestor. */
    private static XFTY_DummySObjectProviderLookupIntf contactsUnder(String sharedName) {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Account.SObjectType) => new XFTY_DefaultAccountDataProvider(),
                XFTY_LookupKey.get(Contact.SObjectType) => childProvider(Contact.Id, Contact.AccountId, Contact.LastName, sharedName)
        });
    }

    /** Contact -> shared 'level1'; 'level1' Account -> shared 'root'; plain Accounts for 'root'. */
    private static XFTY_DummySObjectProviderLookupIntf deepChainLookup() {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Account.SObjectType) => new XFTY_DefaultAccountDataProvider(),
                LEVEL1_KEY => childProvider(Account.Id, Account.ParentId, Account.Name, 'root'),
                XFTY_LookupKey.get(Contact.SObjectType) => childProvider(Contact.Id, Contact.AccountId, Contact.LastName, 'level1')
        });
    }

    /** 'a' Account -> shared 'b'; 'b' Account -> shared 'a'; Contact -> shared 'a'. */
    private static XFTY_DummySObjectProviderLookupIntf cycleLookup() {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                KEY_A => childProvider(Account.Id, Account.ParentId, Account.Name, 'b'),
                KEY_B => childProvider(Account.Id, Account.ParentId, Account.Name, 'a'),
                XFTY_LookupKey.get(Contact.SObjectType) => childProvider(Contact.Id, Contact.AccountId, Contact.LastName, 'a')
        });
    }

    private static XFTY_DummySObjectProviderLookupIntf defaultTypesLookup() {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Account.SObjectType) => new XFTY_DefaultAccountDataProvider(),
                XFTY_LookupKey.get(Contact.SObjectType) => new XFTY_DefaultContactDataProvider(),
                XFTY_LookupKey.get(User.SObjectType) => new XFTY_DefaultUserDataProvider()
        });
    }

    private static XFTY_DummySobjectProviderIntf childProvider(
            SObjectField primaryField, SObjectField lookupField, SObjectField requiredLabelField, String sharedName
    ) {
        return new ChildOfSharedProvider(primaryField, lookupField, requiredLabelField, sharedName);
    }

    /** A Provider with one required lookup to a named shared ancestor, plus the label field its insert needs. */
    private class ChildOfSharedProvider implements XFTY_DummySobjectProviderIntf {
        private final SObjectField primaryField;
        private final XFTY_DummySObjectMasterTemplate template;

        private ChildOfSharedProvider(
                SObjectField primaryField, SObjectField lookupField, SObjectField requiredLabelField, String sharedName
        ) {
            this.primaryField = primaryField;
            this.template = new XFTY_DummySObjectMasterTemplate(primaryField)
                    .putRequired(lookupField, XFTY_SharedAncestor.get(sharedName));
            if (requiredLabelField != null) {
                this.template.put(requiredLabelField, new XFTY_DummyDefaultValueIncrementingString('X'));
            }
        }

        public SObjectField getPrimaryTargetField() {
            return this.primaryField;
        }

        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }

        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext context, List<SObject> templates) {
            return XFTY_DummySObjectFactory.createBundle(context, this.template, templates);
        }
    }
}

/**
 * Shared ancestors that have hierarchies of their own: automatic deep-vs-flat
 * resolution, the depth-batched pre-phase, nested shared ancestors, cycle
 * detection, `resolveNow(...)`, `putIfAbsent(...)`, `put(name, provider)`, and the
 * `.depthBatched()` / `DEFERRED` main build. Also the end-to-end proof: a
 * three-level all-shared spine, built once, wired everywhere.
 *
 * The plain one-record case is in `XFTY_SharedAncestorTest`; DML volume and
 * frugality in `XFTY_SharedAncestorLoadTest`. See docs/use/shared-ancestors.md.
 */
@IsTest
private class XFTY_SharedAncestorHierarchyTest {

    private static final XFTY_LookupKeyIntf LEVEL1_KEY = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'level1');
    private static final XFTY_LookupKeyIntf KEY_A = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'a');
    private static final XFTY_LookupKeyIntf KEY_B = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'b');

    // Flat --------------------------------------------------------------------

    @IsTest
    static void everyChildSharesOneConfiguredAncestor() {
        // Arrange
        XFTY_SharedAncestor.put('hq', new Account(Name = 'HQ'));

        // Act
        List<Contact> contacts;
        Test.startTest();
        contacts = supplyContactsUnder('hq', 5, XFTY_InsertModeEnum.NOW);
        Test.stopTest();

        // Assert
        Account sharedHq = [SELECT Id, Name FROM Account];
        Assert.areEqual('HQ', sharedHq.Name);
        Assert.areEqual(1, [SELECT COUNT() FROM Account], 'one shared HQ, not one per Contact');
        for (Contact leaf : contacts) {
            Assert.areEqual(sharedHq.Id, leaf.AccountId);
        }
    }

    // Deep ------------------------------------------------------------------

    @IsTest
    static void aDeepSharedAncestorResolvesAutomatically() {
        // Arrange
        configureDeepChain();

        // Act
        Contact leaf;
        Test.startTest();
        leaf = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, deepChainLookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .supply();
        Test.stopTest();

        // Assert
        Account root = [SELECT Id FROM Account WHERE Name = 'Root'];
        Account level1 = [SELECT Id, ParentId FROM Account WHERE Name = 'Level 1'];
        Assert.areEqual(root.Id, level1.ParentId, 'the nested shared ancestor was wired');
        Assert.areEqual(level1.Id, leaf.AccountId);
        Assert.areEqual(2, [SELECT COUNT() FROM Account], 'one row per shared level');
    }

    @IsTest
    static void aDeepChainStaysDmlFrugal() {
        // Arrange
        configureDeepChain();

        // Act
        Integer statements;
        Test.startTest();
        statements = dmlStatementsToSupply(4, deepChainLookup());
        Test.stopTest();

        // Assert
        Assert.isTrue(statements <= 4, 'root + level1 + four Contacts is a handful of statements, not one per record: ' + statements);
        Assert.areEqual(2, [SELECT COUNT() FROM Account]);
        Assert.areEqual(4, [SELECT COUNT() FROM Contact]);
    }

    @IsTest
    static void twoSupplyCallsConvergeOnTheSameRoot() {
        // Arrange
        XFTY_SharedAncestor.put('root', new Account(Name = 'Singleton Root'));

        // Act - two independent calls that should land on the same shared Root
        Contact fromFirstCall;
        Contact fromSecondCall;
        Test.startTest();
        fromFirstCall = supplyOneContactUnder('root', XFTY_InsertModeEnum.NOW);
        fromSecondCall = supplyOneContactUnder('root', XFTY_InsertModeEnum.NOW);
        Test.stopTest();

        // Assert
        Assert.areEqual(fromFirstCall.AccountId, fromSecondCall.AccountId, 'both calls share the one Root');
        Assert.areEqual(1, [SELECT COUNT() FROM Account]);
    }

    // resolveNow / getId --------------------------------------------------

    @IsTest
    static void getIdBeforeResolutionThrows() {
        // Arrange
        XFTY_SharedAncestor.put('hq', new Account());

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        try {
            XFTY_SharedAncestor.getId('hq');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }

        // Assert
        Assert.isNotNull(thrown, 'getId before resolution must throw, not return null');
        Assert.isTrue(thrown.getMessage().contains('not resolved yet'), thrown.getMessage());
    }

    @IsTest
    static void resolveNowLetsGetIdRunBeforeAnySupplyCall() {
        // Arrange
        XFTY_SharedAncestor.put('hq', new Account(Name = 'HQ'));

        // Act
        Test.startTest();
        XFTY_SharedAncestor.get('hq').resolveNow(contactsUnder('hq'), XFTY_InsertModeEnum.NOW);
        Test.stopTest();

        // Assert
        Assert.areEqual(1, [SELECT COUNT() FROM Account]);
        Assert.areEqual([SELECT Id FROM Account].Id, XFTY_SharedAncestor.getId('hq'));
    }

    @IsTest
    static void resolveNowPinsTheAncestorsModeAheadOfTheCall() {
        // Arrange - resolve 'hq' MOCK up front, then reference it from a NEVER call
        XFTY_SharedAncestor.put('hq', new Account(Name = 'HQ'));
        XFTY_SharedAncestor.get('hq').resolveNow(contactsUnder('hq'), XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        supplyContactsUnder('hq', 1, XFTY_InsertModeEnum.NEVER);
        Test.stopTest();

        // Assert
        Assert.areEqual(0, [SELECT COUNT() FROM Account], 'MOCK up front means no DML');
        Assert.isNotNull(XFTY_SharedAncestor.getId('hq'), 'but the mock Id is available');
    }

    @IsTest
    static void getIdFeedsAnOverrideTemplateDirectly() {
        // Arrange - resolve the shared record, then hand its Id straight to a template
        XFTY_SharedAncestor.put('hq', new Account(Name = 'HQ'));
        XFTY_SharedAncestor.get('hq').resolveNow(contactsUnder('hq'), XFTY_InsertModeEnum.NOW);
        Contact template = new Contact(LastName = 'Direct', AccountId = XFTY_SharedAncestor.getId('hq'));

        // Act
        Contact leaf;
        Test.startTest();
        leaf = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, contactsUnder('hq'))
                .setOverrideTemplate(template)
                .setInclusivity(XFTY_InsertInclusivityEnum.NONE)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .supply();
        Test.stopTest();

        // Assert
        Assert.areEqual(1, [SELECT COUNT() FROM Account], 'only the record resolveNow built');
        Assert.areEqual(XFTY_SharedAncestor.getId('hq'), leaf.AccountId);
    }

    // putIfAbsent ------------------------------------------------------

    @IsTest
    static void putIfAbsentRegistersOnlyWhenUnregistered() {
        // Arrange - a second putIfAbsent for the same name must not change it
        XFTY_SharedAncestor.putIfAbsent('hq', new Account(Name = 'First'));
        XFTY_SharedAncestor.putIfAbsent('hq', new Account(Name = 'Second'));

        // Act
        Test.startTest();
        supplyOneContactUnder('hq', XFTY_InsertModeEnum.NOW);
        Test.stopTest();

        // Assert
        Assert.areEqual('First', [SELECT Name FROM Account].Name, 'the second putIfAbsent was ignored');
    }

    // Cycles ---------------------------------------------------------

    @IsTest
    static void sharedAncestorsInACycleThrow() {
        // Arrange - 'a' needs 'b', 'b' needs 'a'
        XFTY_SharedAncestor.put('a', new Account()).fromVariant(KEY_A);
        XFTY_SharedAncestor.put('b', new Account()).fromVariant(KEY_B);

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        try {
            supplyOneContactUnderCycle();
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }

        // Assert
        Assert.isNotNull(thrown, 'a shared-ancestor cycle must throw');
        Assert.isTrue(thrown.getMessage().containsIgnoreCase('cycle'), thrown.getMessage());
    }

    @IsTest
    static void preRegisteringOneSideBreaksACycle() {
        // Arrange - hand 'b' a record so the 'a' <-> 'b' cycle resolves
        XFTY_SharedAncestor.put('a', new Account()).fromVariant(KEY_A);
        XFTY_SharedAncestor.put('b', new Account()).fromVariant(KEY_B);
        Account premadeB = new Account(Name = 'Pre-made B', Id = XFTY_IdMocker.generateId(Account.SObjectType));
        XFTY_SharedAncestor.put('b', premadeB);

        // Act
        Contact leaf;
        Test.startTest();
        leaf = supplyOneContactUnderCycle();
        Test.stopTest();

        // Assert
        Assert.isNotNull(leaf.AccountId, 'the chain resolved because the cycle was broken');
        Assert.areEqual(premadeB.Id, XFTY_SharedAncestor.getId('b'));
    }

    // Batched / deferred main build ----------------------------------

    @IsTest
    static void resolvesUpFrontUnderDepthBatched() {
        // Arrange
        XFTY_SharedAncestor.put('hq', new Account(Name = 'HQ'));

        // Act
        Test.startTest();
        new XFTY_DummySObjectProvider(Contact.SObjectType, contactsUnder('hq'))
                .setQuantityPerTemplate(3)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .depthBatched()
                .supplyList();
        Test.stopTest();

        // Assert
        Assert.areEqual(1, [SELECT COUNT() FROM Account]);
        Assert.areEqual(3, [SELECT COUNT() FROM Contact]);
    }

    @IsTest
    static void resolvesUpFrontUnderDeferred() {
        // Arrange - a DEFERRED build; the shared ancestor should not wait for flush()
        XFTY_SharedAncestor.put('hq', new Account(Name = 'HQ'));
        supplyContactsUnder('hq', 2, XFTY_InsertModeEnum.DEFERRED);

        // Act
        Test.startTest();
        XFTY_DeferredInserter.flush();
        Test.stopTest();

        // Assert
        Account sharedHq = [SELECT Id FROM Account];
        Assert.areEqual(1, [SELECT COUNT() FROM Account], 'the shared ancestor resolved before the flush');
        Assert.areEqual(2, [SELECT COUNT() FROM Contact]);
        for (Contact leaf : [SELECT AccountId FROM Contact]) {
            Assert.areEqual(sharedHq.Id, leaf.AccountId);
        }
    }

    // put(name, provider) - the full generation API for one shared record --------

    @IsTest
    static void putProviderShapesTheSharedRecordWithValueStrategies() {
        // Arrange - a literal strategy and a context-aware value on the shared Account
        XFTY_SharedAncestor.put('hq', 
                accountProvider()
                        .setOverrideTemplate(new Account(Name = 'HQ Ltd'))
                        .put(Account.Site, 'Berlin')
                        .put(Account.Description, new XFTY_CopyFromSibling(Account.Name))
        );

        // Act
        Contact leaf;
        Test.startTest();
        leaf = supplyOneContactUnder('hq', XFTY_InsertModeEnum.NOW);
        Test.stopTest();

        // Assert
        Account sharedHq = [SELECT Id, Name, Site, Description FROM Account];
        Assert.areEqual('HQ Ltd', sharedHq.Name);
        Assert.areEqual('Berlin', sharedHq.Site, 'the literal strategy landed on the shared record');
        Assert.areEqual('HQ Ltd', sharedHq.Description, 'the context-aware value ran on the shared record');
        Assert.areEqual(sharedHq.Id, leaf.AccountId);
    }

    @IsTest
    static void putProviderShapesTheSharedRecordsOwnAncestor() {
        // Arrange - the shared 'hq' Account gets a parent Account of its own
        XFTY_SharedAncestor.put('hq', 
                accountProvider()
                        .setOverrideTemplate(new Account(Name = 'HQ'))
                        .putRequired(Account.ParentId, new XFTY_DummyDefaultRelationship(new Account(Name = 'HQ Parent')))
                        .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
        );

        // Act
        Test.startTest();
        supplyOneContactUnder('hq', XFTY_InsertModeEnum.NOW);
        Test.stopTest();

        // Assert
        Account sharedHq = [SELECT ParentId FROM Account WHERE Name = 'HQ'];
        Account parent = [SELECT Id FROM Account WHERE Name = 'HQ Parent'];
        Assert.areEqual(parent.Id, sharedHq.ParentId, 'the shared record got the parent configured via the put-Provider');
        Assert.areEqual(2, [SELECT COUNT() FROM Account]);
    }

    @IsTest
    static void putProviderRejectsAKnobThatMeansMoreThanOneRecord() {
        // Arrange - setQuantityPerTemplate has no meaning for a single shared record
        XFTY_SharedAncestor.put('hq', 
                accountProvider()
                        .setOverrideTemplate(new Account(Name = 'HQ'))
                        .setQuantityPerTemplate(2)
        );

        // Act
        XFTY_DummySObjectProvider.SanityException thrown;
        try {
            supplyOneContactUnder('hq', XFTY_InsertModeEnum.MOCK);
        } catch (XFTY_DummySObjectProvider.SanityException ex) {
            thrown = ex;
        }

        // Assert
        Assert.isNotNull(thrown, 'a quantity > 1 on a put-Provider must throw');
        Assert.isTrue(thrown.getMessage().contains('one record'), thrown.getMessage());
    }

    @IsTest
    static void putProviderRejectsAnExplicitInsertModeOnTheProvider() {
        // Arrange - persistence follows the referencing call, not the Provider
        XFTY_SharedAncestor.put('hq', 
                accountProvider()
                        .setOverrideTemplate(new Account(Name = 'HQ'))
                        .setInsertMode(XFTY_InsertModeEnum.NOW)
        );

        // Act
        XFTY_DummySObjectProvider.SanityException thrown;
        try {
            supplyOneContactUnder('hq', XFTY_InsertModeEnum.MOCK);
        } catch (XFTY_DummySObjectProvider.SanityException ex) {
            thrown = ex;
        }

        // Assert
        Assert.isNotNull(thrown, 'setInsertMode on a put-Provider must throw');
        Assert.isTrue(thrown.getMessage().contains('setInsertMode'), thrown.getMessage());
    }

    @IsTest
    static void aTemplateThenAProviderIsRejected() {
        // Arrange
        XFTY_SharedAncestor.putAsTemplate('x', new Account());

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        try {
            XFTY_SharedAncestor.put('x', accountProvider());
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }

        // Assert
        Assert.isNotNull(thrown, 'a template then a Provider must be rejected');
        Assert.isTrue(thrown.getMessage().contains('not both'), thrown.getMessage());
    }

    @IsTest
    static void aProviderThenATemplateIsRejected() {
        // Arrange
        XFTY_SharedAncestor.put('y', accountProvider());

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        try {
            XFTY_SharedAncestor.putAsTemplate('y', new Account());
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }

        // Assert
        Assert.isNotNull(thrown, 'a Provider then a template must be rejected');
        Assert.isTrue(thrown.getMessage().contains('not both'), thrown.getMessage());
    }

    // Path-scoped value wires in a shared ancestor -------------------

    @IsTest
    static void aPathValueCanWireInASharedAncestorWithNoSpecialSetup() {
        // Arrange - a shared User, reached through Contact.AccountId -> Account.OwnerId
        XFTY_SharedAncestor.put('shared-owner', adminUser());
        List<SObjectField> ownerPath = new List<SObjectField>{ Contact.AccountId, Account.OwnerId };

        // Act
        XFTY_DummySObjectBundle bundle;
        Test.startTest();
        bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, defaultTypesLookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .putRequired(ownerPath, XFTY_SharedAncestor.get('shared-owner'))
                .supplyBundle();
        Test.stopTest();

        // Assert
        Account generatedAccount = firstAccount(bundle.getBundle(Contact.AccountId));
        Assert.areEqual(XFTY_SharedAncestor.getId('shared-owner'), generatedAccount.OwnerId,
                'the shared ancestor was wired in through a path value, nothing declared');
    }

    // Cross-SObject - one record, two child types -----------------

    @IsTest
    static void oneSharedRecordServesTwoDifferentChildSObjects() {
        // Arrange - a Contact Provider and a Case Provider, both under shared 'hq'
        XFTY_SharedAncestor.put('hq', new Account(Name = 'Shared HQ'));
        XFTY_DummySObjectProviderLookupIntf lookup = XFTY_ProviderLookups.of(
                new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                        XFTY_LookupKey.get(Account.SObjectType) => new XFTY_DefaultAccountDataProvider(),
                        XFTY_LookupKey.get(Contact.SObjectType) => childProvider(Contact.Id, Contact.AccountId, Contact.LastName, 'hq'),
                        XFTY_LookupKey.get(Case.SObjectType) => childProvider(Case.Id, Case.AccountId, null, 'hq')
                }
        );

        // Act - one supply per SObject type
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

        // Assert
        Assert.areEqual(1, [SELECT COUNT() FROM Account], 'one HQ for both the Contact and the Case');
        Assert.areEqual(contact.AccountId, supportCase.AccountId);
        Assert.areEqual(XFTY_SharedAncestor.getId('hq'), supportCase.AccountId);
    }

    // End to end - a three-level all-shared spine -------------------

    @IsTest
    static void anAllSharedSpineIsBuiltOnceAndEveryLeafLandsOnIt() {
        // Arrange - root (flat) <- division (put-Provider) <- region (put-Provider)
        configureAllSharedSpine();

        // Act - two independent leaf batches under the shared region
        List<Contact> eastLeaves;
        List<Contact> westLeaves;
        Test.startTest();
        eastLeaves = supplyContactsUnder('region', 3, XFTY_InsertModeEnum.NOW);
        westLeaves = supplyContactsUnder('region', 2, XFTY_InsertModeEnum.NOW);
        Test.stopTest();

        // Assert
        Account root = [SELECT Id FROM Account WHERE Name = 'Global Root'];
        Account division = [SELECT Id, ParentId FROM Account WHERE Name = 'Division'];
        Account region = [SELECT Id, ParentId FROM Account WHERE Name = 'Region'];
        Assert.areEqual(3, [SELECT COUNT() FROM Account], 'one row per shared level, whatever the leaves or calls');
        Assert.areEqual(root.Id, division.ParentId, 'division -> root');
        Assert.areEqual(division.Id, region.ParentId, 'region -> division');
        assertAllPointAt(eastLeaves, region.Id);
        assertAllPointAt(westLeaves, region.Id);
        Assert.areEqual(root.Id, XFTY_SharedAncestor.getId('root'));
        Assert.areEqual(division.Id, XFTY_SharedAncestor.getId('division'));
        Assert.areEqual(region.Id, XFTY_SharedAncestor.getId('region'));
    }

    @IsTest
    static void anAllSharedSpineIsReachableAllTheWayDownTheBundle() {
        // Arrange
        configureAllSharedSpine();

        // Act
        XFTY_DummySObjectBundle leafBundle;
        Test.startTest();
        leafBundle = new XFTY_DummySObjectProvider(Contact.SObjectType, contactsUnder('region'))
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .supplyBundle();
        Test.stopTest();

        // Assert - invariant 4: the shared record is present at every level of the bundle
        XFTY_DummySObjectBundle regionBundle = leafBundle.getBundle(Contact.AccountId);
        XFTY_DummySObjectBundle divisionBundle = regionBundle.getBundle(Account.ParentId);
        XFTY_DummySObjectBundle rootBundle = divisionBundle.getBundle(Account.ParentId);
        Assert.areEqual('Region', firstAccount(regionBundle).Name);
        Assert.areEqual('Division', firstAccount(divisionBundle).Name, 'present two levels down');
        Assert.areEqual('Global Root', firstAccount(rootBundle).Name, 'and three levels down');
    }

    // Fixture - configuration -----------------------------------------------

    private static void configureDeepChain() {
        XFTY_SharedAncestor.put('root', new Account(Name = 'Root'))
                .fromVariant(XFTY_LookupKey.get(Account.SObjectType));
        XFTY_SharedAncestor.put('level1', new Account(Name = 'Level 1'))
                .fromVariant(LEVEL1_KEY);
    }

    private static void configureAllSharedSpine() {
        XFTY_SharedAncestor.put('root', new Account(Name = 'Global Root'));
        XFTY_SharedAncestor.put('division', sharedAccountUnder('Division', 'root'));
        XFTY_SharedAncestor.put('region', sharedAccountUnder('Region', 'division'));
    }

    private static XFTY_DummySObjectProvider sharedAccountUnder(String name, String sharedParentName) {
        return accountProvider()
                .setOverrideTemplate(new Account(Name = name))
                .putRequired(Account.ParentId, XFTY_SharedAncestor.get(sharedParentName))
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED);
    }

    private static User adminUser() {
        return new User(
                Alias = 'shOwn', Email = 'sh.owner@example.com', Username = 'sh.owner@example.com.xfty',
                LastName = 'Owner', EmailEncodingKey = 'ISO-8859-1', LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US', TimeZoneSidKey = 'GMT',
                ProfileId = XFTY_DefaultUserDataProvider.profileIdFor('System Administrator')
        );
    }

    // Fixture - supply helpers -------------------------------------------

    private static List<Contact> supplyContactsUnder(String sharedName, Integer howMany, XFTY_InsertModeEnum mode) {
        return (List<Contact>) new XFTY_DummySObjectProvider(Contact.SObjectType, contactsUnder(sharedName))
                .setQuantityPerTemplate(howMany)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(mode)
                .supplyList();
    }

    private static Contact supplyOneContactUnder(String sharedName, XFTY_InsertModeEnum mode) {
        return supplyContactsUnder(sharedName, 1, mode)[0];
    }

    private static Contact supplyOneContactUnderCycle() {
        return (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, cycleLookup())
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
    }

    private static Integer dmlStatementsToSupply(Integer howMany, XFTY_DummySObjectProviderLookupIntf lookup) {
        Integer before = Limits.getDmlStatements();
        new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
                .setQuantityPerTemplate(howMany)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .supplyList();
        return Limits.getDmlStatements() - before;
    }

    // Fixture - assertions -------------------------------------------

    private static void assertAllPointAt(List<Contact> leaves, Id accountId) {
        for (Contact leaf : leaves) {
            Assert.areEqual(accountId, leaf.AccountId);
        }
    }

    private static Account firstAccount(XFTY_DummySObjectBundle bundle) {
        return (Account) bundle.primaryRecords()[0];
    }

    // Fixture - lookups + the Provider double ---------------------------

    private static XFTY_DummySObjectProvider accountProvider() {
        return new XFTY_DummySObjectProvider(Account.SObjectType, defaultTypesLookup());
    }

    private static XFTY_DummySObjectProviderLookupIntf contactsUnder(String sharedName) {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Account.SObjectType) => new XFTY_DefaultAccountDataProvider(),
                XFTY_LookupKey.get(Contact.SObjectType) => childProvider(Contact.Id, Contact.AccountId, Contact.LastName, sharedName)
        });
    }

    private static XFTY_DummySObjectProviderLookupIntf deepChainLookup() {
        return XFTY_ProviderLookups.of(new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
                XFTY_LookupKey.get(Account.SObjectType) => new XFTY_DefaultAccountDataProvider(),
                LEVEL1_KEY => childProvider(Account.Id, Account.ParentId, Account.Name, 'root'),
                XFTY_LookupKey.get(Contact.SObjectType) => childProvider(Contact.Id, Contact.AccountId, Contact.LastName, 'level1')
        });
    }

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

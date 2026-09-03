/**
 * Proves `XFTY_Seeder.seed(bundle)` - a best-effort save of a whole generated
 * graph into the org. Real DML, so `System.runAs`. (The @IntegrationTest path -
 * data surviving the transaction - is proven on a scratch org, not here.)
 */
@IsTest
private class XFTY_SeederTest {

    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;
    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();

    @IsTest
    static void testSeed_aGeneratedAncestorGraph_savesEveryRecord() {
        // Arrange - 3 Contacts, each with its own generated Account, nothing persisted yet
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.LATER)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setQuantityPerTemplate(3)
                .supplyBundle();

        // Act
        XFTY_SeedResult result;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = XFTY_Seeder.seed(bundle);
            Test.stopTest();
        }

        // Assert
        Assert.isTrue(result.isFullySeeded(), String.valueOf(result.errors()));
        Assert.areEqual(6, result.savedCount(), '3 Contacts + 3 Accounts');
        Assert.isNotNull(bundle.primaryRecords()[0].Id);
    }

    @IsTest
    static void testSeed_aDownwardChildGraph_wiresEachChildToItsNewParentId() {
        // Arrange - one Account with 2 child Contacts
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.LATER)
                .withChildren(Contact.AccountId, 2)
                .supplyBundle();

        // Act
        XFTY_SeedResult result;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = XFTY_Seeder.seed(bundle);
            Test.stopTest();
        }

        // Assert
        Id accountId = bundle.primaryRecords()[0].Id;
        Assert.isNotNull(accountId);
        for (SObject child : bundle.getChildList(Contact.AccountId)) {
            Assert.areEqual(accountId, child.get('AccountId'), 'child FK points at the new Account Id');
        }
        Assert.isTrue(result.isFullySeeded());
    }

    @IsTest
    static void testSeed_aThreeLevelDownwardTree_wiresEveryLevel() {
        // Arrange - Account -> 2 Contacts -> 2 reports each (Contact.ReportsToId)
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.LATER)
                .with(
                        new XFTY_SObjectChildProvider(Contact.AccountId).setQuantity(2)
                                .with(new XFTY_SObjectChildProvider(Contact.ReportsToId).setQuantity(2))
                )
                .supplyBundle();

        // Act
        XFTY_SeedResult result;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = XFTY_Seeder.seed(bundle);
            Test.stopTest();
        }

        // Assert
        Assert.isTrue(result.isFullySeeded(), String.valueOf(result.errors()));
        Assert.areEqual(7, result.savedCount(), '1 Account + 2 Contacts + 4 reports');
        Contact firstChild = (Contact) bundle.getChildList(Contact.AccountId)[0];
        Assert.areEqual(bundle.primaryRecords()[0].Id, firstChild.AccountId);
        SObject firstGrandchild = bundle.getChildBundle(Contact.AccountId).getChildList(Contact.ReportsToId)[0];
        Assert.areEqual(firstChild.Id, firstGrandchild.get('ReportsToId'), 'grandchild wired to its Contact');
    }

    @IsTest
    static void testSeed_twoChildConfigsOnTheSameField_seedsBoth() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.LATER)
                .withChildren(Contact.AccountId, 2)
                .withChildren(Contact.AccountId, 3)
                .supplyBundle();

        // Act
        XFTY_SeedResult result;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = XFTY_Seeder.seed(bundle);
            Test.stopTest();
        }

        // Assert
        Assert.isTrue(result.isFullySeeded(), String.valueOf(result.errors()));
        Assert.areEqual(6, result.savedCount(), '1 Account + 5 Contacts across both configs');
        for (SObject child : bundle.getChildList(Contact.AccountId)) {
            Assert.areEqual(bundle.primaryRecords()[0].Id, child.get('AccountId'));
        }
    }

    @IsTest
    static void testSeed_aPolymorphicGraph_wiresEverySide() {
        // Arrange - a Task with a generated Contact (WhoId) and Account (WhatId), hand-built
        Contact who = new Contact(LastName = 'Who');
        Account what = new Account(Name = 'What Co');
        Task primary = new Task(Subject = 'Poly');
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Task.Id, new List<SObject>{ primary });
        bundle.put(Task.WhoId, new List<SObject>{ who });
        bundle.put(Task.WhoId, singletonBundle(Contact.Id, who));
        bundle.put(Task.WhatId, new List<SObject>{ what });
        bundle.put(Task.WhatId, singletonBundle(Account.Id, what));

        // Act
        XFTY_SeedResult result;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = XFTY_Seeder.seed(bundle);
            Test.stopTest();
        }

        // Assert
        Assert.isTrue(result.isFullySeeded(), String.valueOf(result.errors()));
        Assert.areEqual(who.Id, primary.WhoId);
        Assert.areEqual(what.Id, primary.WhatId);
    }

    @IsTest
    static void testSeed_aSelfReferentialAncestorChain_seedsFromTheTopDown() {
        // Arrange - Account -> parent Account -> grandparent Account (terminated), hand-built
        Account grandparent = new Account(Name = 'GP');
        Account parent = new Account(Name = 'P');
        Account child = new Account(Name = 'C');
        XFTY_DummySObjectBundle gpBundle = singletonBundle(Account.Id, grandparent);
        XFTY_DummySObjectBundle parentBundle = singletonBundle(Account.Id, parent);
        parentBundle.put(Account.ParentId, new List<SObject>{ grandparent });
        parentBundle.put(Account.ParentId, gpBundle);
        XFTY_DummySObjectBundle bundle = singletonBundle(Account.Id, child);
        bundle.put(Account.ParentId, new List<SObject>{ parent });
        bundle.put(Account.ParentId, parentBundle);

        // Act
        XFTY_SeedResult result;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = XFTY_Seeder.seed(bundle);
            Test.stopTest();
        }

        // Assert
        Assert.isTrue(result.isFullySeeded(), String.valueOf(result.errors()));
        Assert.areEqual(parent.Id, child.ParentId);
        Assert.areEqual(grandparent.Id, parent.ParentId);
    }

    private static XFTY_DummySObjectBundle singletonBundle(SObjectField primaryField, SObject record) {
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(primaryField, new List<SObject>{ record });
        return bundle;
    }

    @IsTest
    static void testSeed_whenOnePrimaryIsInvalid_savesTheRestAndReportsTheFailure() {
        // Arrange - a hand-built bundle: one valid Contact, one with no LastName
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Contact.Id, new List<SObject>{
                new Contact(LastName = 'Valid'), new Contact()
        });

        // Act
        XFTY_SeedResult result;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = XFTY_Seeder.seed(bundle);
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(1, result.savedCount());
        Assert.areEqual(1, result.failedCount());
        Assert.isFalse(result.isFullySeeded());
        Assert.areEqual(1, result.errors().size(), 'the rejected record is reported');
    }

    @IsTest
    static void testSeed_aTwoLevelAncestorChain_savesFromTheTopDown() {
        // Arrange - Contact -> Account -> parent Account, hand-built, nothing persisted
        Account grandparent = new Account(Name = 'Grandparent Co');
        Account parent = new Account(Name = 'Parent Co');
        Contact primary = new Contact(LastName = 'Leaf');

        XFTY_DummySObjectBundle grandparentBundle = new XFTY_DummySObjectBundle();
        grandparentBundle.putPrimaries(Account.Id, new List<SObject>{ grandparent });
        XFTY_DummySObjectBundle parentBundle = new XFTY_DummySObjectBundle();
        parentBundle.putPrimaries(Account.Id, new List<SObject>{ parent });
        parentBundle.put(Account.ParentId, new List<SObject>{ grandparent });
        parentBundle.put(Account.ParentId, grandparentBundle);
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Contact.Id, new List<SObject>{ primary });
        bundle.put(Contact.AccountId, new List<SObject>{ parent });
        bundle.put(Contact.AccountId, parentBundle);

        // Act
        XFTY_SeedResult result;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = XFTY_Seeder.seed(bundle);
            Test.stopTest();
        }

        // Assert
        Assert.isTrue(result.isFullySeeded(), String.valueOf(result.errors()));
        Assert.areEqual(parent.Id, primary.AccountId);
        Assert.areEqual(grandparent.Id, parent.ParentId);
    }

    @IsTest
    static void testSeed_whenManyPrimariesShareOneAncestor_insertsThatAncestorOnceAndWiresThemAll() {
        // Arrange - 3 Contacts on one shared Account, generated but not persisted
        XFTY_SharedAncestor.put('seed-hq', new Account(Name = 'Seed HQ'));
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('seed-hq'))
                .setQuantityPerTemplate(3)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.LATER)
                .supplyBundle();

        // Act
        XFTY_SeedResult result;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = XFTY_Seeder.seed(bundle);
            Test.stopTest();
        }

        // Assert
        Assert.isTrue(result.isFullySeeded(), String.valueOf(result.errors()));
        Id sharedId = bundle.primaryRecords()[0].get('AccountId') != null
                ? (Id) bundle.primaryRecords()[0].get('AccountId')
                : null;
        Assert.isNotNull(sharedId, 'the shared Account was inserted and wired');
        for (SObject contact : bundle.primaryRecords()) {
            Assert.areEqual(sharedId, contact.get('AccountId'), 'every Contact points at the one shared Account');
        }
    }

    @IsTest
    static void testSeed_whenAPrimaryAlreadyHasAnId_doesNotCountItAsAttempted() {
        // Arrange - one anchor (pre-set Id), one to insert
        Contact anchor = new Contact(LastName = 'Anchor', Id = XFTY_IdMocker.generateId(Contact.SObjectType));
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Contact.Id, new List<SObject>{ anchor, new Contact(LastName = 'Fresh') });

        // Act
        XFTY_SeedResult result;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = XFTY_Seeder.seed(bundle);
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(1, result.attemptedCount(), 'the anchor was not re-inserted');
        Assert.areEqual(1, result.savedCount());
    }

    @IsTest
    static void testSeed_splitsSavedFromFailedRecords() {
        // Arrange
        Contact good = new Contact(LastName = 'Kept');
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Contact.Id, new List<SObject>{ good, new Contact() });

        // Act
        XFTY_SeedResult result;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = XFTY_Seeder.seed(bundle);
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(1, result.savedRecords().size());
        Assert.areEqual('Kept', ((Contact) result.savedRecords()[0]).LastName);
        Assert.areEqual(1, result.failedRecords().size());
    }

    @IsTest
    static void testSeed_anEmptyBundle_reportsNothingAttempted() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Contact.Id, new List<SObject>());

        // Act
        XFTY_SeedResult result;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = XFTY_Seeder.seed(bundle);
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(0, result.attemptedCount());
        Assert.isTrue(result.isFullySeeded(), 'nothing failed');
    }

    @IsTest
    static void testSeed_fromARegularTestNotAnIntegrationTest_flagsItOnTheResult() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Contact.Id, new List<SObject>{ new Contact(LastName = 'Rolled Back') });

        // Act
        XFTY_SeedResult result;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = XFTY_Seeder.seed(bundle);
            Test.stopTest();
        }

        // Assert - the DML ran (and will roll back with this @IsTest transaction)
        Assert.isFalse(result.ranInIntegrationTest(), 'a plain @IsTest is not an @IntegrationTest');
        Assert.areEqual(1, result.savedCount(), 'the insert still happened in-transaction');
    }

    @IsTest
    static void testIsInIntegrationTest_fromARegularTest_isFalse() {
        // Arrange - running as a plain @IsTest method

        // Act
        Test.startTest();
        Boolean inIntegrationTest = XFTY_Seeder.isInIntegrationTest();
        Test.stopTest();

        // Assert
        Assert.isFalse(inIntegrationTest);
    }
}

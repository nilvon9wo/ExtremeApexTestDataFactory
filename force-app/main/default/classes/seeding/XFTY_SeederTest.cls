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
                .setInsertMode(XFTY_InsertModeEnum.NEVER)
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
                .setInsertMode(XFTY_InsertModeEnum.NEVER)
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
}

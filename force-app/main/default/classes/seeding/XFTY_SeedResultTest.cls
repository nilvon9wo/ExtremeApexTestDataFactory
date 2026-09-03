/**
 * Proves `XFTY_SeedResult` - the counts and error text over a set of
 * `Database.SaveResult`s. Needs one small `Database.insert` to get real
 * results, so `System.runAs`.
 */
@IsTest
private class XFTY_SeedResultTest {

    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    @IsTest
    static void testCounts_forAMixOfSuccessAndFailure_splitSavedFromFailed() {
        // Arrange - Account saves, the LastName-less Contact does not
        List<SObject> records = new List<SObject>{ new Account(Name = 'Ok'), new Contact() };
        XFTY_SeedResult result;

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            Map<Integer, Database.SaveResult> outcomes = outcomesFor(records);
            result = new XFTY_SeedResult(records, outcomes, true);
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(2, result.attemptedCount());
        Assert.areEqual(1, result.savedCount());
        Assert.areEqual(1, result.failedCount());
        Assert.isFalse(result.isFullySeeded());
    }

    @IsTest
    static void testErrors_nameTheFailedRecordType_andCarryThePlatformMessage() {
        // Arrange
        List<SObject> records = new List<SObject>{ new Contact() };
        XFTY_SeedResult result;

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = new XFTY_SeedResult(records, outcomesFor(records), true);
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(1, result.errors().size());
        Assert.isTrue(result.errors()[0].startsWith('Contact:'), result.errors()[0]);
        Assert.areEqual(1, result.failedRecords().size());
    }

    @IsTest
    static void testIsFullySeeded_whenEveryRecordSaved_isTrue() {
        // Arrange
        List<SObject> records = new List<SObject>{ new Account(Name = 'One'), new Account(Name = 'Two') };
        XFTY_SeedResult result;

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = new XFTY_SeedResult(records, outcomesFor(records), true);
            Test.stopTest();
        }

        // Assert
        Assert.isTrue(result.isFullySeeded());
        Assert.areEqual(2, result.savedRecords().size());
        Assert.isTrue(result.errors().isEmpty());
    }

    @IsTest
    static void testEmptyOutcomes_readAsAFullySeededNoOp() {
        // Arrange
        XFTY_SeedResult result = new XFTY_SeedResult(
                new List<SObject>(), new Map<Integer, Database.SaveResult>(), true
        );

        // Act
        Test.startTest();
        Boolean full = result.isFullySeeded();
        Test.stopTest();

        // Assert
        Assert.isTrue(full);
        Assert.areEqual(0, result.attemptedCount());
    }

    @IsTest
    static void testSavedRecordsOfType_returnsOnlyThatTypesSavedRecords() {
        // Arrange - an Account and a Contact both save
        List<SObject> records = new List<SObject>{ new Account(Name = 'A'), new Contact(LastName = 'C') };
        XFTY_SeedResult result;

        // Act
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = new XFTY_SeedResult(records, outcomesFor(records), true);
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(1, result.savedRecordsOfType(Account.SObjectType).size());
        Assert.isTrue(result.savedRecordsOfType(Account.SObjectType)[0] instanceof Account);
        Assert.areEqual(0, result.savedRecordsOfType(Lead.SObjectType).size());
    }

    @IsTest
    static void testRanInIntegrationTest_carriesTheFlagItWasBuiltWith() {
        // Arrange
        XFTY_SeedResult outside = new XFTY_SeedResult(
                new List<SObject>(), new Map<Integer, Database.SaveResult>(), false
        );

        // Act
        Test.startTest();
        Boolean ran = outside.ranInIntegrationTest();
        Test.stopTest();

        // Assert
        Assert.isFalse(ran);
    }

    private static Map<Integer, Database.SaveResult> outcomesFor(List<SObject> records) {
        Map<Integer, Database.SaveResult> outcomes = new Map<Integer, Database.SaveResult>();
        List<Database.SaveResult> saveResults = Database.insert(records, false);
        for (Integer i = 0; i < saveResults.size(); i++) {
            outcomes.put(i, saveResults[i]);
        }
        return outcomes;
    }
}

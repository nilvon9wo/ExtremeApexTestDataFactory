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
            result = new XFTY_SeedResult(records, outcomes);
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
            result = new XFTY_SeedResult(records, outcomesFor(records));
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(1, result.errors().size());
        Assert.isTrue(result.errors()[0].startsWith('Contact:'), result.errors()[0]);
        Assert.areEqual(1, result.failedRecords().size());
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

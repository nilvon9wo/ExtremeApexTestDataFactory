/**
 * Proves `XFTY_PathKey` - a comparable string key for a relationship path.
 */
@IsTest
private class XFTY_PathKeyTest {

    @IsTest
    static void testOf_joinsTheFieldNamesPositionally() {
        // Arrange
        List<SObjectField> path = new List<SObjectField>{ Contact.AccountId, Account.ParentId };

        // Act
        Test.startTest();
        String key = XFTY_PathKey.of(path);
        Test.stopTest();

        // Assert
        Assert.areEqual('AccountId>ParentId>', key);
    }

    @IsTest
    static void testOf_forAnEmptyPath_isEmpty() {
        // Arrange
        List<SObjectField> emptyPath = new List<SObjectField>();

        // Act
        Test.startTest();
        String key = XFTY_PathKey.of(emptyPath);
        Test.stopTest();

        // Assert
        Assert.areEqual('', key);
    }

    @IsTest
    static void testOf_forANullPath_isEmpty() {
        // Arrange
        List<SObjectField> nullPath = null;

        // Act
        Test.startTest();
        String key = XFTY_PathKey.of(nullPath);
        Test.stopTest();

        // Assert
        Assert.areEqual('', key);
    }
}

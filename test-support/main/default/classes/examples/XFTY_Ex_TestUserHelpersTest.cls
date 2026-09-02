/**
 * Runnable proof for docs/use/test-user-helpers.md.
 *
 * Covers TEST_ADMIN_USER. `profileIdFor` / `roleIdFor` resolve against real org
 * metadata and are proven by XFTY_DefaultDataProviderTest.
 */
@IsTest
private class XFTY_Ex_TestUserHelpersTest {

    @IsTest
    static void testTestAdminUser_isAnInsertedAdminUsableDirectlyInRunAs() {
        // Arrange
        // nothing to arrange - the helper is under test

        // Act
        Boolean ranAsAdmin = false;
        System.runAs(XFTY_DefaultUserDataProvider.TEST_ADMIN_USER) {
            Test.startTest();
            ranAsAdmin = true;
            Test.stopTest();
        }

        // Assert
        Assert.isNotNull(XFTY_DefaultUserDataProvider.TEST_ADMIN_USER.Id, 'TEST_ADMIN_USER is already inserted');
        Assert.isTrue(ranAsAdmin, 'and usable directly in System.runAs(...)');
        Assert.areEqual(
                1, [SELECT COUNT() FROM User WHERE Id = :XFTY_DefaultUserDataProvider.TEST_ADMIN_USER.Id]
        );
    }

    @IsTest
    static void testTestAdminUser_returnsTheSameInstanceEachCall() {
        // Arrange
        // nothing to arrange - the helper is a per-transaction singleton

        // Act
        Test.startTest();
        User first = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;
        Test.stopTest();

        // Assert
        Assert.areEqual(first.Id, XFTY_DefaultUserDataProvider.TEST_ADMIN_USER.Id, 'one admin per transaction, not one per call');
    }
}

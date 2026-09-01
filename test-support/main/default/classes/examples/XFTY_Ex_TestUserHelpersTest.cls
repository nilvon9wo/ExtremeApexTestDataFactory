/**
 * Runnable proof for docs/use/test-user-helpers.md.
 *
 * Covers TEST_ADMIN_USER. `profileIdFor` / `roleIdFor` resolve against real org
 * metadata and are proven by XFTY_DefaultDataProviderTest (they sit in the same
 * known-gap bucket as the record-type self-tests when run on the local runtime).
 */
@IsTest
private class XFTY_Ex_TestUserHelpersTest {

    @IsTest
    static void testAdminUserIsAnInsertedAdminReadyForRunAs() {
        // Arrange
        User admin = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

        // Act
        Boolean ranAsAdmin = false;
        System.runAs(admin) {
            ranAsAdmin = true;
        }

        // Assert
        Assert.isNotNull(admin.Id, 'TEST_ADMIN_USER is already inserted');
        Assert.isTrue(ranAsAdmin, 'and usable directly in System.runAs(...)');
        Assert.areEqual(1, [SELECT COUNT() FROM User WHERE Id = :admin.Id]);
    }

    @IsTest
    static void theSameAdminInstanceIsReturnedEachTime() {
        // Arrange
        // nothing to arrange - the helper is a per-transaction singleton

        // Act
        User first = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;
        User second = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

        // Assert
        Assert.areEqual(first.Id, second.Id, 'one admin per transaction, not one per call');
    }
}

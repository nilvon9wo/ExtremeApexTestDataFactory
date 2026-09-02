/**
 * The `XFTY_DefaultUserDataProvider.profileIdFor` / `roleIdFor` paths that need a
 * real org's `Profile` / `UserRole` tables - resolving a real reference, and
 * throwing `UnknownReferenceException` for one that does not exist.
 *
 * In `test-support/orgonly/` because the local runtime fakes `Profile` /
 * `UserRole` `WHERE` filtering and query counting. Passes on a scratch org;
 * `nimbus test` excludes `orgonly/`. The feature-independent paths are in
 * `XFTY_DefaultDataProviderTest` (force-app).
 */
@IsTest
private class XFTY_DefaultDataProviderOrgTest {

    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    @IsTest
    static void testProfileIdFor_forAKnownProfile_resolvesItFromCacheWithoutAFreshQuery() {
        // Arrange - the first resolve already ran during TEST_ADMIN static init

        // Act
        Id adminProfileId;
        Integer queriesUsed;
        Test.startTest();
        Integer before = Limits.getQueries();
        adminProfileId = XFTY_DefaultUserDataProvider.profileIdFor(XFTY_DefaultUserDataProvider.SYSTEM_ADMIN);
        XFTY_DefaultUserDataProvider.profileIdFor(XFTY_DefaultUserDataProvider.SYSTEM_ADMIN);
        queriesUsed = Limits.getQueries() - before;
        Test.stopTest();

        // Assert
        Assert.areEqual(0, queriesUsed, 'resolution is cached across calls');
        Assert.areEqual(TEST_ADMIN.ProfileId, adminProfileId);
    }

    @IsTest
    static void testProfileIdFor_forAnUnknownProfileName_throws() {
        // Arrange
        // nothing to arrange

        // Act
        XFTY_DefaultUserDataProvider.UnknownReferenceException thrown;
        Test.startTest();
        try {
            XFTY_DefaultUserDataProvider.profileIdFor('No Such Profile Name');
        } catch (XFTY_DefaultUserDataProvider.UnknownReferenceException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown, 'an unknown Profile name must throw');
        Assert.isTrue(thrown.getMessage().contains('No Such Profile Name'), thrown.getMessage());
    }

    @IsTest
    static void testRoleIdFor_forAnUnknownDeveloperName_throws() {
        // Arrange
        // nothing to arrange

        // Act
        XFTY_DefaultUserDataProvider.UnknownReferenceException thrown;
        Test.startTest();
        try {
            XFTY_DefaultUserDataProvider.roleIdFor('XFTY_No_Such_Role');
        } catch (XFTY_DefaultUserDataProvider.UnknownReferenceException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown, 'an unknown UserRole developer name must throw');
        Assert.isTrue(thrown.getMessage().contains('XFTY_No_Such_Role'), thrown.getMessage());
    }
}

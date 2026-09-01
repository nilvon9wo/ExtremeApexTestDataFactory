/**
 * The `XFTY_DefaultUserDataProvider.profileIdFor` / `roleIdFor` paths that need a
 * real org's `Profile` / `UserRole` tables - resolving a real reference, and
 * throwing `UnknownReferenceException` for one that does not exist.
 *
 * In `test-support/orgonly/` because the local Apex runtime (Nimbus) fakes
 * `Profile` / `UserRole` `WHERE` filtering and query counting. These pass on a
 * scratch org; the local run excludes the `orgonly/` folder. The
 * feature-independent paths are in `XFTY_DefaultDataProviderTest` (force-app).
 */
@IsTest
private class XFTY_DefaultDataProviderOrgTest {

    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    @IsTest
    static void profileIdForResolvesAndCaches() {
        // Arrange
        Integer queriesBefore = Limits.getQueries();

        // Act - the first resolve already ran during TEST_ADMIN static init, so this re-reads the cache
        Id adminId = XFTY_DefaultUserDataProvider.profileIdFor(XFTY_DefaultUserDataProvider.SYSTEM_ADMIN);
        XFTY_DefaultUserDataProvider.profileIdFor(XFTY_DefaultUserDataProvider.SYSTEM_ADMIN);

        // Assert
        Assert.areEqual(queriesBefore, Limits.getQueries(), 'resolution is cached across calls');
        Assert.areEqual(TEST_ADMIN.ProfileId, adminId);
    }

    @IsTest
    static void profileIdForThrowsForAnUnknownProfile() {
        // Arrange
        XFTY_DefaultUserDataProvider.UnknownReferenceException thrown;

        // Act
        try {
            XFTY_DefaultUserDataProvider.profileIdFor('No Such Profile Name');
        } catch (XFTY_DefaultUserDataProvider.UnknownReferenceException ex) {
            thrown = ex;
        }

        // Assert
        Assert.isNotNull(thrown, 'an unknown Profile name must throw');
        Assert.isTrue(thrown.getMessage().contains('No Such Profile Name'), thrown.getMessage());
    }

    @IsTest
    static void roleIdForThrowsForAnUnknownRole() {
        // Arrange
        XFTY_DefaultUserDataProvider.UnknownReferenceException thrown;

        // Act
        try {
            XFTY_DefaultUserDataProvider.roleIdFor('XFTY_No_Such_Role');
        } catch (XFTY_DefaultUserDataProvider.UnknownReferenceException ex) {
            thrown = ex;
        }

        // Assert
        Assert.isNotNull(thrown, 'an unknown UserRole developer name must throw');
        Assert.isTrue(thrown.getMessage().contains('XFTY_No_Such_Role'), thrown.getMessage());
    }
}

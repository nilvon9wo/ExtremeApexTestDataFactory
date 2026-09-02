/**
 * Proves `XFTY_DefaultUserDataProvider` - the ready-made `TEST_ADMIN_USER`, the
 * Master Template that covers the fields a User insert needs, an inserted User,
 * and `roleIdFor` resolving a real `UserRole`. The unknown-name / feature-gated
 * paths are in `XFTY_DefaultDataProviderOrgTest` (test-support/orgonly).
 * DML/SOQL-backed, so `System.runAs`.
 */
@IsTest
private class XFTY_DefaultUserDataProviderTest {

    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    @IsTest
    static void testTestAdminUser_isAnInsertedSystemAdministrator() {
        // Arrange
        // nothing to arrange - the static is under test

        // Act
        Profile adminProfile;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            adminProfile = [SELECT Name FROM Profile WHERE Id = :TEST_ADMIN.ProfileId];
            Test.stopTest();
        }

        // Assert
        Assert.isNotNull(TEST_ADMIN.Id, 'TEST_ADMIN_USER is inserted');
        Assert.areEqual('System Administrator', adminProfile.Name);
    }

    @IsTest
    static void testGetMasterTemplate_populatesEveryFieldRequiredToInsertAUser() {
        // Arrange
        XFTY_DefaultUserDataProvider provider = new XFTY_DefaultUserDataProvider();

        // Act
        Test.startTest();
        XFTY_DummySObjectMasterTemplate template = provider.getMasterTemplate();
        Test.stopTest();

        // Assert
        for (SObjectField required : new List<SObjectField>{
                User.Alias, User.Email, User.EmailEncodingKey, User.LanguageLocaleKey,
                User.LastName, User.LocaleSidKey, User.ProfileId, User.TimeZoneSidKey, User.Username
        }) {
            Assert.isTrue(template.defaultBySObjectFieldMap.containsKey(required), 'master template populates ' + required);
        }
    }

    @IsTest
    static void testSupply_inNowMode_generatesAnInsertableUser() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(User.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED);

        // Act
        User generated;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            generated = (User) provider.supply();
            Test.stopTest();
        }

        // Assert
        Assert.isNotNull(generated.Id);
        Assert.isTrue(generated.Username.contains(XFTY_DefaultUserDataProvider.DEFAULT_USERNAME_PREFIX));
    }

    @IsTest
    static void testRoleIdFor_forARealRole_resolvesByDeveloperNameAndCachesTheResult() {
        // Arrange
        UserRole role = new UserRole(Name = 'XFTY Coverage Role', DeveloperName = 'XFTY_Coverage_Role');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert role;
        }

        // Act
        Id firstResolved;
        Integer queriesAfterFirst;
        Id secondResolved;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            firstResolved = XFTY_DefaultUserDataProvider.roleIdFor('XFTY_Coverage_Role');
            queriesAfterFirst = Limits.getQueries();
            secondResolved = XFTY_DefaultUserDataProvider.roleIdFor('XFTY_Coverage_Role');
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(role.Id, firstResolved);
        Assert.areEqual(role.Id, secondResolved, 'the same Id on repeat');
        Assert.areEqual(queriesAfterFirst, Limits.getQueries(), 'the second call does not re-query');
    }

    @IsTest
    static void testSupplyBundle_whenARoleIdIsSetViaAnOverrideTemplate_isKeptOnTheGeneratedUser() {
        // Arrange
        UserRole role = new UserRole(Name = 'XFTY Override Role', DeveloperName = 'XFTY_Override_Role');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert role;
        }
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(User.SObjectType, LOOKUP)
                .setOverrideTemplate(new User(UserRoleId = XFTY_DefaultUserDataProvider.roleIdFor('XFTY_Override_Role')))
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        XFTY_DummySObjectBundle bundle;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            bundle = provider.supplyBundle();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(role.Id, ((User) bundle.getList(User.Id)[0]).UserRoleId);
    }
}

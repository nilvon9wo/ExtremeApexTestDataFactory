/**
 * Proves the bundled Providers (`Account`, `Contact`, `User`). Doubles as a
 * template for the per-Provider test class docs/extend/providers.md recommends.
 * DML/SOQL-backed tests run under `System.runAs`; the template-inspection tests
 * do not.
 */
@IsTest
private class XFTY_DefaultDataProviderTest {

    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    // Account -----------------------------------------------

    @IsTest
    static void testGetPrimaryTargetField_forTheAccountProvider_isAccountId() {
        // Arrange
        XFTY_DefaultAccountDataProvider provider = new XFTY_DefaultAccountDataProvider();

        // Act
        Test.startTest();
        SObjectField primaryField = provider.getPrimaryTargetField();
        Test.stopTest();

        // Assert
        Assert.areEqual(Account.Id, primaryField);
        Assert.isNotNull(provider.getMasterTemplate());
    }

    @IsTest
    static void testCreateBundle_forTheAccountProvider_producesAPopulatedAccount() {
        // Arrange
        XFTY_DefaultAccountDataProvider provider = new XFTY_DefaultAccountDataProvider();
        XFTY_GenerationContext context =
                new XFTY_GenerationContext(LOOKUP, XFTY_InsertModeEnum.MOCK, XFTY_InsertInclusivityEnum.NONE);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.createBundle(context, new List<SObject>{ new Account() });
        Test.stopTest();

        // Assert
        Account generatedAccount = (Account) bundle.getList(Account.Id)[0];
        Assert.isNotNull(generatedAccount.Id);
        Assert.areEqual(XFTY_DefaultAccountDataProvider.DEFAULT_INDUSTRY, generatedAccount.Industry);
        Assert.areEqual(XFTY_DefaultAccountDataProvider.DEFAULT_SHIPPING_COUNTRY, generatedAccount.ShippingCountry);
    }

    @IsTest
    static void testSupply_forTheAccountProviderInNowMode_generatesAnInsertableAccountWithDefaults() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.NOW);

        // Act
        Account generatedAccount;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            generatedAccount = (Account) provider.supply();
            Test.stopTest();
        }

        // Assert
        Assert.isNotNull(generatedAccount.Id);
        Assert.isTrue(generatedAccount.Name.startsWith(XFTY_DefaultAccountDataProvider.DEFAULT_NAME_PREFIX));
        Assert.areEqual(XFTY_DefaultAccountDataProvider.DEFAULT_INDUSTRY, generatedAccount.Industry);
        Assert.areEqual(1, [SELECT COUNT() FROM Account]);
    }

    // Contact ----------------------------------------------

    @IsTest
    static void testGetMasterTemplate_forTheContactProvider_declaresARequiredAccountRelationship() {
        // Arrange
        XFTY_DefaultContactDataProvider provider = new XFTY_DefaultContactDataProvider();

        // Act
        Test.startTest();
        XFTY_DummySObjectMasterTemplate template = provider.getMasterTemplate();
        Test.stopTest();

        // Assert
        Assert.isTrue(template.requiredRelationshipBySObjectFieldMap.containsKey(Contact.AccountId),
                'Contact requires an Account');
    }

    @IsTest
    static void testSupplyList_forTheContactProviderWithQuantity_generatesAUniqueEmailPerRecord() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setQuantityPerTemplate(3)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        List<SObject> contacts = provider.supplyList();
        Test.stopTest();

        // Assert
        Set<Object> emails = new Set<Object>();
        for (SObject generatedContact : contacts) {
            emails.add(generatedContact.get(Contact.Email));
        }
        Assert.areEqual(3, emails.size(), 'each generated Contact gets its own email');
    }

    // User -----------------------------------------------

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
    static void testGetMasterTemplate_forTheUserProvider_populatesEveryFieldRequiredToInsertAUser() {
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
    static void testSupply_forTheUserProviderInNowMode_generatesAnInsertableUser() {
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

    // roleIdFor - the "resolves for a real role" path. The "throws for an unknown
    // name" path is in XFTY_DefaultDataProviderOrgTest (test-support/orgonly).

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

        // Act
        XFTY_DummySObjectBundle bundle;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            bundle = new XFTY_DummySObjectProvider(User.SObjectType, LOOKUP)
                    .setOverrideTemplate(new User(UserRoleId = XFTY_DefaultUserDataProvider.roleIdFor('XFTY_Override_Role')))
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supplyBundle();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(role.Id, ((User) bundle.getList(User.Id)[0]).UserRoleId);
    }
}

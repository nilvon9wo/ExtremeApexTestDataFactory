/**
 * Coverage for the bundled Providers (`Account`, `Contact`, `User`) and for
 * `XFTY_RecordTypeDataProvider`.
 *
 * These tests double as a template for the per-Provider test class that
 * docs/providers.md recommends writing for every new Provider.
 */
@IsTest
private class XFTY_DefaultDataProviderTest {
    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    // Account -----------------------------------------------------------------

    @IsTest
    static void accountProviderExposesItsIdentityAndTemplate() {
        XFTY_DefaultAccountDataProvider provider = new XFTY_DefaultAccountDataProvider();
        Assert.areEqual(Account.Id, provider.getPrimaryTargetField());
        Assert.isNotNull(provider.getMasterTemplate());
    }

    @IsTest
    static void accountProviderGeneratesAnInsertableAccountWithDefaults() {
        Account generatedAccount;
        Test.startTest();
        System.runAs(TEST_ADMIN) {
            generatedAccount = (Account) new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .supply();
        }
        Test.stopTest();

        Assert.isNotNull(generatedAccount.Id);
        Assert.isTrue(generatedAccount.Name.startsWith(XFTY_DefaultAccountDataProvider.DEFAULT_NAME_PREFIX));
        Assert.areEqual(XFTY_DefaultAccountDataProvider.DEFAULT_INDUSTRY, generatedAccount.Industry);
        Assert.areEqual(1, [SELECT COUNT() FROM Account]);
    }

    // Contact ---------------------------------------------------------------

    @IsTest
    static void accountProviderCreateBundleProducesAPopulatedAccount() {
        XFTY_DummySObjectBundle bundle;
        System.runAs(TEST_ADMIN) {
            bundle = new XFTY_DefaultAccountDataProvider().createBundle(
                    new XFTY_GenerationContext(LOOKUP, XFTY_InsertModeEnum.MOCK, XFTY_InsertInclusivityEnum.NONE),
                    new List<SObject>{ new Account() }
            );
        }

        Account account = (Account) bundle.getList(Account.Id)[0];
        Assert.isNotNull(account.Id);
        Assert.areEqual(XFTY_DefaultAccountDataProvider.DEFAULT_INDUSTRY, account.Industry);
        Assert.areEqual(XFTY_DefaultAccountDataProvider.DEFAULT_SHIPPING_COUNTRY, account.ShippingCountry);
    }

    @IsTest
    static void contactProviderDeclaresARequiredAccountRelationship() {
        XFTY_DummySObjectMasterTemplate template = new XFTY_DefaultContactDataProvider().getMasterTemplate();
        Assert.isTrue(
                template.requiredRelationshipBySObjectFieldMap.containsKey(Contact.AccountId),
                'Contact should require an Account'
        );
    }

    @IsTest
    static void contactProviderGeneratesUniqueEmailsPerRecord() {
        List<SObject> contacts;
        Test.startTest();
        System.runAs(TEST_ADMIN) {
            contacts = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .setQuantityPerTemplate(3)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supplyList();
        }
        Test.stopTest();

        Set<Object> emails = new Set<Object>();
        for (SObject generatedContact : contacts) {
            emails.add(generatedContact.get(Contact.Email));
        }
        Assert.areEqual(3, emails.size(), 'Each generated Contact should get its own email');
    }

    // User ----------------------------------------------------------------

    @IsTest
    static void userProviderExposesAReadyMadeAdminUser() {
        Assert.isNotNull(TEST_ADMIN, 'TEST_ADMIN_USER should be available');
        Assert.isNotNull(TEST_ADMIN.Id);

        Profile adminProfile = [SELECT Name FROM Profile WHERE Id = :TEST_ADMIN.ProfileId];
        Assert.areEqual('System Administrator', adminProfile.Name);
    }

    @IsTest
    static void userProviderMasterTemplateCoversTheFieldsRequiredToInsertAUser() {
        XFTY_DummySObjectMasterTemplate template = new XFTY_DefaultUserDataProvider().getMasterTemplate();

        for (SObjectField required : new List<SObjectField>{
                User.Alias, User.Email, User.EmailEncodingKey, User.LanguageLocaleKey,
                User.LastName, User.LocaleSidKey, User.ProfileId, User.TimeZoneSidKey, User.Username
        }) {
            Assert.isTrue(
                    template.defaultBySObjectFieldMap.containsKey(required),
                    'Master template should populate ' + required
            );
        }
    }

    @IsTest
    static void userProviderGeneratesAnInsertableUser() {
        User generated;
        Test.startTest();
        System.runAs(TEST_ADMIN) {
            generated = (User) new XFTY_DummySObjectProvider(User.SObjectType, LOOKUP)
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .supply();
        }
        Test.stopTest();

        Assert.isNotNull(generated.Id);
        Assert.isTrue(generated.Username.contains(XFTY_DefaultUserDataProvider.DEFAULT_USERNAME_PREFIX));
    }

    @IsTest
    static void profileIdForResolvesAndCaches() {
        Integer before = Limits.getQueries();
        Id adminId = XFTY_DefaultUserDataProvider.profileIdFor(XFTY_DefaultUserDataProvider.SYSTEM_ADMIN);
        XFTY_DefaultUserDataProvider.profileIdFor(XFTY_DefaultUserDataProvider.SYSTEM_ADMIN); // cached
        // The first call already ran during static init (TEST_ADMIN), so no new query here.
        Assert.areEqual(before, Limits.getQueries(), 'resolution is cached across calls');
        Assert.areEqual(TEST_ADMIN.ProfileId, adminId);
    }

    @IsTest
    static void profileIdForThrowsForAnUnknownProfile() {
        try {
            XFTY_DefaultUserDataProvider.profileIdFor('No Such Profile Name');
            Assert.fail('Expected an UnknownReferenceException');
        } catch (XFTY_DefaultUserDataProvider.UnknownReferenceException ex) {
            Assert.isTrue(ex.getMessage().contains('No Such Profile Name'), ex.getMessage());
        }
    }

    @IsTest
    static void roleIdForResolvesByDeveloperNameAndCaches() {
        UserRole role = new UserRole(Name = 'XFTY Coverage Role', DeveloperName = 'XFTY_Coverage_Role');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert role;
        }

        Integer queriesAfterFirst;
        Id resolved = XFTY_DefaultUserDataProvider.roleIdFor('XFTY_Coverage_Role');
        queriesAfterFirst = Limits.getQueries();
        Assert.areEqual(role.Id, resolved);
        Assert.areEqual(role.Id, XFTY_DefaultUserDataProvider.roleIdFor('XFTY_Coverage_Role'), 'cached on repeat');
        Assert.areEqual(queriesAfterFirst, Limits.getQueries(), 'the second call does not re-query');
    }

    @IsTest
    static void roleIdForThrowsForAnUnknownRole() {
        try {
            XFTY_DefaultUserDataProvider.roleIdFor('XFTY_No_Such_Role');
            Assert.fail('Expected an UnknownReferenceException');
        } catch (XFTY_DefaultUserDataProvider.UnknownReferenceException ex) {
            Assert.isTrue(ex.getMessage().contains('XFTY_No_Such_Role'), ex.getMessage());
        }
    }

    @IsTest
    static void aRoleCanBeAppliedViaAnOverrideTemplate() {
        // Assigning the role at insert time is a platform concern; this only checks
        // that roleIdFor(...) plugs into the normal override-template flow.
        UserRole role = new UserRole(Name = 'XFTY Override Role', DeveloperName = 'XFTY_Override_Role');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert role;
        }

        XFTY_DummySObjectBundle bundle;
        Test.startTest();
        System.runAs(TEST_ADMIN) {
            bundle = new XFTY_DummySObjectProvider(User.SObjectType, LOOKUP)
                    .setOverrideTemplate(new User(UserRoleId = XFTY_DefaultUserDataProvider.roleIdFor('XFTY_Override_Role')))
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supplyBundle();
        }
        Test.stopTest();

        User generated = (User) bundle.getList(User.Id)[0];
        Assert.areEqual(role.Id, generated.UserRoleId);
    }
}

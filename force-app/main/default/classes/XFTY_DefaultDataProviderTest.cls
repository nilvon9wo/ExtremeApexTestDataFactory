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

    // RecordType --------------------------------------------------------

    @IsTest
    static void recordTypeProviderReturnsNullForAnUnknownDeveloperName() {
        Assert.isNull(XFTY_RecordTypeDataProvider.getFor(Account.SObjectType, 'This_Does_Not_Exist'));
    }
}

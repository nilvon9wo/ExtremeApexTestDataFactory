/**
 * End-to-end generation scenarios through `XFTY_DummySObjectProvider`: request a
 * Contact and get a valid Account graph too, in-database persistence, and MOCK
 * mode not touching the database. Fine-grained API guards go in
 * `XFTY_DummySObjectProviderApiTest`.
 */
@IsTest
private class XFTY_DummySObjectProviderScenarioTest {

    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;
    private static final String TEST_CONTACT_FIRST_NAME = 'Fred';

    // NOW mode - real DML, so System.runAs -------------------------

    @IsTest
    static void testSupplyBundle_withRequiredInclusivity_generatesTheContactAndItsAccount() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setOverrideTemplateList(contactTemplateList())
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED);

        // Act
        XFTY_DummySObjectBundle bundle;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            bundle = provider.supplyBundle();
            Test.stopTest();
        }

        // Assert
        assertContactGenerated(bundle);
        Assert.isNotNull(bundle.getList(Contact.AccountId));
        Assert.isNotNull(bundle.getBundle(Contact.AccountId));
        Assert.isNotNull(((Contact) bundle.getList(Contact.Id)[0]).AccountId, 'the FK is wired');
    }

    @IsTest
    static void testSupplyBundle_inNowModeWithAllInclusivity_insertsBothRecordsWithTheFkWired() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setOverrideTemplateList(contactTemplateList())
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .setInclusivity(XFTY_InsertInclusivityEnum.ALL);

        // Act
        XFTY_DummySObjectBundle bundle;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            bundle = provider.supplyBundle();
            Test.stopTest();
        }

        // Assert
        assertContactGenerated(bundle);
        assertAccountGenerated(bundle);
        Assert.areEqual(
                ((Contact) bundle.getList(Contact.Id)[0]).AccountId,
                bundle.getList(Contact.AccountId)[0].Id
        );
    }

    @IsTest
    static void testUpdate_onRecordsFromANowRun_succeeds() {
        // Arrange
        List<Contact> generated;
        System.runAs(TEST_ADMIN) {
            generated = (List<Contact>) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .setOverrideTemplateList(contactTemplateList())
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .setInclusivity(XFTY_InsertInclusivityEnum.ALL)
                    .supplyList();
        }

        // Act
        List<Database.SaveResult> results;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            results = Database.update(generated);
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(generated.size(), results.size());
        for (Database.SaveResult result : results) {
            Assert.isTrue(result.isSuccess(), String.valueOf(result.getErrors()));
        }
    }

    // MOCK mode - no DML during generation, so no System.runAs -----

    @IsTest
    static void testSupplyBundle_inMockMode_wiresTheGraphWithoutTouchingTheDatabase() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setOverrideTemplateList(contactTemplateList())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.ALL);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        assertContactGenerated(bundle);
        assertAccountGenerated(bundle);
        Assert.areEqual(
                ((Contact) bundle.getList(Contact.Id)[0]).AccountId,
                bundle.getList(Contact.AccountId)[0].Id,
                'mock Ids still wire the FK'
        );
    }

    @IsTest
    static void testUpdate_onRecordsFromAMockRun_failsBecauseTheyAreNotReal() {
        // Arrange
        List<Contact> mocked = (List<Contact>) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setOverrideTemplateList(contactTemplateList())
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .setInclusivity(XFTY_InsertInclusivityEnum.ALL)
                .supplyList();

        // Act
        DmlException thrown;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            try {
                update mocked;
            } catch (DmlException ex) {
                thrown = ex;
            }
            Test.stopTest();
        }

        // Assert
        Assert.isNotNull(thrown, 'mock records are not real - DML must fail');
        Assert.isTrue(thrown.getMessage().contains('INVALID_CROSS_REFERENCE_KEY'), thrown.getMessage());
    }

    @IsTest
    static void testSupply_withNoInclusivity_generatesOnlyTheContact() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setOverrideTemplateList(contactTemplateList())
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        Contact result = (Contact) provider.supply();
        Test.stopTest();

        // Assert
        assertContactGenerated(result);
        Assert.isNull(result.AccountId, 'no inclusivity -> no Account');
    }

    @IsTest
    static void testSupply_withOnlyAType_appliesTheMasterTemplateDefaults() {
        // Arrange
        XFTY_DummySObjectProvider provider = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        Contact result = (Contact) provider.supply();
        Test.stopTest();

        // Assert
        Assert.isTrue(result.FirstName.contains(XFTY_DefaultContactDataProvider.DEFAULT_FIRST_NAME_PREFIX));
        Assert.isTrue(result.LastName.contains(XFTY_DefaultContactDataProvider.DEFAULT_LAST_NAME_PREFIX));
    }

    // Helpers -----------------------------------------------------

    private static List<Contact> contactTemplateList() {
        return new List<Contact>{ new Contact(FirstName = TEST_CONTACT_FIRST_NAME) };
    }

    private static void assertAccountGenerated(XFTY_DummySObjectBundle bundle) {
        Assert.isNotNull(bundle.getBundle(Contact.AccountId));
        List<Account> accounts = bundle.getList(Contact.AccountId);
        Assert.isNotNull(accounts);

        Account generatedAccount = accounts[0];
        Assert.isNotNull(generatedAccount.Id);
        Assert.isTrue(generatedAccount.Name.contains(XFTY_DefaultAccountDataProvider.DEFAULT_NAME_PREFIX));
        Assert.areEqual(XFTY_DefaultContactDataProvider.DEFAULT_ACCOUNT_DESCRIPTION, generatedAccount.Description);
    }

    private static void assertContactGenerated(XFTY_DummySObjectBundle bundle) {
        List<Contact> contacts = bundle.getList(Contact.Id);
        Assert.isNotNull(contacts);
        assertContactGenerated(contacts[0]);
    }

    private static void assertContactGenerated(Contact generatedContact) {
        Assert.isNotNull(generatedContact.Id);
        Assert.areEqual(TEST_CONTACT_FIRST_NAME, generatedContact.FirstName);
        Assert.isTrue(generatedContact.LastName.contains(XFTY_DefaultContactDataProvider.DEFAULT_LAST_NAME_PREFIX));
    }
}

/**
 * End-to-end generation scenarios through `XFTY_DummySObjectProvider`: request a
 * Contact and get a valid Account graph too, in-database persistence, MOCK not
 * touching the database. Add a test here for a "does the whole flow work" case;
 * fine-grained API guards go in `XFTY_DummySObjectProviderApiTest`.
 */
@IsTest
private class XFTY_DummySObjectProviderScenarioTest {
    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;
    private static final String TEST_CONTACT_FIRST_NAME = 'Fred';

    @IsTest
    static void supplyBundleGivesTheContactAndItsGeneratedAccount() {
        // Arrange
        List<Contact> templates = contactTemplateList();

        // Act
        XFTY_DummySObjectBundle bundle;
        Test.startTest();
        System.runAs(TEST_ADMIN) {
            bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .setOverrideTemplateList(templates)
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .supplyBundle();
        }
        Test.stopTest();

        // Assert
        assertContactGenerated(bundle);
        Assert.isNotNull(bundle.getList(Contact.AccountId));
        Assert.isNotNull(bundle.getBundle(Contact.AccountId));
        Assert.isNotNull(((Contact) bundle.getList(Contact.Id)[0]).AccountId);
    }

    @IsTest
    static void nowInsertsBothRecordsAndTheyCanBeUpdated() {
        // Arrange
        List<Contact> templates = contactTemplateList();

        // Act
        XFTY_DummySObjectBundle bundle;
        Test.startTest();
        System.runAs(TEST_ADMIN) {
            bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .setOverrideTemplateList(templates)
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .setInclusivity(XFTY_InsertInclusivityEnum.ALL)
                    .supplyBundle();
        }
        Test.stopTest();

        // Assert
        assertContactGenerated(bundle);
        assertAccountGenerated(bundle);
        Assert.areEqual(
                ((Contact) bundle.getList(Contact.Id)[0]).AccountId,
                bundle.getList(Contact.AccountId)[0].Id
        );

        List<Database.SaveResult> results = Database.update(bundle.getList(Contact.Id));
        Assert.areEqual(bundle.getList(Contact.Id).size(), results.size());
        for (Database.SaveResult result : results) {
            Assert.isTrue(result.isSuccess());
        }
    }

    @IsTest
    static void mockWiresTheGraphButDmlOnItFails() {
        // Arrange
        List<Contact> templates = contactTemplateList();

        // Act
        XFTY_DummySObjectBundle bundle;
        Test.startTest();
        System.runAs(TEST_ADMIN) {
            bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .setOverrideTemplateList(templates)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .setInclusivity(XFTY_InsertInclusivityEnum.ALL)
                    .supplyBundle();
        }
        Test.stopTest();

        // Assert
        assertContactGenerated(bundle);
        assertAccountGenerated(bundle);
        Assert.areEqual(
                ((Contact) bundle.getList(Contact.Id)[0]).AccountId,
                bundle.getList(Contact.AccountId)[0].Id
        );

        DmlException caught;
        try {
            update bundle.getList(Contact.Id);
        } catch (DmlException ex) {
            caught = ex;
        }
        Assert.isNotNull(caught, 'mock records are not real - DML must fail');
        Assert.isTrue(caught.getMessage().contains('INVALID_CROSS_REFERENCE_KEY'), caught.getMessage());
    }

    @IsTest
    static void withNoInclusivityOnlyTheContactIsGenerated() {
        // Arrange
        List<Contact> templates = contactTemplateList();

        // Act
        Contact result;
        Test.startTest();
        System.runAs(TEST_ADMIN) {
            result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .setOverrideTemplateList(templates)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supply();
        }
        Test.stopTest();

        // Assert
        assertContactGenerated(result);
        Assert.isNull(result.AccountId, 'no inclusivity -> no Account');
    }

    @IsTest
    static void withOnlyATypeTheContactGetsMasterTemplateDefaults() {
        // Act
        Contact result;
        Test.startTest();
        System.runAs(TEST_ADMIN) {
            result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supply();
        }
        Test.stopTest();

        // Assert
        Assert.isTrue(result.FirstName.contains(XFTY_DefaultContactDataProvider.DEFAULT_FIRST_NAME_PREFIX));
        Assert.isTrue(result.LastName.contains(XFTY_DefaultContactDataProvider.DEFAULT_LAST_NAME_PREFIX));
    }

    // Helpers ------------------------------------------------------------------

    private static List<Contact> contactTemplateList() {
        return new List<Contact>{ new Contact(FirstName = TEST_CONTACT_FIRST_NAME) };
    }

    private static void assertAccountGenerated(XFTY_DummySObjectBundle bundle) {
        Assert.isNotNull(bundle.getBundle(Contact.AccountId));
        List<Account> accounts = bundle.getList(Contact.AccountId);
        Assert.isNotNull(accounts);

        Account account = accounts[0];
        Assert.isNotNull(account.Id);
        Assert.isTrue(account.Name.contains(XFTY_DefaultAccountDataProvider.DEFAULT_NAME_PREFIX));
        Assert.areEqual(XFTY_DefaultContactDataProvider.DEFAULT_ACCOUNT_DESCRIPTION, account.Description);
    }

    private static void assertContactGenerated(XFTY_DummySObjectBundle bundle) {
        List<Contact> contacts = bundle.getList(Contact.Id);
        Assert.isNotNull(contacts);
        assertContactGenerated(contacts[0]);
    }

    private static void assertContactGenerated(Contact contact) {
        Assert.isNotNull(contact.Id);
        Assert.areEqual(TEST_CONTACT_FIRST_NAME, contact.FirstName);
        Assert.isTrue(contact.LastName.contains(XFTY_DefaultContactDataProvider.DEFAULT_LAST_NAME_PREFIX));
    }
}

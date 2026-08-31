@IsTest
public class XFTY_DefaultContactDataProviderTest {
    private static final XFTY_DefaultSObjectProviderLookup DEFAULT_SOBJECT_PROVIDER = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;
    private static final String TEST_CONTACT_FIRST_NAME = 'Fred';

    @IsTest public static void testContactFactoryCreatesOnlyContact() {
        // Arrange
        List<Contact> templateContactList = createTestTemplateContactList();

        // Act
        XFTY_DummySObjectBundle resultBundle;
        Test.startTest();
        System.runAs(TEST_ADMIN) {
            resultBundle = (new XFTY_DummySObjectProvider(Contact.SObjectType, DEFAULT_SOBJECT_PROVIDER))
                    .setOverrideTemplateList(templateContactList)
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .setInclusivity(XFTY_InsertInclusivityEnum.NONE)
                    .supplyBundle();
        }
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, resultBundle);
        assertContactsCreated(resultBundle);

        System.assertEquals(null, resultBundle.getList(Contact.AccountId));
        System.assertEquals(null, resultBundle.getBundle(Contact.AccountId));
        System.assertEquals(null, ((Contact) resultBundle.getList(Contact.Id)[0]).AccountId);
    }


    @IsTest public static void testContactFactoryCreatesBothContactAndAccountInDatabase() {
        // Arrange
        List<Contact> templateContactList = createTestTemplateContactList();

        // Act
        XFTY_DummySObjectBundle resultBundle;
        Test.startTest();
        System.runAs(TEST_ADMIN) {
            resultBundle = (new XFTY_DummySObjectProvider(Contact.SObjectType, DEFAULT_SOBJECT_PROVIDER))
                    .setOverrideTemplateList(templateContactList)
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .setInclusivity(XFTY_InsertInclusivityEnum.ALL)
                    .supplyBundle();
        }
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, resultBundle);
        assertContactsCreated(resultBundle);
        assertAccountsCreated(resultBundle);

        System.assertEquals(
                ((Contact) resultBundle.getList(Contact.Id)[0]).AccountId,
                resultBundle.getList(Contact.AccountId)[0].Id
        );

        List<Database.SaveResult> saveResultList = Database.update(resultBundle.getList(Contact.Id));
        System.assertEquals(resultBundle.getList(Contact.Id).size(), saveResultList.size());
        for (Database.SaveResult saveResult : saveResultList) {
            System.assert(saveResult.isSuccess());
        }
    }

    @IsTest public static void testContactFactoryCreatesBothContactAndAccountWithoutTouchingDatabase() {
        // Arrange
        List<Contact> templateContactList = createTestTemplateContactList();

        // Act
        XFTY_DummySObjectBundle resultBundle;
        Test.startTest();
        System.runAs(TEST_ADMIN) {
            resultBundle = (new XFTY_DummySObjectProvider(Contact.SObjectType, DEFAULT_SOBJECT_PROVIDER))
                    .setOverrideTemplateList(templateContactList)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .setInclusivity(XFTY_InsertInclusivityEnum.ALL)
                    .supplyBundle();
        }
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, resultBundle);
        assertContactsCreated(resultBundle);
        assertAccountsCreated(resultBundle);

        System.assertEquals(
                ((Contact) resultBundle.getList(Contact.Id)[0]).AccountId,
                resultBundle.getList(Contact.AccountId)[0].Id
        );

        DmlException caughtException;
        try {
            update resultBundle.getList(Contact.Id);
        } catch (DmlException ex) {
            caughtException = ex;
        }
        System.assertNotEquals(null, caughtException);
        System.assert(caughtException.getMessage().contains('INVALID_CROSS_REFERENCE_KEY'));
    }


    private static List<Contact> createTestTemplateContactList() {
        return new List<Contact>{
                new Contact(
                        FirstName = TEST_CONTACT_FIRST_NAME
                )
        };
    }

    private static void assertAccountsCreated(XFTY_DummySObjectBundle resultBundle) {
        System.assertNotEquals(null, resultBundle.getBundle(Contact.AccountId));
        List<Account> resultAccountList = resultBundle.getList(Contact.AccountId);
        System.assertNotEquals(null, resultAccountList);

        Account resultAccount = resultAccountList[0];
        System.assertNotEquals(null, resultAccount.Id);
        System.assert(resultAccount.Name.contains(XFTY_DefaultAccountDataProvider.DEFAULT_NAME_PREFIX));
        System.assertEquals(resultAccount.Description, XFTY_DefaultContactDataProvider.DEFAULT_ACCOUNT_DESCRIPTION);
    }

    private static void assertContactsCreated(XFTY_DummySObjectBundle resultBundle) {
        List<Contact> resultContactList = resultBundle.getList(Contact.Id);
        System.assertNotEquals(null, resultContactList);

        Contact resultContact = resultContactList[0];
        System.assertNotEquals(null, resultContact.Id);
        System.assertEquals(TEST_CONTACT_FIRST_NAME, resultContact.FirstName);
        System.assert(resultContact.LastName.contains(XFTY_DefaultContactDataProvider.DEFAULT_LAST_NAME_PREFIX));
    }


}
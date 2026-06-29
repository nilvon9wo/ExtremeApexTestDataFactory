@IsTest
public class XFTY_DummySObjectProviderTests {
    private static final XFTY_DefaultSObjectProviderLookup DEFAULT_SOBJECT_PROVIDER = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;
    private static final String TEST_CONTACT_FIRST_NAME = 'Fred';

    // Create Bundle Tests -------------------------------------------------------------

    @IsTest public static void testSupplyBundleShouldCreateContactWithAccount() {
        // Arrange
        List<Contact> templateContactList = createTestTemplateContactList();

        // Act
        XFTY_DummySObjectBundle resultBundle;
        Test.startTest();
        System.runAs(TEST_ADMIN) {
            resultBundle = (new XFTY_DummySObjectProvider(Contact.SObjectType, DEFAULT_SOBJECT_PROVIDER))
                    .setOverrideTemplateList(templateContactList)
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .supplyBundle();
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(resultBundle);
        assertContactsCreated(resultBundle);

        Assert.isNotNull(resultBundle.getList(Contact.AccountId));
        Assert.isNotNull(resultBundle.getBundle(Contact.AccountId));
        Assert.isNotNull(((Contact) resultBundle.getList(Contact.Id)[0]).AccountId);
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

    // Create Instance Tests -------------------------------------------------------------

    @IsTest public static void testSupplyShouldCreateOnlyContactWhenTemplateIsSet() {
        // Arrange
        List<Contact> templateContactList = createTestTemplateContactList();

        // Act
        Contact resultContact;
        Test.startTest();
        System.runAs(TEST_ADMIN) {
            resultContact = (Contact) (new XFTY_DummySObjectProvider(Contact.SObjectType, DEFAULT_SOBJECT_PROVIDER))
                    .setOverrideTemplateList(templateContactList)
                    .setInsertMode(XFTY_InsertModeEnum.MOCK)
                    .supply();
        }
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, resultContact);
        assertContactCreated(resultContact);

        System.assertEquals(null, resultContact.AccountId);
    }

    @IsTest public static void testSupplyShouldCreateOnlyContactWhenTypeIsSet() {
        // Arrange
        createTestTemplateContactList();

        // Act
        Contact resultContact;
        Test.startTest();
        System.runAs(TEST_ADMIN) {
            resultContact = (Contact) (new XFTY_DummySObjectProvider(Contact.SObjectType, DEFAULT_SOBJECT_PROVIDER))
                    .supply();
        }
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, resultContact);
        System.assert(resultContact.FirstName.contains(XFTY_DefaultContactDataProvider.DEFAULT_FIRST_NAME_PREFIX));
        System.assert(resultContact.LastName.contains(XFTY_DefaultContactDataProvider.DEFAULT_LAST_NAME_PREFIX));
    }

    @SuppressWarnings('PMD.UnusedLocalVariable')
    @IsTest public static void testSupplyShouldThrowFriendlyExceptionWhenNoSObjectTypeProvided() {
        // Arrange
        createTestTemplateContactList();

        // Act
        XFTY_DummySObjectProvider.SanityException caughtException;
        Test.startTest();
        System.runAs(TEST_ADMIN) {
            try {
                //noinspection ApexUnusedDeclaration - We need this unused variable, because `new X()` can't be a statement.
                XFTY_DummySObjectProvider supplier = (new XFTY_DummySObjectProvider(null, DEFAULT_SOBJECT_PROVIDER));
            } catch (XFTY_DummySObjectProvider.SanityException ex) {
                caughtException = ex;
            }
        }
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, caughtException);
        System.assert(caughtException.getMessage().contains('SObjectType to request data'));
    }

    // Helpers ------------------------------------------------------------------------------------

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
        assertContactCreated(resultContactList[0]);
    }

    private static void assertContactCreated(Contact resultContact) {
        System.assertNotEquals(null, resultContact.Id);
        System.assertEquals(TEST_CONTACT_FIRST_NAME, resultContact.FirstName);
        System.assert(resultContact.LastName.contains(XFTY_DefaultContactDataProvider.DEFAULT_LAST_NAME_PREFIX));
    }


}
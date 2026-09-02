/**
 * Proves `XFTY_DefaultContactDataProvider` end to end: a generated Contact, its
 * required Account (with the documented defaults), and the inclusivity that
 * controls whether that Account is generated. Real DML in the NOW tests, so
 * `System.runAs`.
 */
@IsTest
private class XFTY_DefaultContactDataProviderTest {

    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;
    private static final String TEST_FIRST_NAME = 'Fred';

    private static XFTY_DummySObjectProvider contactProvider(XFTY_InsertInclusivityEnum inclusivity, XFTY_InsertModeEnum mode) {
        return new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setOverrideTemplate(new Contact(FirstName = TEST_FIRST_NAME))
                .setInclusivity(inclusivity)
                .setInsertMode(mode);
    }

    @IsTest
    static void testSupplyBundle_atNoneInclusivity_generatesTheContactButNotAnAccount() {
        // Arrange
        XFTY_DummySObjectProvider provider = contactProvider(XFTY_InsertInclusivityEnum.NONE, XFTY_InsertModeEnum.NOW);

        // Act
        XFTY_DummySObjectBundle bundle;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            bundle = provider.supplyBundle();
            Test.stopTest();
        }

        // Assert
        assertContactGenerated(bundle);
        Assert.isNull(bundle.getList(Contact.AccountId), 'no Account generated at NONE inclusivity');
        Assert.isNull(((Contact) bundle.getList(Contact.Id)[0]).AccountId);
    }

    @IsTest
    static void testSupplyBundle_atAllInclusivityInNowMode_generatesTheContactAndItsAccountWithTheDocumentedDefaults() {
        // Arrange
        XFTY_DummySObjectProvider provider = contactProvider(XFTY_InsertInclusivityEnum.ALL, XFTY_InsertModeEnum.NOW);

        // Act
        XFTY_DummySObjectBundle bundle;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            bundle = provider.supplyBundle();
            Test.stopTest();
        }

        // Assert
        assertContactGenerated(bundle);
        Account generatedAccount = (Account) bundle.getList(Contact.AccountId)[0];
        Assert.isNotNull(generatedAccount.Id);
        Assert.isTrue(generatedAccount.Name.contains(XFTY_DefaultAccountDataProvider.DEFAULT_NAME_PREFIX));
        Assert.areEqual(XFTY_DefaultContactDataProvider.DEFAULT_ACCOUNT_DESCRIPTION, generatedAccount.Description);
        Assert.areEqual(generatedAccount.Id, ((Contact) bundle.getList(Contact.Id)[0]).AccountId, 'the FK is wired');
    }

    @IsTest
    static void testUpdate_onRecordsFromANowRun_succeeds() {
        // Arrange
        List<Contact> generated;
        System.runAs(TEST_ADMIN) {
            generated = (List<Contact>) contactProvider(XFTY_InsertInclusivityEnum.ALL, XFTY_InsertModeEnum.NOW).supplyList();
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

    @IsTest
    static void testSupplyBundle_atAllInclusivityInMockMode_wiresTheGraphWithoutTouchingTheDatabase() {
        // Arrange
        XFTY_DummySObjectProvider provider = contactProvider(XFTY_InsertInclusivityEnum.ALL, XFTY_InsertModeEnum.MOCK);

        // Act
        Test.startTest();
        XFTY_DummySObjectBundle bundle = provider.supplyBundle();
        Test.stopTest();

        // Assert
        assertContactGenerated(bundle);
        Assert.isNotNull(bundle.getList(Contact.AccountId)[0].Id, 'the Account got a mock Id');
        Assert.areEqual(
                bundle.getList(Contact.AccountId)[0].Id,
                ((Contact) bundle.getList(Contact.Id)[0]).AccountId,
                'mock Ids still wire the FK'
        );
    }

    // Master Template ------------------------------------

    @IsTest
    static void testGetMasterTemplate_declaresARequiredAccountRelationship() {
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
    static void testSupplyList_withQuantity_generatesAUniqueEmailPerRecord() {
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

    private static void assertContactGenerated(XFTY_DummySObjectBundle bundle) {
        Contact generated = (Contact) bundle.getList(Contact.Id)[0];
        Assert.isNotNull(generated.Id);
        Assert.areEqual(TEST_FIRST_NAME, generated.FirstName);
        Assert.isTrue(generated.LastName.contains(XFTY_DefaultContactDataProvider.DEFAULT_LAST_NAME_PREFIX));
    }
}

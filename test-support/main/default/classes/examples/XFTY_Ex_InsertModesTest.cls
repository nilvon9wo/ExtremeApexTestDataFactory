/**
 * Runnable proof for docs/use/insert-modes.md - every `@IsTest` method is one
 * fenced example (or one row of the modes table) from that page.
 */
@IsTest
private class XFTY_Ex_InsertModesTest {

    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    @IsTest
    static void testSupply_inNeverMode_generatesRecordsWithoutIds() {
        // Arrange
        // nothing to arrange - NEVER is the default

        // Act
        Contact result;
        Test.startTest();
        result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.NEVER)
                .supply();
        Test.stopTest();

        // Assert
        Assert.isNotNull(result.LastName, 'the data is generated');
        Assert.areEqual(null, result.Id, 'but there is no Id');
    }

    @IsTest
    static void testSupply_inMockMode_givesRealisticIdsWithoutDml() {
        // Arrange
        Integer dmlBefore = Limits.getDmlStatements();

        // Act
        Contact result;
        Test.startTest();
        result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        // Assert
        Assert.isNotNull(result.Id);
        Assert.areEqual(Contact.SObjectType, result.Id.getSObjectType(), 'a real-looking Contact Id');
        Assert.areEqual(dmlBefore, Limits.getDmlStatements(), 'no DML');
    }

    @IsTest
    static void testSupply_inNowMode_insertsEveryGeneratedRecord() {
        // Arrange
        // nothing to arrange

        // Act
        Contact result;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .supply();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(1, [SELECT COUNT() FROM Contact WHERE Id = :result.Id]);
        Assert.areEqual(1, [SELECT COUNT() FROM Account], 'the required parent was inserted too');
    }

    @IsTest
    static void testSupply_inRelatedOnlyMode_insertsTheParentsButNotThePrimaries() {
        // Arrange
        // nothing to arrange

        // Act
        Contact result;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.RELATED_ONLY)
                    .supply();
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(null, result.Id, 'the primary Contact is left uninserted');
        Assert.isNotNull(result.AccountId, 'but it points at a real, inserted Account');
        Assert.areEqual(1, [SELECT COUNT() FROM Account]);
        Assert.areEqual(0, [SELECT COUNT() FROM Contact]);
    }

    @IsTest
    static void testSupply_theGeneratedDataIsIdenticalRegardlessOfMode() {
        // Arrange
        Contact template = new Contact(FirstName = 'Sam', LastName = 'Jones');

        // Act
        Contact fromNever;
        Contact fromMock;
        Test.startTest();
        fromNever = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setOverrideTemplate(template.clone(false, true, false, false))
                .setInsertMode(XFTY_InsertModeEnum.NEVER)
                .supply();
        fromMock = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setOverrideTemplate(template.clone(false, true, false, false))
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        // Assert
        Assert.areEqual(fromNever.FirstName, fromMock.FirstName);
        Assert.areEqual(fromNever.LastName, fromMock.LastName);
    }
}

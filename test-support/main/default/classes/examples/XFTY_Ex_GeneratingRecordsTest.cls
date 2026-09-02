/**
 * Runnable proof for docs/use/generating-records.md - every `@IsTest` method
 * here is one fenced example from that page.
 */
@IsTest
private class XFTY_Ex_GeneratingRecordsTest {

    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();

    @IsTest
    static void testSupply_onABareProvider_returnsOneRecordWithDefaultsAndNoId() {
        // Arrange
        // nothing to arrange - a bare Provider generates one record with defaults

        // Act
        Contact result;
        Test.startTest();
        result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .supply();
        Test.stopTest();

        // Assert
        Assert.isNotNull(result, 'supply() returns the one generated primary record');
        Assert.isNotNull(result.LastName, 'default values were filled');
        Assert.areEqual(null, result.Id, 'not inserted by default (NEVER mode)');
    }

    @IsTest
    static void testSupplyList_withQuantity_returnsThatManyCopies() {
        // Arrange
        // nothing to arrange

        // Act
        List<Contact> results;
        Test.startTest();
        results = (List<Contact>) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setQuantityPerTemplate(5)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supplyList();
        Test.stopTest();

        // Assert
        Assert.areEqual(5, results.size());
    }

    @IsTest
    static void testSupplyBundle_returnsTheWholeGeneratedGraph() {
        // Arrange
        // nothing to arrange

        // Act
        XFTY_DummySObjectBundle bundle;
        Test.startTest();
        bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supplyBundle();
        Test.stopTest();

        // Assert
        Assert.areEqual(1, bundle.getList(Contact.Id).size(), 'the requested Contact');
        Assert.areEqual(1, bundle.getList(Contact.AccountId).size(), 'and its generated Account');
    }

    @IsTest
    static void testSupplyList_withATemplateList_appliesEachTemplateToItsRow() {
        // Arrange
        List<Contact> templates = new List<Contact>{
                new Contact(FirstName = 'Alice'),
                new Contact(FirstName = 'Bob')
        };

        // Act
        List<Contact> results;
        Test.startTest();
        results = (List<Contact>) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setOverrideTemplateList(templates)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supplyList();
        Test.stopTest();

        // Assert
        Assert.areEqual(2, results.size());
        Assert.areEqual('Alice', results[0].FirstName);
        Assert.areEqual('Bob', results[1].FirstName);
        Assert.isNotNull(results[0].LastName, 'remaining values still come from the Master Template');
    }

    @IsTest
    static void testSupplyList_withATemplateListAndQuantity_appliesQuantityOutsideTheTemplateLoop() {
        // Arrange
        List<Contact> templates = new List<Contact>{
                new Contact(FirstName = 'Alice'),
                new Contact(FirstName = 'Bob')
        };

        // Act
        List<Contact> results;
        Test.startTest();
        results = (List<Contact>) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setOverrideTemplateList(templates)
                .setQuantityPerTemplate(2)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supplyList();
        Test.stopTest();

        // Assert - Alice, Bob, Alice, Bob - not Alice, Alice, Bob, Bob
        Assert.areEqual(4, results.size());
        Assert.areEqual('Alice', results[0].FirstName);
        Assert.areEqual('Bob', results[1].FirstName);
        Assert.areEqual('Alice', results[2].FirstName);
        Assert.areEqual('Bob', results[3].FirstName);
    }

    @IsTest
    static void testConstructor_fromASingleTemplate_derivesTheType() {
        // Arrange
        // nothing to arrange - the single-template constructor is under test

        // Act
        Contact result;
        Test.startTest();
        result = (Contact) new XFTY_DummySObjectProvider(new Contact(FirstName = 'Alice'), LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        // Assert
        Assert.areEqual('Alice', result.FirstName);
        Assert.isNotNull(result.Id);
    }

    @IsTest
    static void testConstructor_fromATemplateList_derivesTheTypeFromTheFirstTemplate() {
        // Arrange
        // nothing to arrange - the template-list constructor is under test

        // Act
        List<Contact> results;
        Test.startTest();
        results = (List<Contact>) new XFTY_DummySObjectProvider(new List<Contact>{ new Contact(), new Contact() }, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supplyList();
        Test.stopTest();

        // Assert
        Assert.areEqual(2, results.size());
    }

    @IsTest
    static void testConstructor_fromALookupKey_derivesTheTypeAndPinsTheVariant() {
        // Arrange
        // nothing to arrange - the lookup-key constructor is under test

        // Act
        Contact result;
        Test.startTest();
        result = (Contact) new XFTY_DummySObjectProvider(XFTY_LookupKey.get(Contact.SObjectType), LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        // Assert
        Assert.isNotNull(result.Id);
        Assert.isNotNull(result.LastName);
    }
}

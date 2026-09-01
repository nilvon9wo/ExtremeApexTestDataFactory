/**
 * Runnable proof for docs/use/generating-records.md - every `@IsTest` method
 * here is one fenced example from that page.
 */
@IsTest
private class XFTY_Ex_GeneratingRecordsTest {

    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();

    @IsTest
    static void supplyReturnsOneGeneratedRecord() {
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
    static void supplyListReturnsManyCopiesOfOneTemplate() {
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
    static void supplyBundleReturnsTheWholeGraph() {
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
    static void aTemplateListGivesDifferentValuesPerRecord() {
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
    static void quantityIsAppliedOutsideTheTemplateLoop() {
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
    static void theTemplateShorthandConstructorDerivesTheType() {
        // Arrange
        Contact template = new Contact(FirstName = 'Alice');

        // Act
        Contact result;
        Test.startTest();
        result = (Contact) new XFTY_DummySObjectProvider(template, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        // Assert
        Assert.areEqual('Alice', result.FirstName);
        Assert.isNotNull(result.Id);
    }

    @IsTest
    static void theLookupKeyShorthandConstructorDerivesTheTypeAndPinsTheVariant() {
        // Arrange
        XFTY_LookupKeyIntf contactKey = XFTY_LookupKey.get(Contact.SObjectType);

        // Act
        Contact result;
        Test.startTest();
        result = (Contact) new XFTY_DummySObjectProvider(contactKey, LOOKUP)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        // Assert
        Assert.isNotNull(result.Id);
        Assert.isNotNull(result.LastName);
    }
}

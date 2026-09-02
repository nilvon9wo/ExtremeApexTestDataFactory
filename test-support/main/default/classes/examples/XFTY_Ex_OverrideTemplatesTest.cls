/**
 * Runnable proof for docs/use/override-templates.md - every `@IsTest` method is
 * one fenced example from that page.
 */
@IsTest
private class XFTY_Ex_OverrideTemplatesTest {

    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();

    @IsTest
    static void testSupply_withAnOverrideTemplate_replacesOnlyTheFieldsItSets() {
        // Arrange
        // nothing to arrange - the override template is inline, below

        // Act
        Contact result;
        Test.startTest();
        result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setOverrideTemplate(new Contact(FirstName = 'Alice', LastName = 'Smith'))
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        // Assert
        Assert.areEqual('Alice', result.FirstName);
        Assert.areEqual('Smith', result.LastName);
        Assert.isNotNull(result.Email, 'the email is still generated');
    }

    @IsTest
    static void testSupply_whenAnOverrideTemplateAndPutSetTheSameField_theOverrideWins() {
        // Arrange
        // nothing to arrange - the precedence is exercised entirely by the Provider config

        // Act
        Contact result;
        Test.startTest();
        result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .put(Contact.FirstName, new XFTY_LiteralExpression('Generated'))
                .setOverrideTemplate(new Contact(FirstName = 'Alice'))
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        // Assert
        Assert.areEqual('Alice', result.FirstName, 'the override template wins over put(...)');
    }

    @IsTest
    static void testRemoveFromMasterTemplate_dropsAFieldsGenerationEntirely() {
        // Arrange
        // nothing to arrange

        // Act
        Contact result;
        Test.startTest();
        result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .removeFromMasterTemplate(Contact.Email)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        // Assert
        Assert.areEqual(null, result.Email, 'the field is not generated, not replaced');
        Assert.isNotNull(result.LastName, 'other fields are untouched');
    }
}

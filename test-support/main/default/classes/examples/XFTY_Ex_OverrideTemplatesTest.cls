/**
 * Runnable proof for docs/use/override-templates.md - every `@IsTest` method is
 * one fenced example from that page.
 */
@IsTest
private class XFTY_Ex_OverrideTemplatesTest {

    private static final XFTY_DefaultSObjectProviderLookup PROVIDER_LOOKUP = new XFTY_DefaultSObjectProviderLookup();

    @IsTest
    static void anOverrideTemplateReplacesOnlyTheFieldsItSets() {
        // Arrange
        Contact template = new Contact(FirstName = 'Alice', LastName = 'Smith');

        // Act
        Contact result;
        Test.startTest();
        result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, PROVIDER_LOOKUP)
                .setOverrideTemplate(template)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        // Assert
        Assert.areEqual('Alice', result.FirstName);
        Assert.areEqual('Smith', result.LastName);
        Assert.isNotNull(result.Email, 'the email is still generated');
    }

    @IsTest
    static void theOverrideTemplateWinsOverAPutStrategy() {
        // Arrange
        // nothing to arrange - the precedence is exercised entirely by the Provider config

        // Act
        Contact result;
        Test.startTest();
        result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, PROVIDER_LOOKUP)
                .put(Contact.FirstName, new XFTY_DummyDefaultValueExact('Generated'))
                .setOverrideTemplate(new Contact(FirstName = 'Alice'))
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        // Assert
        Assert.areEqual('Alice', result.FirstName, 'the override template wins over put(...)');
    }

    @IsTest
    static void removeFromMasterTemplateDropsAFieldsGenerationEntirely() {
        // Arrange
        // nothing to arrange

        // Act
        Contact result;
        Test.startTest();
        result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, PROVIDER_LOOKUP)
                .removeFromMasterTemplate(Contact.Email)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        // Assert
        Assert.areEqual(null, result.Email, 'the field is not generated, not replaced');
        Assert.isNotNull(result.LastName, 'other fields are untouched');
    }
}

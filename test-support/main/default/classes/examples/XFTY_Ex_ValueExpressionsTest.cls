/**
 * Runnable proof for docs/use/value-expressions.md - every `@IsTest` method is
 * one fenced example from that page.
 */
@IsTest
private class XFTY_Ex_ValueExpressionsTest {

    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();

    @IsTest
    static void testSupplyList_withAnIncrementingStringExpression_producesADistinctValuePerRecord() {
        // Arrange
        // nothing to arrange

        // Act
        List<Contact> results;
        Test.startTest();
        results = (List<Contact>) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .put(Contact.FirstName, new XFTY_IncrementingStringExpression('Test Contact'))
                .setQuantityPerTemplate(3)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supplyList();
        Test.stopTest();

        // Assert
        Set<String> firstNames = new Set<String>();
        for (Contact contactRecord : results) {
            Assert.isTrue(contactRecord.FirstName.startsWith('Test Contact'), contactRecord.FirstName);
            firstNames.add(contactRecord.FirstName);
        }
        Assert.areEqual(3, firstNames.size(), 'each record got a distinct incrementing value');
    }

    @IsTest
    static void testSupply_withABareValue_wrapsItInALiteralExpression() {
        // Arrange
        // nothing to arrange - put(field, bareValue) is the shorthand under test

        // Act
        Account result;
        Test.startTest();
        result = (Account) new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .put(Account.Type, 'Customer')
                .put(Account.NumberOfEmployees, 500)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        // Assert
        Assert.areEqual('Customer', result.Type);
        Assert.areEqual(500, result.NumberOfEmployees);
    }

    @IsTest
    static void testSupply_theExplicitLiteralExpressionFormIsEquivalentToABareValue() {
        // Arrange
        // nothing to arrange - the explicit XFTY_LiteralExpression wrapper is under test

        // Act
        Account result;
        Test.startTest();
        result = (Account) new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
                .put(Account.Type, new XFTY_LiteralExpression('Customer'))
                .put(Account.NumberOfEmployees, new XFTY_LiteralExpression(500))
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supply();
        Test.stopTest();

        // Assert
        Assert.areEqual('Customer', result.Type);
        Assert.areEqual(500, result.NumberOfEmployees);
    }

    @IsTest
    static void testPut_withAPath_takesEveryValueFormOnAGeneratedAncestor() {
        // Arrange - 'mr-smith' is the ancestor Account's own generated owner
        XFTY_SharedAncestor.put('mr-smith', new User());

        // Act
        XFTY_DummySObjectBundle bundle;
        Test.startTest();
        bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)

                // an exact value
                .put(new List<SObjectField>{ Contact.AccountId, Account.Industry }, 'Aerospace')

                // an expression - the generated Account gets a unique name
                .put(new List<SObjectField>{ Contact.AccountId, Account.Name },
                     new XFTY_UniqueStringExpression('Acct'))

                // a context-aware value - evaluated against that ancestor
                .put(new List<SObjectField>{ Contact.AccountId, Account.Site },
                     new XFTY_CopyFromSiblingExpression(Account.Name))

                // a relationship - give the ancestor its own generated parent
                .putRequired(new List<SObjectField>{ Contact.AccountId, Account.OwnerId },
                     XFTY_SharedAncestor.get('mr-smith'))

                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supplyBundle();
        Test.stopTest();

        // Assert
        Account generatedAccount = (Account) bundle.getBundle(Contact.AccountId).getList(Account.Id)[0];
        Assert.areEqual('Aerospace', generatedAccount.Industry, 'exact value landed on the ancestor');
        Assert.isTrue(generatedAccount.Name.startsWith('Acct'), 'expression ran on the ancestor');
        Assert.areEqual(generatedAccount.Name, generatedAccount.Site, 'context-aware value evaluated against the ancestor');
        Assert.isNotNull(generatedAccount.OwnerId, 'the ancestor got its own generated owner via the forced relationship');
    }

    @IsTest
    static void testSupplyList_withAUniqueEmailExpression_neverCollidesWithinOneRun() {
        // Arrange
        // nothing to arrange

        // Act
        List<Contact> results;
        Test.startTest();
        results = (List<Contact>) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                .put(Contact.Email, new XFTY_UniqueEmailExpression('team.member'))
                .setQuantityPerTemplate(5)
                .setInsertMode(XFTY_InsertModeEnum.MOCK)
                .supplyList();
        Test.stopTest();

        // Assert
        Set<String> emails = new Set<String>();
        for (Contact contactRecord : results) {
            emails.add(contactRecord.Email);
        }
        Assert.areEqual(5, emails.size(), 'five distinct addresses');
    }
}

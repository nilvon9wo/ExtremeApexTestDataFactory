/**
 * Proves the small `XFTY_ValueExpressionIntf` implementations - pure value
 * producers, so no DML/SOQL and no `System.runAs`. They double as executable
 * documentation of what each expression guarantees (format, uniqueness scope,
 * statefulness).
 */
@IsTest
private class XFTY_ValueExpressionTest {

    // XFTY_LiteralExpression --------------------------------------

    @IsTest
    static void testGet_forAStringLiteral_returnsItUnchanged() {
        assertLiteralReturnsItself('Customer');
    }

    @IsTest
    static void testGet_forAnIntegerLiteral_returnsItUnchanged() {
        assertLiteralReturnsItself(42);
    }

    @IsTest
    static void testGet_forANullLiteral_returnsNull() {
        assertLiteralReturnsItself(null);
    }

    @IsTest
    static void testGet_forALiteral_returnsTheSameValueEveryCall() {
        // Arrange
        XFTY_LiteralExpression expression = new XFTY_LiteralExpression('constant');

        // Act
        Test.startTest();
        List<Object> twoCalls = new List<Object>{ expression.get(), expression.get() };
        Test.stopTest();

        // Assert
        Assert.areEqual(new List<Object>{ 'constant', 'constant' }, twoCalls);
    }

    // XFTY_IncrementingStringExpression --------------------------

    @IsTest
    static void testGet_forAnIncrementingString_separatesThePrefixAndCounterByDefault() {
        // Arrange
        XFTY_IncrementingStringExpression expression = new XFTY_IncrementingStringExpression('Account');

        // Act
        Test.startTest();
        List<Object> sequence = new List<Object>{ expression.get(), expression.get(), expression.get() };
        Test.stopTest();

        // Assert
        Assert.areEqual(new List<Object>{ 'Account 1', 'Account 2', 'Account 3' }, sequence);
    }

    @IsTest
    static void testGet_forAnIncrementingStringWithNoSeparator_joinsThePrefixAndCounter() {
        // Arrange
        XFTY_IncrementingStringExpression expression = new XFTY_IncrementingStringExpression(
                'ACME', XFTY_IncrementingStringExpression.DONT_SEPARATE_PREFIX
        );

        // Act
        Test.startTest();
        List<Object> sequence = new List<Object>{ expression.get(), expression.get() };
        Test.stopTest();

        // Assert
        Assert.areEqual(new List<Object>{ 'ACME1', 'ACME2' }, sequence);
    }

    @IsTest
    static void testGet_forTwoIncrementingStringInstances_theCounterIsPerInstance() {
        // Arrange
        XFTY_IncrementingStringExpression first = new XFTY_IncrementingStringExpression('P');
        XFTY_IncrementingStringExpression second = new XFTY_IncrementingStringExpression('P');
        first.get();
        first.get();

        // Act
        Test.startTest();
        Object secondsFirstValue = second.get();
        Test.stopTest();

        // Assert
        Assert.areEqual('P 1', secondsFirstValue, 'each instance counts independently');
    }

    // XFTY_UniqueStringExpression ------------------------------

    @IsTest
    static void testGet_forAUniqueString_neverRepeatsEvenAcrossInstances() {
        // Arrange
        Set<Object> produced = new Set<Object>();

        // Act
        Test.startTest();
        for (Integer i = 0; i < 25; i++) {
            produced.add(new XFTY_UniqueStringExpression('Prefix').get());
        }
        Test.stopTest();

        // Assert
        Assert.areEqual(25, produced.size(), 'the static counter keeps values distinct within a transaction');
    }

    @IsTest
    static void testGet_forAUniqueString_startsWithTheSuppliedPrefix() {
        // Arrange
        // nothing to arrange

        // Act
        Test.startTest();
        String value = (String) new XFTY_UniqueStringExpression('Widget').get();
        Test.stopTest();

        // Assert
        Assert.isTrue(value.startsWith('Widget '), value);
    }

    // XFTY_UniqueEmailExpression -----------------------------

    @IsTest
    static void testGet_forAUniqueEmail_producesWellFormedUniqueAddresses() {
        // Arrange
        Set<Object> produced = new Set<Object>();

        // Act
        Test.startTest();
        for (Integer i = 0; i < 25; i++) {
            produced.add(new XFTY_UniqueEmailExpression('test.user').get());
        }
        Test.stopTest();

        // Assert
        Assert.areEqual(25, produced.size(), 'each address is unique');
        for (Object email : produced) {
            Assert.isTrue(((String) email).startsWith('test.user'), (String) email);
            Assert.isTrue(((String) email).endsWith('@example.com'), (String) email);
        }
    }

    // XFTY_UniqueStringOfLengthExpression --------------------

    @IsTest
    static void testGet_forAUniqueStringOfLength_producesFixedLengthUppercaseUniqueValues() {
        // Arrange
        XFTY_UniqueStringOfLengthExpression expression = new XFTY_UniqueStringOfLengthExpression(5);
        Set<Object> produced = new Set<Object>();

        // Act
        Test.startTest();
        for (Integer i = 0; i < 20; i++) {
            produced.add(expression.get());
        }
        Test.stopTest();

        // Assert
        Assert.areEqual(20, produced.size());
        for (Object value : produced) {
            Assert.areEqual(5, ((String) value).length(), (String) value);
            Assert.isTrue(Pattern.matches('[A-Z]{5}', (String) value), (String) value);
        }
    }

    @IsTest
    static void testGet_forUniqueStringsOfDifferentLengths_countsSeparatelyPerLength() {
        // Arrange
        XFTY_UniqueStringOfLengthExpression threeCharExpression = new XFTY_UniqueStringOfLengthExpression(3);
        XFTY_UniqueStringOfLengthExpression fourCharExpression = new XFTY_UniqueStringOfLengthExpression(4);

        // Act
        Test.startTest();
        List<Object> firstOfEachLength = new List<Object>{ threeCharExpression.get(), fourCharExpression.get() };
        Test.stopTest();

        // Assert - both counters started at 0, so both are the first string for their length
        Assert.areEqual(new List<Object>{ 'AAA', 'AAAA' }, firstOfEachLength);
    }

    // XFTY_IncrementingDecimalExpression --------------------

    @IsTest
    static void testGet_forAnIncrementingDecimal_returnsAscendingDecimals() {
        // Arrange
        XFTY_IncrementingDecimalExpression expression = new XFTY_IncrementingDecimalExpression();

        // Act
        Test.startTest();
        List<Object> twoCalls = new List<Object>{ expression.get(), expression.get() };
        Test.stopTest();

        // Assert
        Assert.isTrue(twoCalls[0] instanceof Decimal, 'produces a Decimal');
        Assert.areEqual(Decimal.valueOf('1'), (Decimal) twoCalls[0]);
        Assert.areEqual(Decimal.valueOf('2'), (Decimal) twoCalls[1]);
    }

    // XFTY_UniqueAcrossRunsExpression ------------------------

    @IsTest
    static void testGet_forAUniqueAcrossRunsValue_wrapsACounterInAPrefixAndSuffix() {
        // Arrange
        XFTY_UniqueAcrossRunsExpression expression = new XFTY_UniqueAcrossRunsExpression('u.', '@example.com');

        // Act
        Test.startTest();
        List<Object> two = new List<Object>{ expression.get(), expression.get() };
        Test.stopTest();

        // Assert
        Assert.isTrue(((String) two[0]).startsWith('u.'), (String) two[0]);
        Assert.isTrue(((String) two[0]).endsWith('@example.com'), (String) two[0]);
        Assert.areNotEqual(two[0], two[1], 'the counter still moves within a transaction');
    }

    @IsTest
    static void testGet_forAUniqueAcrossRunsValue_carriesAPerTransactionToken() {
        // Arrange - the token is what makes two persisted runs not collide
        XFTY_UniqueAcrossRunsExpression expression = new XFTY_UniqueAcrossRunsExpression('User Federation Id ', '');

        // Act
        Test.startTest();
        String value = (String) expression.get();
        Test.stopTest();

        // Assert - prefix, then digits from the token + counter (no 'User Federation Id 1' literal)
        Assert.isTrue(value.startsWith('User Federation Id '), value);
        Assert.isTrue(value.length() > 'User Federation Id 1'.length(), value);
    }

    // Runner -----------------------------------------------

    static void assertLiteralReturnsItself(Object value) {
        // Arrange
        XFTY_LiteralExpression expression = new XFTY_LiteralExpression(value);

        // Act
        Test.startTest();
        Object result = expression.get();
        Test.stopTest();

        // Assert
        Assert.areEqual(value, result);
    }
}

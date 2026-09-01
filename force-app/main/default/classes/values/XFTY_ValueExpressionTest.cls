/**
 * Coverage for the small `XFTY_ValueExpressionIntf` expression implementations.
 *
 * These generators are pure value producers, so the tests need neither DML nor
 * `System.runAs`. They double as executable documentation of what each expression
 * guarantees (format, uniqueness scope, statefulness).
 */
@IsTest
private class XFTY_ValueExpressionTest {

    // XFTY_LiteralExpression -------------------------------------------------

    @IsTest
    static void exactReturnsTheSuppliedValueUnchanged() {
        Assert.areEqual('Customer', new XFTY_LiteralExpression('Customer').get());
        Assert.areEqual(42, new XFTY_LiteralExpression(42).get());
    }

    @IsTest
    static void exactSupportsNull() {
        Assert.isNull(new XFTY_LiteralExpression(null).get());
    }

    @IsTest
    static void exactReturnsTheSameValueEveryCall() {
        XFTY_LiteralExpression expression = new XFTY_LiteralExpression('constant');
        Assert.areEqual('constant', expression.get());
        Assert.areEqual('constant', expression.get());
    }

    // XFTY_IncrementingStringExpression ----------------------------------

    @IsTest
    static void incrementingStringSeparatesPrefixAndCounterByDefault() {
        XFTY_IncrementingStringExpression expression =
                new XFTY_IncrementingStringExpression('Account');
        Assert.areEqual('Account 1', expression.get());
        Assert.areEqual('Account 2', expression.get());
        Assert.areEqual('Account 3', expression.get());
    }

    @IsTest
    static void incrementingStringCanOmitTheSeparator() {
        XFTY_IncrementingStringExpression expression = new XFTY_IncrementingStringExpression(
                'ACME',
                XFTY_IncrementingStringExpression.DONT_SEPARATE_PREFIX
        );
        Assert.areEqual('ACME1', expression.get());
        Assert.areEqual('ACME2', expression.get());
    }

    @IsTest
    static void incrementingStringCounterIsPerInstance() {
        XFTY_IncrementingStringExpression first = new XFTY_IncrementingStringExpression('P');
        XFTY_IncrementingStringExpression second = new XFTY_IncrementingStringExpression('P');
        first.get();
        first.get();
        Assert.areEqual('P 1', second.get(), 'Each instance should count independently');
    }

    // XFTY_UniqueStringExpression ---------------------------------------

    @IsTest
    static void uniqueStringNeverRepeatsEvenAcrossInstances() {
        Set<Object> produced = new Set<Object>();
        for (Integer i = 0; i < 25; i++) {
            produced.add(new XFTY_UniqueStringExpression('Prefix').get());
        }
        Assert.areEqual(25, produced.size(), 'The counter is static, so values must be globally unique');
    }

    @IsTest
    static void uniqueStringStartsWithTheSuppliedPrefix() {
        String value = (String) new XFTY_UniqueStringExpression('Widget').get();
        Assert.isTrue(value.startsWith('Widget '), 'Got: ' + value);
    }

    // XFTY_UniqueEmailExpression --------------------------------------

    @IsTest
    static void uniqueEmailProducesWellFormedUniqueAddresses() {
        Set<Object> produced = new Set<Object>();
        for (Integer i = 0; i < 25; i++) {
            String email = (String) new XFTY_UniqueEmailExpression('test.user').get();
            Assert.isTrue(email.startsWith('test.user'), 'Got: ' + email);
            Assert.isTrue(email.endsWith('@example.com'), 'Got: ' + email);
            produced.add(email);
        }
        Assert.areEqual(25, produced.size());
    }

    // XFTY_UniqueStringOfLengthExpression ------------------------------

    @IsTest
    static void uniqueStringLengthProducesFixedLengthUppercaseValues() {
        XFTY_UniqueStringOfLengthExpression expression = new XFTY_UniqueStringOfLengthExpression(5);
        Set<Object> produced = new Set<Object>();
        for (Integer i = 0; i < 20; i++) {
            String value = (String) expression.get();
            Assert.areEqual(5, value.length(), 'Got: ' + value);
            Assert.isTrue(Pattern.matches('[A-Z]{5}', value), 'Got: ' + value);
            produced.add(value);
        }
        Assert.areEqual(20, produced.size());
    }

    @IsTest
    static void uniqueStringLengthCountsSeparatelyPerLength() {
        String threeChars = (String) new XFTY_UniqueStringOfLengthExpression(3).get();
        String fourChars = (String) new XFTY_UniqueStringOfLengthExpression(4).get();
        Assert.areEqual(3, threeChars.length());
        Assert.areEqual(4, fourChars.length());
        // Both counters started at 0, so both should be the first string for their length.
        Assert.areEqual('AAA', threeChars);
        Assert.areEqual('AAAA', fourChars);
    }

    // XFTY_IncrementingDecimalExpression ---------------------------------

    @IsTest
    static void incrementingDecimalReturnsAscendingDecimals() {
        XFTY_IncrementingDecimalExpression expression = new XFTY_IncrementingDecimalExpression();
        Object first = expression.get();
        Assert.isTrue(first instanceof Decimal, 'Expected a Decimal');
        Assert.areEqual(Decimal.valueOf('1'), (Decimal) first);
        Assert.areEqual(Decimal.valueOf('2'), (Decimal) expression.get());
    }
}

/**
 * Coverage for the small `XFTY_DummyDefaultValueIntf` strategy implementations.
 *
 * These generators are pure value producers, so the tests need neither DML nor
 * `System.runAs`. They double as executable documentation of what each strategy
 * guarantees (format, uniqueness scope, statefulness).
 */
@IsTest
private class XFTY_DefaultValueStrategyTest {

    // XFTY_DummyDefaultValueExact -------------------------------------------------

    @IsTest
    static void exactReturnsTheSuppliedValueUnchanged() {
        Assert.areEqual('Customer', new XFTY_DummyDefaultValueExact('Customer').get());
        Assert.areEqual(42, new XFTY_DummyDefaultValueExact(42).get());
    }

    @IsTest
    static void exactSupportsNull() {
        Assert.isNull(new XFTY_DummyDefaultValueExact(null).get());
    }

    @IsTest
    static void exactReturnsTheSameValueEveryCall() {
        XFTY_DummyDefaultValueExact strategy = new XFTY_DummyDefaultValueExact('constant');
        Assert.areEqual('constant', strategy.get());
        Assert.areEqual('constant', strategy.get());
    }

    // XFTY_DummyDefaultValueIncrementingString ----------------------------------

    @IsTest
    static void incrementingStringSeparatesPrefixAndCounterByDefault() {
        XFTY_DummyDefaultValueIncrementingString strategy =
                new XFTY_DummyDefaultValueIncrementingString('Account');
        Assert.areEqual('Account 1', strategy.get());
        Assert.areEqual('Account 2', strategy.get());
        Assert.areEqual('Account 3', strategy.get());
    }

    @IsTest
    static void incrementingStringCanOmitTheSeparator() {
        XFTY_DummyDefaultValueIncrementingString strategy = new XFTY_DummyDefaultValueIncrementingString(
                'ACME',
                XFTY_DummyDefaultValueIncrementingString.DONT_SEPARATE_PREFIX
        );
        Assert.areEqual('ACME1', strategy.get());
        Assert.areEqual('ACME2', strategy.get());
    }

    @IsTest
    static void incrementingStringCounterIsPerInstance() {
        XFTY_DummyDefaultValueIncrementingString first = new XFTY_DummyDefaultValueIncrementingString('P');
        XFTY_DummyDefaultValueIncrementingString second = new XFTY_DummyDefaultValueIncrementingString('P');
        first.get();
        first.get();
        Assert.areEqual('P 1', second.get(), 'Each instance should count independently');
    }

    // XFTY_DummyDefaultValueUniqueString ---------------------------------------

    @IsTest
    static void uniqueStringNeverRepeatsEvenAcrossInstances() {
        Set<Object> produced = new Set<Object>();
        for (Integer i = 0; i < 25; i++) {
            produced.add(new XFTY_DummyDefaultValueUniqueString('Prefix').get());
        }
        Assert.areEqual(25, produced.size(), 'The counter is static, so values must be globally unique');
    }

    @IsTest
    static void uniqueStringStartsWithTheSuppliedPrefix() {
        String value = (String) new XFTY_DummyDefaultValueUniqueString('Widget').get();
        Assert.isTrue(value.startsWith('Widget '), 'Got: ' + value);
    }

    // XFTY_DummyDefaultValueUniqueEmail --------------------------------------

    @IsTest
    static void uniqueEmailProducesWellFormedUniqueAddresses() {
        Set<Object> produced = new Set<Object>();
        for (Integer i = 0; i < 25; i++) {
            String email = (String) new XFTY_DummyDefaultValueUniqueEmail('test.user').get();
            Assert.isTrue(email.startsWith('test.user'), 'Got: ' + email);
            Assert.isTrue(email.endsWith('@example.com'), 'Got: ' + email);
            produced.add(email);
        }
        Assert.areEqual(25, produced.size());
    }

    // XFTY_DummyDefaultValueUniqueStringLength ------------------------------

    @IsTest
    static void uniqueStringLengthProducesFixedLengthUppercaseValues() {
        XFTY_DummyDefaultValueUniqueStringLength strategy = new XFTY_DummyDefaultValueUniqueStringLength(5);
        Set<Object> produced = new Set<Object>();
        for (Integer i = 0; i < 20; i++) {
            String value = (String) strategy.get();
            Assert.areEqual(5, value.length(), 'Got: ' + value);
            Assert.isTrue(Pattern.matches('[A-Z]{5}', value), 'Got: ' + value);
            produced.add(value);
        }
        Assert.areEqual(20, produced.size());
    }

    @IsTest
    static void uniqueStringLengthCountsSeparatelyPerLength() {
        String threeChars = (String) new XFTY_DummyDefaultValueUniqueStringLength(3).get();
        String fourChars = (String) new XFTY_DummyDefaultValueUniqueStringLength(4).get();
        Assert.areEqual(3, threeChars.length());
        Assert.areEqual(4, fourChars.length());
        // Both counters started at 0, so both should be the first string for their length.
        Assert.areEqual('AAA', threeChars);
        Assert.areEqual('AAAA', fourChars);
    }

    // XFTY_DummyDefaultIncrementingDecimal ---------------------------------

    @IsTest
    static void incrementingDecimalReturnsAscendingDecimals() {
        XFTY_DummyDefaultIncrementingDecimal strategy = new XFTY_DummyDefaultIncrementingDecimal();
        Object first = strategy.get();
        Assert.isTrue(first instanceof Decimal, 'Expected a Decimal');
        Assert.areEqual(Decimal.valueOf('1'), (Decimal) first);
        Assert.areEqual(Decimal.valueOf('2'), (Decimal) strategy.get());
    }
}

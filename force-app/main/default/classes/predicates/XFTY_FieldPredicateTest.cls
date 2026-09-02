/**
 * Proves the {@link XFTY_FieldPredicate} facade wires each factory to the right
 * single-field predicate. The predicates' own edge cases are proved in their
 * dedicated test classes; here one representative outcome per factory is enough.
 * `notEqualTo` / `isNotNull` are a negated `equalTo`, so both directions are
 * checked.
 */
@IsTest
private class XFTY_FieldPredicateTest {

    @IsTest
    static void testEqualTo_whenTheFieldMatches_returnsTrue() {
        testIsSatisfiedBy(XFTY_FieldPredicate.equalTo(Account.Industry, 'Technology'),
                new Account(Industry = 'Technology'), true);
    }

    @IsTest
    static void testNotEqualTo_whenTheFieldDiffers_returnsTrue() {
        testIsSatisfiedBy(XFTY_FieldPredicate.notEqualTo(Account.Industry, 'Retail'),
                new Account(Industry = 'Technology'), true);
    }

    @IsTest
    static void testNotEqualTo_whenTheFieldMatches_returnsFalse() {
        testIsSatisfiedBy(XFTY_FieldPredicate.notEqualTo(Account.Industry, 'Retail'),
                new Account(Industry = 'Retail'), false);
    }

    @IsTest
    static void testGreaterThan_whenTheFieldExceedsTheValue_returnsTrue() {
        testIsSatisfiedBy(XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 100),
                new Account(NumberOfEmployees = 900), true);
    }

    @IsTest
    static void testLessThan_whenTheFieldIsBelowTheValue_returnsTrue() {
        testIsSatisfiedBy(XFTY_FieldPredicate.lessThan(Account.NumberOfEmployees, 100),
                new Account(NumberOfEmployees = 5), true);
    }

    @IsTest
    static void testIsNull_whenTheFieldIsBlank_returnsTrue() {
        testIsSatisfiedBy(XFTY_FieldPredicate.isNull(Account.Industry), new Account(), true);
    }

    @IsTest
    static void testIsNotNull_whenTheFieldIsSet_returnsTrue() {
        testIsSatisfiedBy(XFTY_FieldPredicate.isNotNull(Account.Industry),
                new Account(Industry = 'Technology'), true);
    }

    @IsTest
    static void testIsNotNull_whenTheFieldIsBlank_returnsFalse() {
        testIsSatisfiedBy(XFTY_FieldPredicate.isNotNull(Account.Industry), new Account(), false);
    }

    @IsTest
    static void testInSet_whenTheFieldIsAMember_returnsTrue() {
        testIsSatisfiedBy(XFTY_FieldPredicate.inSet(Account.Industry, new Set<Object>{ 'Technology' }),
                new Account(Industry = 'Technology'), true);
    }

    static void testIsSatisfiedBy(XFTY_SObjectPredicateIntf predicate, SObject record, Boolean expectedResult) {
        // Arrange - the caller supplies the facade-built predicate and the record

        // Act
        Test.startTest();
        Boolean actualResult = predicate.isSatisfiedBy(record);
        Test.stopTest();

        // Assert
        Assert.areEqual(expectedResult, actualResult);
    }
}

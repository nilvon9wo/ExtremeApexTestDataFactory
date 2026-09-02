/**
 * Proves {@link XFTY_FieldGreaterThanPredicate} - `isSatisfiedBy` is true
 * exactly when the field orders strictly after the configured value, and false
 * whenever the two cannot be compared. The ordering itself is
 * {@link XFTY_ValueComparison}'s job and is proved in `XFTY_ValueComparisonTest`.
 */
@IsTest
private class XFTY_FieldGreaterThanPredicateTest {

    @IsTest
    static void testIsSatisfiedBy_whenTheFieldExceedsTheValue_returnsTrue() {
        testIsSatisfiedBy(100, new Account(NumberOfEmployees = 900), true);
    }

    @IsTest
    static void testIsSatisfiedBy_whenTheFieldEqualsTheValue_returnsFalse() {
        testIsSatisfiedBy(900, new Account(NumberOfEmployees = 900), false);
    }

    @IsTest
    static void testIsSatisfiedBy_whenTheFieldIsBelowTheValue_returnsFalse() {
        testIsSatisfiedBy(900, new Account(NumberOfEmployees = 5), false);
    }

    @IsTest
    static void testIsSatisfiedBy_whenTheFieldValueIsNull_returnsFalse() {
        testIsSatisfiedBy(1, new Account(), false);
    }

    @IsTest
    static void testIsSatisfiedBy_whenTheComparisonValueIsNull_returnsFalse() {
        testIsSatisfiedBy(null, new Account(NumberOfEmployees = 5), false);
    }

    @IsTest
    static void testIsSatisfiedBy_whenTheRecordIsNull_returnsFalse() {
        testIsSatisfiedBy(1, null, false);
    }

    static void testIsSatisfiedBy(Object threshold, SObject record, Boolean expectedResult) {
        // Arrange
        XFTY_SObjectPredicateIntf predicate = XFTY_FieldGreaterThanPredicate.of(Account.NumberOfEmployees, threshold);

        // Act
        Test.startTest();
        Boolean actualResult = predicate.isSatisfiedBy(record);
        Test.stopTest();

        // Assert
        Assert.areEqual(expectedResult, actualResult);
    }
}

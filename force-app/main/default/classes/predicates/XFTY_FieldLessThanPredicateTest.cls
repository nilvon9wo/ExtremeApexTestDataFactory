/**
 * Proves {@link XFTY_FieldLessThanPredicate} - `isSatisfiedBy` is true exactly
 * when the field orders strictly before the configured value, and false
 * whenever the two cannot be compared. The ordering itself is proved in
 * `XFTY_ValueComparisonTest`.
 */
@IsTest
private class XFTY_FieldLessThanPredicateTest {

    @IsTest
    static void testIsSatisfiedBy_whenTheFieldIsBelowTheValue_returnsTrue() {
        testIsSatisfiedBy(100, 5, true);
    }

    @IsTest
    static void testIsSatisfiedBy_whenTheFieldEqualsTheValue_returnsFalse() {
        testIsSatisfiedBy(100, 100, false);
    }

    @IsTest
    static void testIsSatisfiedBy_whenTheFieldExceedsTheValue_returnsFalse() {
        testIsSatisfiedBy(100, 900, false);
    }

    @IsTest
    static void testIsSatisfiedBy_whenTheFieldValueIsNull_returnsFalse() {
        testIsSatisfiedBy(1, null, false);
    }

    @IsTest
    static void testIsSatisfiedBy_whenTheRecordIsNull_returnsFalse() {
        // Arrange
        XFTY_SObjectPredicateIntf predicate = XFTY_FieldLessThanPredicate.of(Account.NumberOfEmployees, 1);

        // Act
        Boolean actualResult = predicate.isSatisfiedBy(null);

        // Assert
        Assert.isFalse(actualResult);
    }

    static void testIsSatisfiedBy(Object threshold, Integer fieldValue, Boolean expectedResult) {
        // Arrange
        XFTY_SObjectPredicateIntf predicate = XFTY_FieldLessThanPredicate.of(Account.NumberOfEmployees, threshold);

        // Act
        Boolean actualResult = predicate.isSatisfiedBy(new Account(NumberOfEmployees = fieldValue));

        // Assert
        Assert.areEqual(expectedResult, actualResult);
    }
}

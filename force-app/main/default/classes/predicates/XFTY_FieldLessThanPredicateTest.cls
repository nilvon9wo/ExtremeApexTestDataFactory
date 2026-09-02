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
        testIsSatisfiedBy(100, new Account(NumberOfEmployees = 5), true);
    }

    @IsTest
    static void testIsSatisfiedBy_whenTheFieldEqualsTheValue_returnsFalse() {
        testIsSatisfiedBy(100, new Account(NumberOfEmployees = 100), false);
    }

    @IsTest
    static void testIsSatisfiedBy_whenTheFieldExceedsTheValue_returnsFalse() {
        testIsSatisfiedBy(100, new Account(NumberOfEmployees = 900), false);
    }

    @IsTest
    static void testIsSatisfiedBy_whenTheFieldValueIsNull_returnsFalse() {
        testIsSatisfiedBy(1, new Account(), false);
    }

    @IsTest
    static void testIsSatisfiedBy_whenTheRecordIsNull_returnsFalse() {
        testIsSatisfiedBy(1, null, false);
    }

    static void testIsSatisfiedBy(Object threshold, SObject record, Boolean expectedResult) {
        // Arrange
        XFTY_SObjectPredicateIntf predicate = XFTY_FieldLessThanPredicate.of(Account.NumberOfEmployees, threshold);

        // Act
        Test.startTest();
        Boolean actualResult = predicate.isSatisfiedBy(record);
        Test.stopTest();

        // Assert
        Assert.areEqual(expectedResult, actualResult);
    }
}

/**
 * Proves {@link XFTY_FieldInSetPredicate} - `isSatisfiedBy` is true exactly when
 * the record's field is one of the configured set; a null set accepts nothing.
 */
@IsTest
private class XFTY_FieldInSetPredicateTest {

    private static final Set<Object> FINANCE_OR_TECH = new Set<Object>{ 'Finance', 'Technology' };

    @IsTest
    static void testIsSatisfiedBy_whenTheFieldIsAMemberOfTheSet_returnsTrue() {
        testIsSatisfiedBy(FINANCE_OR_TECH, new Account(Industry = 'Technology'), true);
    }

    @IsTest
    static void testIsSatisfiedBy_whenTheFieldIsNotAMemberOfTheSet_returnsFalse() {
        testIsSatisfiedBy(FINANCE_OR_TECH, new Account(Industry = 'Retail'), false);
    }

    @IsTest
    static void testIsSatisfiedBy_whenTheSetIsNull_returnsFalse() {
        testIsSatisfiedBy(null, new Account(Industry = 'Technology'), false);
    }

    @IsTest
    static void testIsSatisfiedBy_whenTheRecordIsNull_returnsFalse() {
        testIsSatisfiedBy(FINANCE_OR_TECH, null, false);
    }

    static void testIsSatisfiedBy(Set<Object> acceptedValues, SObject record, Boolean expectedResult) {
        // Arrange
        XFTY_SObjectPredicateIntf predicate = XFTY_FieldInSetPredicate.of(Account.Industry, acceptedValues);

        // Act
        Test.startTest();
        Boolean actualResult = predicate.isSatisfiedBy(record);
        Test.stopTest();

        // Assert
        Assert.areEqual(expectedResult, actualResult);
    }
}

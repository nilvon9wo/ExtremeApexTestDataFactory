/**
 * Proves {@link XFTY_FieldEqualToPredicate} - `isSatisfiedBy` is true exactly
 * when the record's field equals the configured value, `null` included.
 */
@IsTest
private class XFTY_FieldEqualToPredicateTest {

    @IsTest
    static void testIsSatisfiedBy_whenFieldEqualsValue_returnsTrue() {
        testIsSatisfiedBy('Technology', new Account(Industry = 'Technology'), true);
    }

    @IsTest
    static void testIsSatisfiedBy_whenFieldDiffersFromValue_returnsFalse() {
        testIsSatisfiedBy('Technology', new Account(Industry = 'Retail'), false);
    }

    @IsTest
    static void testIsSatisfiedBy_whenConfiguredWithNullAndFieldIsBlank_returnsTrue() {
        testIsSatisfiedBy(null, new Account(), true);
    }

    @IsTest
    static void testIsSatisfiedBy_whenConfiguredWithNullAndFieldIsSet_returnsFalse() {
        testIsSatisfiedBy(null, new Account(Industry = 'Technology'), false);
    }

    @IsTest
    static void testIsSatisfiedBy_whenRecordIsNull_returnsFalse() {
        testIsSatisfiedBy('Technology', null, false);
    }

    static void testIsSatisfiedBy(Object configuredValue, SObject record, Boolean expectedResult) {
        // Arrange
        XFTY_SObjectPredicateIntf predicate = XFTY_FieldEqualToPredicate.of(Account.Industry, configuredValue);

        // Act
        Test.startTest();
        Boolean actualResult = predicate.isSatisfiedBy(record);
        Test.stopTest();

        // Assert
        Assert.areEqual(expectedResult, actualResult);
    }
}

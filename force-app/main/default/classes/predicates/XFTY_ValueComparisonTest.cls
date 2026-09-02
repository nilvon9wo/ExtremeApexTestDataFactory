/**
 * Proves {@link XFTY_ValueComparison}: `compare` returns the sign of the natural
 * ordering (numbers numerically, `Date` / `Datetime` chronologically, otherwise
 * lexicographically), and `fieldToValue` returns `null` for any pairing that
 * cannot be ordered.
 */
@IsTest
private class XFTY_ValueComparisonTest {

    private static final Datetime NOON = Datetime.newInstanceGmt(2024, 1, 1, 12, 0, 0);
    private static final Date MILLENNIUM = Date.newInstance(2000, 1, 1);

    // compare(left, right) -----------------------------------------------

    @IsTest
    static void testCompare_whenTheLeftNumberIsGreater_returnsPositive() {
        testCompare(900, 100, 1);
    }

    @IsTest
    static void testCompare_whenTheNumbersAreEqual_returnsZero() {
        testCompare(100, 100, 0);
    }

    @IsTest
    static void testCompare_whenTheLeftNumberIsSmaller_returnsNegative() {
        testCompare(5, 100, -1);
    }

    @IsTest
    static void testCompare_whenGivenDecimals_ordersThemNumerically() {
        testCompare(1000000.50, 1000000.25, 1);
    }

    @IsTest
    static void testCompare_whenTheLeftDateIsLater_returnsPositive() {
        testCompare(Date.newInstance(2020, 1, 1), MILLENNIUM, 1);
    }

    @IsTest
    static void testCompare_whenTheLeftDateIsEarlier_returnsNegative() {
        testCompare(Date.newInstance(1980, 1, 1), MILLENNIUM, -1);
    }

    @IsTest
    static void testCompare_whenTheLeftDatetimeIsLater_returnsPositive() {
        testCompare(NOON.addHours(1), NOON, 1);
    }

    @IsTest
    static void testCompare_whenGivenStrings_ordersThemLexicographically() {
        testCompare('Acme', 'Aardvark', 1);
    }

    // fieldToValue(record, field, value) --------------------------------

    @IsTest
    static void testFieldToValue_whenTheFieldIsAbsent_returnsNull() {
        testFieldToValue(new Account(), 100, null);
    }

    @IsTest
    static void testFieldToValue_whenTheComparisonValueIsNull_returnsNull() {
        testFieldToValue(new Account(NumberOfEmployees = 5), null, null);
    }

    @IsTest
    static void testFieldToValue_whenTheRecordIsNull_returnsNull() {
        testFieldToValue(null, 100, null);
    }

    @IsTest
    static void testFieldToValue_whenBothSidesArePresent_returnsTheirOrdering() {
        testFieldToValue(new Account(NumberOfEmployees = 900), 100, 1);
    }

    // Helpers ---------------------------------------------------------

    static void testCompare(Object left, Object right, Integer expectedSign) {
        // Arrange - the caller supplies the pair to order

        // Act
        Test.startTest();
        Integer actualSign = XFTY_ValueComparison.compare(left, right);
        Test.stopTest();

        // Assert
        Assert.areEqual(expectedSign, actualSign);
    }

    static void testFieldToValue(SObject record, Object comparisonValue, Integer expectedResult) {
        // Arrange - the caller supplies the record and comparison value

        // Act
        Test.startTest();
        Integer actualResult = XFTY_ValueComparison.fieldToValue(record, Account.NumberOfEmployees, comparisonValue);
        Test.stopTest();

        // Assert
        Assert.areEqual(expectedResult, actualResult);
    }
}

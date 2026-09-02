/**
 * Proves {@link XFTY_NegationPredicate} - `isSatisfiedBy` returns the opposite
 * of the wrapped predicate, and `of` rejects a null predicate.
 */
@IsTest
private class XFTY_NegationPredicateTest {

    @IsTest
    static void testIsSatisfiedBy_whenTheInnerPredicateIsSatisfied_returnsFalse() {
        testIsSatisfiedBy(new Account(Type = 'Prospect'), false);
    }

    @IsTest
    static void testIsSatisfiedBy_whenTheInnerPredicateIsNotSatisfied_returnsTrue() {
        testIsSatisfiedBy(new Account(Type = 'Customer'), true);
    }

    @IsTest
    static void testOf_whenThePredicateIsNull_throws() {
        // Arrange
        // nothing to arrange

        // Act
        try {
            XFTY_NegationPredicate.of(null);
            Assert.fail('Expected an exception');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            // Assert
            Assert.isTrue(ex.getMessage().contains('predicate to negate is required'), ex.getMessage());
        }
    }

    static void testIsSatisfiedBy(SObject record, Boolean expectedResult) {
        // Arrange - negate "Type is Prospect"
        XFTY_SObjectPredicateIntf predicate =
                XFTY_NegationPredicate.of(XFTY_FieldPredicate.equalTo(Account.Type, 'Prospect'));

        // Act
        Boolean actualResult = predicate.isSatisfiedBy(record);

        // Assert
        Assert.areEqual(expectedResult, actualResult);
    }
}

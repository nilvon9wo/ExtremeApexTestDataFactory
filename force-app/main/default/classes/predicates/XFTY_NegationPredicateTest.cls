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
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            XFTY_NegationPredicate.of(null);
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown, 'a null inner predicate must be rejected');
        Assert.isTrue(thrown.getMessage().contains('predicate to negate is required'), thrown.getMessage());
    }

    static void testIsSatisfiedBy(SObject record, Boolean expectedResult) {
        // Arrange - negate "Type is Prospect"
        XFTY_SObjectPredicateIntf predicate =
                XFTY_NegationPredicate.of(XFTY_FieldPredicate.equalTo(Account.Type, 'Prospect'));

        // Act
        Test.startTest();
        Boolean actualResult = predicate.isSatisfiedBy(record);
        Test.stopTest();

        // Assert
        Assert.areEqual(expectedResult, actualResult);
    }
}

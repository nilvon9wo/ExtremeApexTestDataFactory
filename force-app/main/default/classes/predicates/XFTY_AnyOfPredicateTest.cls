/**
 * Proves {@link XFTY_AnyOfPredicate} - `isSatisfiedBy` is true when at least one
 * member predicate is (an empty member list is never satisfied), and `of`
 * rejects a null list.
 */
@IsTest
private class XFTY_AnyOfPredicateTest {

    @IsTest
    static void testIsSatisfiedBy_whenOneMemberIsSatisfied_returnsTrue() {
        testIsSatisfiedBy(
                new List<XFTY_SObjectPredicateIntf>{
                        XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 5000),
                        XFTY_FieldPredicate.equalTo(Account.Industry, 'Technology')
                },
                new Account(NumberOfEmployees = 10, Industry = 'Technology'), true);
    }

    @IsTest
    static void testIsSatisfiedBy_whenNoMemberIsSatisfied_returnsFalse() {
        testIsSatisfiedBy(
                new List<XFTY_SObjectPredicateIntf>{
                        XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 5000),
                        XFTY_FieldPredicate.equalTo(Account.Industry, 'Technology')
                },
                new Account(NumberOfEmployees = 10, Industry = 'Retail'), false);
    }

    @IsTest
    static void testIsSatisfiedBy_whenTheMemberListIsEmpty_returnsFalse() {
        testIsSatisfiedBy(new List<XFTY_SObjectPredicateIntf>(), new Account(), false);
    }

    @IsTest
    static void testOf_whenTheMemberListIsNull_throws() {
        // Arrange
        // nothing to arrange

        // Act
        try {
            XFTY_AnyOfPredicate.of(null);
            Assert.fail('Expected an exception');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            // Assert
            Assert.isTrue(ex.getMessage().contains('predicate list is required'), ex.getMessage());
        }
    }

    static void testIsSatisfiedBy(List<XFTY_SObjectPredicateIntf> members, SObject record, Boolean expectedResult) {
        // Arrange
        XFTY_SObjectPredicateIntf predicate = XFTY_AnyOfPredicate.of(members);

        // Act
        Boolean actualResult = predicate.isSatisfiedBy(record);

        // Assert
        Assert.areEqual(expectedResult, actualResult);
    }
}

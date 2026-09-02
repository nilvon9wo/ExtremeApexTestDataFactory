/**
 * Proves {@link XFTY_AllOfPredicate} - `isSatisfiedBy` is true only when every
 * member predicate is (an empty member list is vacuously true), and `of`
 * rejects a null list.
 */
@IsTest
private class XFTY_AllOfPredicateTest {

    @IsTest
    static void testIsSatisfiedBy_whenEveryMemberIsSatisfied_returnsTrue() {
        testIsSatisfiedBy(bigTechPredicates(), new Account(NumberOfEmployees = 900, Industry = 'Technology'), true);
    }

    @IsTest
    static void testIsSatisfiedBy_whenOneMemberIsNotSatisfied_returnsFalse() {
        testIsSatisfiedBy(bigTechPredicates(), new Account(NumberOfEmployees = 900, Industry = 'Retail'), false);
    }

    @IsTest
    static void testIsSatisfiedBy_whenTheMemberListIsEmpty_returnsTrue() {
        testIsSatisfiedBy(new List<XFTY_SObjectPredicateIntf>(), new Account(), true);
    }

    @IsTest
    static void testOf_whenTheMemberListIsNull_throws() {
        // Arrange
        // nothing to arrange

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            XFTY_AllOfPredicate.of(null);
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown, 'a null member list must be rejected');
        Assert.isTrue(thrown.getMessage().contains('predicate list is required'), thrown.getMessage());
    }

    private static List<XFTY_SObjectPredicateIntf> bigTechPredicates() {
        return new List<XFTY_SObjectPredicateIntf>{
                XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 100),
                XFTY_FieldPredicate.equalTo(Account.Industry, 'Technology')
        };
    }

    static void testIsSatisfiedBy(List<XFTY_SObjectPredicateIntf> members, SObject record, Boolean expectedResult) {
        // Arrange
        XFTY_SObjectPredicateIntf predicate = XFTY_AllOfPredicate.of(members);

        // Act
        Test.startTest();
        Boolean actualResult = predicate.isSatisfiedBy(record);
        Test.stopTest();

        // Assert
        Assert.areEqual(expectedResult, actualResult);
    }
}

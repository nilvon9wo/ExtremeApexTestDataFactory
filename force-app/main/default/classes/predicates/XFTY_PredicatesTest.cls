/**
 * Proves the {@link XFTY_Predicates} combinator facade wires `allOf` / `anyOf` /
 * `not` to the right implementation, and that a combinator tree works as the
 * predicate of an `XFTY_FlavouredLookupKey` (the docs/extend/provider-variants.md
 * "strategic" example).
 */
@IsTest
private class XFTY_PredicatesTest {

    // Facade delegation ------------------------------------------------

    @IsTest
    static void testAllOf_whenAMemberIsNotSatisfied_returnsFalse() {
        assertResult(
                XFTY_Predicates.allOf(new List<XFTY_SObjectPredicateIntf>{
                        XFTY_FieldPredicate.equalTo(Account.Industry, 'Technology')
                }),
                new Account(Industry = 'Retail'), false);
    }

    @IsTest
    static void testAnyOf_whenAMemberIsSatisfied_returnsTrue() {
        assertResult(
                XFTY_Predicates.anyOf(new List<XFTY_SObjectPredicateIntf>{
                        XFTY_FieldPredicate.equalTo(Account.Industry, 'Technology')
                }),
                new Account(Industry = 'Technology'), true);
    }

    @IsTest
    static void testNot_whenTheInnerPredicateIsNotSatisfied_returnsTrue() {
        assertResult(XFTY_Predicates.not(XFTY_FieldPredicate.equalTo(Account.Type, 'Prospect')),
                new Account(Type = 'Customer'), true);
    }

    // Driving a flavoured lookup key ---------------------------------

    @IsTest
    static void testIsInstanceOf_whenACombinatorTreeMatchesTheRecord_returnsTrue() {
        // Arrange - the docs "strategic" key verbatim:
        // (big revenue OR big headcount) AND not a prospect
        XFTY_FlavouredLookupKey strategic = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'strategic')
                .matching(XFTY_Predicates.anyOf(new List<XFTY_SObjectPredicateIntf>{
                        XFTY_FieldPredicate.greaterThan(Account.AnnualRevenue, 1000000),
                        XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 5000)
                }))
                .matching(XFTY_Predicates.not(XFTY_FieldPredicate.equalTo(Account.Type, 'Prospect')));

        // Act
        Boolean actualResult = strategic.isInstanceOf(new Account(NumberOfEmployees = 6000, Type = 'Customer'));

        // Assert
        Assert.isTrue(actualResult);
    }

    @IsTest
    static void testIsInstanceOf_whenTheNotBranchRejectsTheRecord_returnsFalse() {
        assertStrategicFlavourMatches('strategic-not', new Account(NumberOfEmployees = 6000, Type = 'Prospect'), false);
    }

    @IsTest
    static void testIsInstanceOf_whenNoOrBranchMatchesTheRecord_returnsFalse() {
        assertStrategicFlavourMatches('strategic-neither', new Account(NumberOfEmployees = 10, AnnualRevenue = 5), false);
    }

    // Helpers -------------------------------------------------------

    static void assertResult(XFTY_SObjectPredicateIntf predicate, SObject record, Boolean expectedResult) {
        // Arrange - the caller supplies the facade-built predicate and the record

        // Act
        Boolean actualResult = predicate.isSatisfiedBy(record);

        // Assert
        Assert.areEqual(expectedResult, actualResult);
    }

    static void assertStrategicFlavourMatches(String flavour, Account record, Boolean expectedResult) {
        // Arrange - "strategic" = (big revenue OR big headcount) AND not a prospect
        XFTY_FlavouredLookupKey strategic = XFTY_FlavouredLookupKey.get(Account.SObjectType, flavour)
                .matching(XFTY_Predicates.anyOf(new List<XFTY_SObjectPredicateIntf>{
                        XFTY_FieldPredicate.greaterThan(Account.AnnualRevenue, 1000000),
                        XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 5000)
                }))
                .matching(XFTY_Predicates.not(XFTY_FieldPredicate.equalTo(Account.Type, 'Prospect')));

        // Act
        Boolean actualResult = strategic.isInstanceOf(record);

        // Assert
        Assert.areEqual(expectedResult, actualResult);
    }
}

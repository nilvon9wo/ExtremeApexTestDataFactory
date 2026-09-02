/**
 * Proves the {@link XFTY_Predicates} combinator facade wires `allOf` / `anyOf` /
 * `not` to the right implementation, and that a combinator tree works as the
 * predicate of an `XFTY_FlavouredLookupKey` (the docs/extend/provider-variants.md
 * "strategic" example).
 */
@IsTest
private class XFTY_PredicatesTest {

    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    // Facade delegation ------------------------------------------------

    @IsTest
    static void testAllOf_whenAMemberIsNotSatisfied_returnsFalse() {
        testIsSatisfiedBy(
                XFTY_Predicates.allOf(new List<XFTY_SObjectPredicateIntf>{
                        XFTY_FieldPredicate.equalTo(Account.Industry, 'Technology')
                }),
                new Account(Industry = 'Retail'), false);
    }

    @IsTest
    static void testAnyOf_whenAMemberIsSatisfied_returnsTrue() {
        testIsSatisfiedBy(
                XFTY_Predicates.anyOf(new List<XFTY_SObjectPredicateIntf>{
                        XFTY_FieldPredicate.equalTo(Account.Industry, 'Technology')
                }),
                new Account(Industry = 'Technology'), true);
    }

    @IsTest
    static void testNot_whenTheInnerPredicateIsNotSatisfied_returnsTrue() {
        testIsSatisfiedBy(XFTY_Predicates.not(XFTY_FieldPredicate.equalTo(Account.Type, 'Prospect')),
                new Account(Type = 'Customer'), true);
    }

    // Driving a flavoured lookup key ---------------------------------

    @IsTest
    static void testIsInstanceOf_whenACombinatorTreeMatchesTheRecord_returnsTrue() {
        testStrategicFlavour('strategic', new Account(NumberOfEmployees = 6000, Type = 'Customer'), true);
    }

    @IsTest
    static void testIsInstanceOf_whenTheNotBranchRejectsTheRecord_returnsFalse() {
        testStrategicFlavour('strategic-not', new Account(NumberOfEmployees = 6000, Type = 'Prospect'), false);
    }

    @IsTest
    static void testIsInstanceOf_whenNoOrBranchMatchesTheRecord_returnsFalse() {
        testStrategicFlavour('strategic-neither', new Account(NumberOfEmployees = 10, AnnualRevenue = 5), false);
    }

    // Helpers -------------------------------------------------------

    static void testIsSatisfiedBy(XFTY_SObjectPredicateIntf predicate, SObject record, Boolean expectedResult) {
        // Arrange - the caller supplies the facade-built predicate and the record

        // Act
        Boolean actualResult;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            actualResult = predicate.isSatisfiedBy(record);
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(expectedResult, actualResult);
    }

    static void testStrategicFlavour(String flavour, Account record, Boolean expectedResult) {
        // Arrange - the docs "strategic" key: (big revenue OR big headcount) AND not a prospect
        XFTY_FlavouredLookupKey strategic = XFTY_FlavouredLookupKey.get(Account.SObjectType, flavour)
                .matching(XFTY_Predicates.anyOf(new List<XFTY_SObjectPredicateIntf>{
                        XFTY_FieldPredicate.greaterThan(Account.AnnualRevenue, 1000000),
                        XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 5000)
                }))
                .matching(XFTY_Predicates.not(XFTY_FieldPredicate.equalTo(Account.Type, 'Prospect')));

        // Act
        Boolean actualResult;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            actualResult = strategic.isInstanceOf(record);
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(expectedResult, actualResult);
    }
}

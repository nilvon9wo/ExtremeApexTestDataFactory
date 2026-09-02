/**
 * Coverage for the predicate building blocks: the single-field predicates
 * ({@link XFTY_FieldEqualToPredicate}, {@link XFTY_FieldGreaterThanPredicate},
 * {@link XFTY_FieldLessThanPredicate}, {@link XFTY_FieldInSetPredicate}), the
 * {@link XFTY_ValueComparison} ordering they share, the {@link XFTY_FieldPredicate}
 * facade, and the {@link XFTY_Predicates} AND / OR / NOT combinators.
 *
 * Each `@IsTest` checks one behaviour and delegates its Arrange / Act / Assert
 * to a shared helper.
 */
@IsTest
private class XFTY_FieldPredicateTest {

    private static final Datetime NOON = Datetime.newInstanceGmt(2024, 1, 1, 12, 0, 0);
    private static final Date MILLENNIUM = Date.newInstance(2000, 1, 1);

    // XFTY_FieldEqualToPredicate ---------------------------------------------

    @IsTest
    static void equalToIsSatisfiedWhenTheFieldEqualsTheValue() {
        assertSatisfiedBy(XFTY_FieldEqualToPredicate.of(Account.Industry, 'Technology'),
                new Account(Industry = 'Technology'), true);
    }

    @IsTest
    static void equalToIsNotSatisfiedWhenTheFieldDiffers() {
        assertSatisfiedBy(XFTY_FieldEqualToPredicate.of(Account.Industry, 'Technology'),
                new Account(Industry = 'Retail'), false);
    }

    @IsTest
    static void equalToNullIsSatisfiedWhenTheFieldIsBlank() {
        assertSatisfiedBy(XFTY_FieldEqualToPredicate.of(Account.Industry, null),
                new Account(), true);
    }

    @IsTest
    static void equalToNullIsNotSatisfiedWhenTheFieldIsSet() {
        assertSatisfiedBy(XFTY_FieldEqualToPredicate.of(Account.Industry, null),
                new Account(Industry = 'Technology'), false);
    }

    @IsTest
    static void equalToIsNotSatisfiedByANullRecord() {
        assertSatisfiedBy(XFTY_FieldEqualToPredicate.of(Account.Industry, 'Technology'), null, false);
    }

    // XFTY_FieldGreaterThanPredicate ----------------------------------------

    @IsTest
    static void greaterThanIsSatisfiedWhenTheNumberExceedsTheThreshold() {
        assertSatisfiedBy(XFTY_FieldGreaterThanPredicate.of(Account.NumberOfEmployees, 100),
                new Account(NumberOfEmployees = 900), true);
    }

    @IsTest
    static void greaterThanIsNotSatisfiedWhenTheNumberEqualsTheThreshold() {
        assertSatisfiedBy(XFTY_FieldGreaterThanPredicate.of(Account.NumberOfEmployees, 900),
                new Account(NumberOfEmployees = 900), false);
    }

    @IsTest
    static void greaterThanIsNotSatisfiedWhenTheNumberIsBelowTheThreshold() {
        assertSatisfiedBy(XFTY_FieldGreaterThanPredicate.of(Account.NumberOfEmployees, 900),
                new Account(NumberOfEmployees = 5), false);
    }

    @IsTest
    static void greaterThanIsSatisfiedWhenTheDateIsAfterTheThreshold() {
        assertSatisfiedBy(XFTY_FieldGreaterThanPredicate.of(Contact.Birthdate, MILLENNIUM),
                new Contact(Birthdate = Date.newInstance(2020, 1, 1)), true);
    }

    @IsTest
    static void greaterThanIsSatisfiedWhenTheDatetimeIsAfterTheThreshold() {
        assertSatisfiedBy(XFTY_FieldGreaterThanPredicate.of(Event.ActivityDateTime, NOON),
                new Event(ActivityDateTime = NOON.addHours(1)), true);
    }

    @IsTest
    static void greaterThanIsSatisfiedWhenTheStringSortsAfterTheThreshold() {
        assertSatisfiedBy(XFTY_FieldGreaterThanPredicate.of(Account.Name, 'Aardvark'),
                new Account(Name = 'Acme'), true);
    }

    @IsTest
    static void greaterThanIsNotSatisfiedWhenTheFieldValueIsNull() {
        assertSatisfiedBy(XFTY_FieldGreaterThanPredicate.of(Account.NumberOfEmployees, 1),
                new Account(), false);
    }

    @IsTest
    static void greaterThanIsNotSatisfiedWhenTheComparisonValueIsNull() {
        assertSatisfiedBy(XFTY_FieldGreaterThanPredicate.of(Account.NumberOfEmployees, null),
                new Account(NumberOfEmployees = 5), false);
    }

    @IsTest
    static void greaterThanIsNotSatisfiedByANullRecord() {
        assertSatisfiedBy(XFTY_FieldGreaterThanPredicate.of(Account.NumberOfEmployees, 1), null, false);
    }

    // XFTY_FieldLessThanPredicate -----------------------------------------

    @IsTest
    static void lessThanIsSatisfiedWhenTheNumberIsBelowTheThreshold() {
        assertSatisfiedBy(XFTY_FieldLessThanPredicate.of(Account.NumberOfEmployees, 100),
                new Account(NumberOfEmployees = 5), true);
    }

    @IsTest
    static void lessThanIsNotSatisfiedWhenTheNumberEqualsTheThreshold() {
        assertSatisfiedBy(XFTY_FieldLessThanPredicate.of(Account.NumberOfEmployees, 100),
                new Account(NumberOfEmployees = 100), false);
    }

    @IsTest
    static void lessThanIsNotSatisfiedWhenTheNumberIsAboveTheThreshold() {
        assertSatisfiedBy(XFTY_FieldLessThanPredicate.of(Account.NumberOfEmployees, 100),
                new Account(NumberOfEmployees = 900), false);
    }

    @IsTest
    static void lessThanIsSatisfiedWhenTheDateIsBeforeTheThreshold() {
        assertSatisfiedBy(XFTY_FieldLessThanPredicate.of(Contact.Birthdate, MILLENNIUM),
                new Contact(Birthdate = Date.newInstance(1980, 1, 1)), true);
    }

    @IsTest
    static void lessThanIsNotSatisfiedByANullRecord() {
        assertSatisfiedBy(XFTY_FieldLessThanPredicate.of(Account.NumberOfEmployees, 1), null, false);
    }

    // XFTY_FieldInSetPredicate ------------------------------------------

    @IsTest
    static void inSetIsSatisfiedWhenTheFieldIsAMemberOfTheSet() {
        assertSatisfiedBy(XFTY_FieldInSetPredicate.of(Account.Industry, new Set<Object>{ 'Finance', 'Technology' }),
                new Account(Industry = 'Technology'), true);
    }

    @IsTest
    static void inSetIsNotSatisfiedWhenTheFieldIsNotAMemberOfTheSet() {
        assertSatisfiedBy(XFTY_FieldInSetPredicate.of(Account.Industry, new Set<Object>{ 'Finance', 'Technology' }),
                new Account(Industry = 'Retail'), false);
    }

    @IsTest
    static void inSetWithANullSetIsSatisfiedByNothing() {
        assertSatisfiedBy(XFTY_FieldInSetPredicate.of(Account.Industry, null),
                new Account(Industry = 'Technology'), false);
    }

    @IsTest
    static void inSetIsNotSatisfiedByANullRecord() {
        assertSatisfiedBy(XFTY_FieldInSetPredicate.of(Account.Industry, new Set<Object>{ 'Technology' }), null, false);
    }

    // XFTY_ValueComparison - compare(left, right) -------------------------

    @IsTest
    static void compareRanksAHigherNumberAsGreater() {
        assertCompareSign(900, 100, 1);
    }

    @IsTest
    static void compareRanksEqualNumbersAsEqual() {
        assertCompareSign(100, 100, 0);
    }

    @IsTest
    static void compareRanksALowerNumberAsLess() {
        assertCompareSign(5, 100, -1);
    }

    @IsTest
    static void compareRanksDecimalsNumerically() {
        assertCompareSign(1000000.50, 1000000.25, 1);
    }

    @IsTest
    static void compareRanksALaterDateAsGreater() {
        assertCompareSign(Date.newInstance(2020, 1, 1), MILLENNIUM, 1);
    }

    @IsTest
    static void compareRanksAnEarlierDateAsLess() {
        assertCompareSign(Date.newInstance(1980, 1, 1), MILLENNIUM, -1);
    }

    @IsTest
    static void compareRanksALaterDatetimeAsGreater() {
        assertCompareSign(NOON.addHours(1), NOON, 1);
    }

    @IsTest
    static void compareRanksStringsLexicographically() {
        assertCompareSign('Acme', 'Aardvark', 1);
    }

    // XFTY_ValueComparison - fieldToValue(record, field, value) ----------

    @IsTest
    static void fieldToValueIsNullWhenTheFieldIsAbsent() {
        assertFieldToValueIsNull(new Account(), 100);
    }

    @IsTest
    static void fieldToValueIsNullWhenTheComparisonValueIsNull() {
        assertFieldToValueIsNull(new Account(NumberOfEmployees = 5), null);
    }

    @IsTest
    static void fieldToValueIsNullWhenTheRecordIsNull() {
        assertFieldToValueIsNull(null, 100);
    }

    @IsTest
    static void fieldToValueRanksThePresentPairNormally() {
        // Arrange
        Account record = new Account(NumberOfEmployees = 900);

        // Act
        Integer comparison = XFTY_ValueComparison.fieldToValue(record, Account.NumberOfEmployees, 100);

        // Assert
        Assert.areEqual(1, comparison);
    }

    // XFTY_AllOfPredicate --------------------------------------------------

    @IsTest
    static void allOfIsSatisfiedWhenEveryMemberIs() {
        assertSatisfiedBy(
                XFTY_AllOfPredicate.of(new List<XFTY_SObjectPredicateIntf>{
                        XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 100),
                        XFTY_FieldPredicate.equalTo(Account.Industry, 'Technology')
                }),
                new Account(NumberOfEmployees = 900, Industry = 'Technology'), true);
    }

    @IsTest
    static void allOfIsNotSatisfiedWhenOneMemberIsNot() {
        assertSatisfiedBy(
                XFTY_AllOfPredicate.of(new List<XFTY_SObjectPredicateIntf>{
                        XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 100),
                        XFTY_FieldPredicate.equalTo(Account.Industry, 'Technology')
                }),
                new Account(NumberOfEmployees = 900, Industry = 'Retail'), false);
    }

    @IsTest
    static void allOfWithNoMembersIsVacuouslySatisfied() {
        assertSatisfiedBy(XFTY_AllOfPredicate.of(new List<XFTY_SObjectPredicateIntf>()), new Account(), true);
    }

    @IsTest
    static void allOfRejectsANullList() {
        // Arrange
        // nothing to arrange

        // Act
        try {
            XFTY_AllOfPredicate.of(null);
            Assert.fail('Expected an exception');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            // Assert
            Assert.isTrue(ex.getMessage().contains('predicate list is required'), ex.getMessage());
        }
    }

    // XFTY_AnyOfPredicate ------------------------------------------------

    @IsTest
    static void anyOfIsSatisfiedWhenOneMemberIs() {
        assertSatisfiedBy(
                XFTY_AnyOfPredicate.of(new List<XFTY_SObjectPredicateIntf>{
                        XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 5000),
                        XFTY_FieldPredicate.equalTo(Account.Industry, 'Technology')
                }),
                new Account(NumberOfEmployees = 10, Industry = 'Technology'), true);
    }

    @IsTest
    static void anyOfIsNotSatisfiedWhenNoMemberIs() {
        assertSatisfiedBy(
                XFTY_AnyOfPredicate.of(new List<XFTY_SObjectPredicateIntf>{
                        XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 5000),
                        XFTY_FieldPredicate.equalTo(Account.Industry, 'Technology')
                }),
                new Account(NumberOfEmployees = 10, Industry = 'Retail'), false);
    }

    @IsTest
    static void anyOfWithNoMembersIsNeverSatisfied() {
        assertSatisfiedBy(XFTY_AnyOfPredicate.of(new List<XFTY_SObjectPredicateIntf>()), new Account(), false);
    }

    @IsTest
    static void anyOfRejectsANullList() {
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

    // XFTY_NegationPredicate -------------------------------------------

    @IsTest
    static void negationIsNotSatisfiedWhenTheInnerPredicateIs() {
        assertSatisfiedBy(XFTY_NegationPredicate.of(XFTY_FieldPredicate.equalTo(Account.Type, 'Prospect')),
                new Account(Type = 'Prospect'), false);
    }

    @IsTest
    static void negationIsSatisfiedWhenTheInnerPredicateIsNot() {
        assertSatisfiedBy(XFTY_NegationPredicate.of(XFTY_FieldPredicate.equalTo(Account.Type, 'Prospect')),
                new Account(Type = 'Customer'), true);
    }

    @IsTest
    static void negationRejectsANullPredicate() {
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

    // XFTY_FieldPredicate facade ------------------------------------------

    @IsTest
    static void facadeEqualToBehavesAsEqualTo() {
        assertSatisfiedBy(XFTY_FieldPredicate.equalTo(Account.Industry, 'Technology'),
                new Account(Industry = 'Technology'), true);
    }

    @IsTest
    static void facadeNotEqualToIsSatisfiedWhenTheFieldDiffers() {
        assertSatisfiedBy(XFTY_FieldPredicate.notEqualTo(Account.Industry, 'Retail'),
                new Account(Industry = 'Technology'), true);
    }

    @IsTest
    static void facadeGreaterThanBehavesAsGreaterThan() {
        assertSatisfiedBy(XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 100),
                new Account(NumberOfEmployees = 900), true);
    }

    @IsTest
    static void facadeLessThanBehavesAsLessThan() {
        assertSatisfiedBy(XFTY_FieldPredicate.lessThan(Account.NumberOfEmployees, 100),
                new Account(NumberOfEmployees = 5), true);
    }

    @IsTest
    static void facadeIsNullIsSatisfiedByABlankField() {
        assertSatisfiedBy(XFTY_FieldPredicate.isNull(Account.Industry), new Account(), true);
    }

    @IsTest
    static void facadeIsNotNullIsSatisfiedByASetField() {
        assertSatisfiedBy(XFTY_FieldPredicate.isNotNull(Account.Industry),
                new Account(Industry = 'Technology'), true);
    }

    @IsTest
    static void facadeInSetBehavesAsInSet() {
        assertSatisfiedBy(XFTY_FieldPredicate.inSet(Account.Industry, new Set<Object>{ 'Technology' }),
                new Account(Industry = 'Technology'), true);
    }

    // XFTY_Predicates facade -------------------------------------------

    @IsTest
    static void predicatesAllOfBehavesAsAllOf() {
        assertSatisfiedBy(
                XFTY_Predicates.allOf(new List<XFTY_SObjectPredicateIntf>{
                        XFTY_FieldPredicate.equalTo(Account.Industry, 'Technology')
                }),
                new Account(Industry = 'Retail'), false);
    }

    @IsTest
    static void predicatesAnyOfBehavesAsAnyOf() {
        assertSatisfiedBy(
                XFTY_Predicates.anyOf(new List<XFTY_SObjectPredicateIntf>{
                        XFTY_FieldPredicate.equalTo(Account.Industry, 'Technology')
                }),
                new Account(Industry = 'Technology'), true);
    }

    @IsTest
    static void predicatesNotBehavesAsNegation() {
        assertSatisfiedBy(XFTY_Predicates.not(XFTY_FieldPredicate.equalTo(Account.Type, 'Prospect')),
                new Account(Type = 'Customer'), true);
    }

    // Driving a flavoured lookup key -------------------------------------

    @IsTest
    static void aCombinatorTreeIsSatisfiedWhenTheRecordMatchesAFlavour() {
        // Arrange - the docs/extend/provider-variants.md "strategic" example verbatim:
        // (big revenue OR big headcount) AND not a prospect
        XFTY_FlavouredLookupKey strategic = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'strategic')
                .matching(XFTY_Predicates.anyOf(new List<XFTY_SObjectPredicateIntf>{
                        XFTY_FieldPredicate.greaterThan(Account.AnnualRevenue, 1000000),
                        XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 5000)
                }))
                .matching(XFTY_Predicates.not(XFTY_FieldPredicate.equalTo(Account.Type, 'Prospect')));

        // Act
        Boolean result = strategic.isInstanceOf(new Account(NumberOfEmployees = 6000, Type = 'Customer'));

        // Assert
        Assert.isTrue(result);
    }

    @IsTest
    static void aCombinatorTreeExcludesARecordTheNotRejects() {
        assertMatchesStrategicFlavour('strategic-not', new Account(NumberOfEmployees = 6000, Type = 'Prospect'), false);
    }

    @IsTest
    static void aCombinatorTreeExcludesARecordNoOrBranchMatches() {
        assertMatchesStrategicFlavour('strategic-neither', new Account(NumberOfEmployees = 10, AnnualRevenue = 5), false);
    }

    // Helpers -----------------------------------------------------------

    static void assertSatisfiedBy(XFTY_SObjectPredicateIntf predicate, SObject record, Boolean expected) {
        // Arrange - the caller supplies the configured predicate and the record
        // Act
        Boolean result = predicate.isSatisfiedBy(record);
        // Assert
        Assert.areEqual(expected, result);
    }

    static void assertCompareSign(Object left, Object right, Integer expectedSign) {
        // Arrange - the caller supplies the pair to order
        // Act
        Integer comparison = XFTY_ValueComparison.compare(left, right);
        // Assert
        Assert.areEqual(expectedSign, comparison);
    }

    static void assertFieldToValueIsNull(SObject record, Object comparisonValue) {
        // Arrange - the caller supplies an incomparable pairing
        // Act
        Integer comparison = XFTY_ValueComparison.fieldToValue(record, Account.NumberOfEmployees, comparisonValue);
        // Assert
        Assert.isNull(comparison);
    }

    static void assertMatchesStrategicFlavour(String flavour, Account record, Boolean expected) {
        // Arrange - "strategic" = (big revenue OR big headcount) AND not a prospect
        XFTY_FlavouredLookupKey strategic = XFTY_FlavouredLookupKey.get(Account.SObjectType, flavour)
                .matching(XFTY_Predicates.anyOf(new List<XFTY_SObjectPredicateIntf>{
                        XFTY_FieldPredicate.greaterThan(Account.AnnualRevenue, 1000000),
                        XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 5000)
                }))
                .matching(XFTY_Predicates.not(XFTY_FieldPredicate.equalTo(Account.Type, 'Prospect')));
        // Act
        Boolean result = strategic.isInstanceOf(record);
        // Assert
        Assert.areEqual(expected, result);
    }
}

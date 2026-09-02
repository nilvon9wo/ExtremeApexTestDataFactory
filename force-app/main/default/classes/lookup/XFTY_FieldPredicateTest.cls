/**
 * Coverage for the predicate building blocks: {@link XFTY_FieldComparisonPredicate},
 * {@link XFTY_FieldInSetPredicate}, the {@link XFTY_FieldPredicate} facade, and
 * the {@link XFTY_Predicates} AND / OR / NOT combinators.
 */
@IsTest
private class XFTY_FieldPredicateTest {

    // XFTY_FieldComparisonPredicate --------------------------------------------

    @IsTest
    static void equalToMatchesTheExactValueOnly() {
        // Arrange
        XFTY_SObjectPredicateIntf isTechnology = XFTY_FieldComparisonPredicate.equalTo(Account.Industry, 'Technology');

        // Act
        Boolean matches = isTechnology.isSatisfiedBy(new Account(Industry = 'Technology'));

        // Assert
        Assert.isTrue(matches);
        Assert.isFalse(isTechnology.isSatisfiedBy(new Account(Industry = 'Retail')));
    }

    @IsTest
    static void notEqualToMatchesEverythingElse() {
        // Arrange
        XFTY_SObjectPredicateIntf notRetail = XFTY_FieldComparisonPredicate.notEqualTo(Account.Industry, 'Retail');

        // Act
        Boolean matches = notRetail.isSatisfiedBy(new Account(Industry = 'Technology'));

        // Assert
        Assert.isTrue(matches);
        Assert.isFalse(notRetail.isSatisfiedBy(new Account(Industry = 'Retail')));
    }

    @IsTest
    static void greaterThanAndLessThanCompareNumbersNumerically() {
        // Arrange
        XFTY_SObjectPredicateIntf over100 = XFTY_FieldComparisonPredicate.greaterThan(Account.NumberOfEmployees, 100);

        // Act
        Boolean matches = over100.isSatisfiedBy(new Account(NumberOfEmployees = 900));

        // Assert
        Assert.isTrue(matches);
        Assert.isFalse(over100.isSatisfiedBy(new Account(NumberOfEmployees = 5)));
        Assert.isFalse(over100.isSatisfiedBy(new Account(NumberOfEmployees = 100)), 'equal is not greater');
        Assert.isTrue(
                XFTY_FieldComparisonPredicate.lessThan(Account.NumberOfEmployees, 100)
                        .isSatisfiedBy(new Account(NumberOfEmployees = 5))
        );
    }

    @IsTest
    static void greaterThanComparesDatesChronologically() {
        // Arrange
        XFTY_SObjectPredicateIntf bornAfterMillennium =
                XFTY_FieldComparisonPredicate.greaterThan(Contact.Birthdate, Date.newInstance(2000, 1, 1));

        // Act
        Boolean matches = bornAfterMillennium.isSatisfiedBy(new Contact(Birthdate = Date.newInstance(2020, 1, 1)));

        // Assert
        Assert.isTrue(matches);
        Assert.isFalse(bornAfterMillennium.isSatisfiedBy(new Contact(Birthdate = Date.newInstance(1980, 1, 1))));
    }

    @IsTest
    static void greaterThanComparesDatetimesChronologically() {
        // Arrange
        Datetime noon = Datetime.newInstanceGmt(2024, 1, 1, 12, 0, 0);
        XFTY_SObjectPredicateIntf afterNoon = XFTY_FieldComparisonPredicate.greaterThan(Event.ActivityDateTime, noon);

        // Act
        Boolean matches = afterNoon.isSatisfiedBy(new Event(ActivityDateTime = noon.addHours(1)));

        // Assert
        Assert.isTrue(matches);
        Assert.isFalse(afterNoon.isSatisfiedBy(new Event(ActivityDateTime = noon.addHours(-1))));
    }

    @IsTest
    static void greaterThanComparesOtherTypesLexicographically() {
        // Arrange
        XFTY_SObjectPredicateIntf afterAardvark = XFTY_FieldComparisonPredicate.greaterThan(Account.Name, 'Aardvark');

        // Act
        Boolean matches = afterAardvark.isSatisfiedBy(new Account(Name = 'Acme'));

        // Assert
        Assert.isTrue(matches);
        Assert.isFalse(afterAardvark.isSatisfiedBy(new Account(Name = 'Aaa')));
    }

    @IsTest
    static void isNullAndIsNotNullReasonAboutAbsentValues() {
        // Arrange
        Account blank = new Account();
        Account named = new Account(Name = 'x');

        // Act
        Boolean nameIsNull = XFTY_FieldComparisonPredicate.isNull(Account.Name).isSatisfiedBy(blank);

        // Assert
        Assert.isTrue(nameIsNull);
        Assert.isTrue(XFTY_FieldComparisonPredicate.isNotNull(Account.Name).isSatisfiedBy(named));
        Assert.isFalse(XFTY_FieldComparisonPredicate.isNull(Account.Name).isSatisfiedBy(named));
    }

    @IsTest
    static void orderingComparisonsAreFalseWhenEitherSideIsNull() {
        // Arrange
        XFTY_SObjectPredicateIntf over1 = XFTY_FieldComparisonPredicate.greaterThan(Account.NumberOfEmployees, 1);

        // Act
        Boolean nullRecord = over1.isSatisfiedBy(null);

        // Assert
        Assert.isFalse(nullRecord, 'null record');
        Assert.isFalse(over1.isSatisfiedBy(new Account()), 'null field value');
        Assert.isFalse(
                XFTY_FieldComparisonPredicate.greaterThan(Account.NumberOfEmployees, null)
                        .isSatisfiedBy(new Account(NumberOfEmployees = 5)),
                'null comparison value'
        );
    }

    // XFTY_FieldInSetPredicate ------------------------------------------------

    @IsTest
    static void inSetMatchesAnyMemberOfTheSet() {
        // Arrange
        XFTY_SObjectPredicateIntf financeOrTech =
                XFTY_FieldInSetPredicate.of(Account.Industry, new Set<Object>{ 'Finance', 'Technology' });

        // Act
        Boolean matches = financeOrTech.isSatisfiedBy(new Account(Industry = 'Technology'));

        // Assert
        Assert.isTrue(matches);
        Assert.isFalse(financeOrTech.isSatisfiedBy(new Account(Industry = 'Retail')));
    }

    @IsTest
    static void inSetWithANullSetMatchesNothing() {
        // Arrange
        XFTY_SObjectPredicateIntf never = XFTY_FieldInSetPredicate.of(Account.Industry, null);

        // Act
        Boolean matches = never.isSatisfiedBy(new Account(Industry = 'Technology'));

        // Assert
        Assert.isFalse(matches);
    }

    // XFTY_FieldPredicate facade --------------------------------------------

    @IsTest
    static void theFacadeReturnsEquivalentPredicates() {
        // Arrange
        Account big = new Account(NumberOfEmployees = 900, Industry = 'Technology');

        // Act
        Boolean matches = XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 100).isSatisfiedBy(big);

        // Assert
        Assert.isTrue(matches);
        Assert.isTrue(XFTY_FieldPredicate.equalTo(Account.Industry, 'Technology').isSatisfiedBy(big));
        Assert.isTrue(XFTY_FieldPredicate.notEqualTo(Account.Industry, 'Retail').isSatisfiedBy(big));
        Assert.isTrue(XFTY_FieldPredicate.lessThan(Account.NumberOfEmployees, 1000).isSatisfiedBy(big));
        Assert.isTrue(XFTY_FieldPredicate.isNotNull(Account.Industry).isSatisfiedBy(big));
        Assert.isTrue(XFTY_FieldPredicate.isNull(Account.Name).isSatisfiedBy(big));
        Assert.isTrue(
                XFTY_FieldPredicate.inSet(Account.Industry, new Set<Object>{ 'Technology' }).isSatisfiedBy(big)
        );
    }

    // XFTY_Predicates - AND / OR / NOT --------------------------------------

    @IsTest
    static void allOfRequiresEveryMemberPredicate() {
        // Arrange
        XFTY_SObjectPredicateIntf bigTech = XFTY_Predicates.allOf(new List<XFTY_SObjectPredicateIntf>{
                XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 100),
                XFTY_FieldPredicate.equalTo(Account.Industry, 'Technology')
        });

        // Act
        Boolean bothTrue = bigTech.isSatisfiedBy(new Account(NumberOfEmployees = 900, Industry = 'Technology'));

        // Assert
        Assert.isTrue(bothTrue);
        Assert.isFalse(bigTech.isSatisfiedBy(new Account(NumberOfEmployees = 900, Industry = 'Retail')));
        Assert.isFalse(bigTech.isSatisfiedBy(new Account(NumberOfEmployees = 5, Industry = 'Technology')));
    }

    @IsTest
    static void allOfWithAnEmptyListIsVacuouslyTrue() {
        // Arrange
        XFTY_SObjectPredicateIntf trivial = XFTY_Predicates.allOf(new List<XFTY_SObjectPredicateIntf>());

        // Act
        Boolean matches = trivial.isSatisfiedBy(new Account());

        // Assert
        Assert.isTrue(matches);
    }

    @IsTest
    static void anyOfNeedsAtLeastOneMemberPredicate() {
        // Arrange
        XFTY_SObjectPredicateIntf bigOrTech = XFTY_Predicates.anyOf(new List<XFTY_SObjectPredicateIntf>{
                XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 5000),
                XFTY_FieldPredicate.equalTo(Account.Industry, 'Technology')
        });

        // Act
        Boolean oneTrue = bigOrTech.isSatisfiedBy(new Account(NumberOfEmployees = 10, Industry = 'Technology'));

        // Assert
        Assert.isTrue(oneTrue);
        Assert.isFalse(bigOrTech.isSatisfiedBy(new Account(NumberOfEmployees = 10, Industry = 'Retail')));
    }

    @IsTest
    static void anyOfWithAnEmptyListIsNeverSatisfied() {
        // Arrange
        XFTY_SObjectPredicateIntf impossible = XFTY_Predicates.anyOf(new List<XFTY_SObjectPredicateIntf>());

        // Act
        Boolean matches = impossible.isSatisfiedBy(new Account());

        // Assert
        Assert.isFalse(matches);
    }

    @IsTest
    static void notInvertsItsInnerPredicate() {
        // Arrange
        XFTY_SObjectPredicateIntf notProspect =
                XFTY_Predicates.not(XFTY_FieldPredicate.equalTo(Account.Type, 'Prospect'));

        // Act
        Boolean matches = notProspect.isSatisfiedBy(new Account(Type = 'Customer'));

        // Assert
        Assert.isTrue(matches);
        Assert.isFalse(notProspect.isSatisfiedBy(new Account(Type = 'Prospect')));
    }

    @IsTest
    static void combinatorsNestArbitrarily() {
        // Arrange - (big OR tech) AND NOT prospect
        XFTY_SObjectPredicateIntf tree = XFTY_Predicates.allOf(new List<XFTY_SObjectPredicateIntf>{
                XFTY_Predicates.anyOf(new List<XFTY_SObjectPredicateIntf>{
                        XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 5000),
                        XFTY_FieldPredicate.equalTo(Account.Industry, 'Technology')
                }),
                XFTY_Predicates.not(XFTY_FieldPredicate.equalTo(Account.Type, 'Prospect'))
        });

        // Act
        Boolean matches = tree.isSatisfiedBy(new Account(Industry = 'Technology', Type = 'Customer'));

        // Assert
        Assert.isTrue(matches);
        Assert.isFalse(tree.isSatisfiedBy(new Account(Industry = 'Technology', Type = 'Prospect')));
        Assert.isFalse(tree.isSatisfiedBy(new Account(Industry = 'Retail', Type = 'Customer')));
    }

    @IsTest
    static void allOfRejectsANullList() {
        // Arrange
        // nothing to arrange

        // Act
        try {
            XFTY_Predicates.allOf(null);
            Assert.fail('Expected an exception');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            // Assert
            Assert.isTrue(ex.getMessage().contains('predicate list is required'), ex.getMessage());
        }
    }

    @IsTest
    static void notRejectsANullPredicate() {
        // Arrange
        // nothing to arrange

        // Act
        try {
            XFTY_Predicates.not(null);
            Assert.fail('Expected an exception');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            // Assert
            Assert.isTrue(ex.getMessage().contains('predicate to negate is required'), ex.getMessage());
        }
    }

    @IsTest
    static void combinatorsDriveAFlavouredLookupKey() {
        // Arrange
        XFTY_FlavouredLookupKey strategic = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'strategic')
                .matching(XFTY_Predicates.anyOf(new List<XFTY_SObjectPredicateIntf>{
                        XFTY_FieldPredicate.greaterThan(Account.AnnualRevenue, 1000000),
                        XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 5000)
                }))
                .matching(XFTY_Predicates.not(XFTY_FieldPredicate.equalTo(Account.Type, 'Prospect')));

        // Act
        Boolean matches = strategic.isInstanceOf(new Account(NumberOfEmployees = 6000, Type = 'Customer'));

        // Assert
        Assert.isTrue(matches);
        Assert.isFalse(strategic.isInstanceOf(new Account(NumberOfEmployees = 6000, Type = 'Prospect')), 'NOT excludes it');
        Assert.isFalse(strategic.isInstanceOf(new Account(NumberOfEmployees = 10, AnnualRevenue = 5)), 'neither OR branch');
    }
}

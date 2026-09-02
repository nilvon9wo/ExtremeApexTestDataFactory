/**
 * Discoverable factory for the boolean combinators over
 * {@link XFTY_SObjectPredicateIntf}. Multiple `XFTY_FlavouredLookupKey.matching(...)`
 * calls are already an implicit AND; these add OR and NOT and let a single
 * `matching(...)` carry a whole boolean tree.
 *
 * ```apex
 * XFTY_FlavouredLookupKey.get(Account.SObjectType, 'strategic')
 *     .matching(XFTY_Predicates.anyOf(new List<XFTY_SObjectPredicateIntf>{
 *         XFTY_FieldPredicate.greaterThan(Account.AnnualRevenue, 1000000),
 *         XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 5000)
 *     }))
 *     .matching(XFTY_Predicates.negate(XFTY_FieldPredicate.equalTo(Account.Type, 'Prospect')))
 * ```
 *
 * Each result is itself an `XFTY_SObjectPredicateIntf`, so they nest. The
 * implementations are {@link XFTY_AllOfPredicate}, {@link XFTY_AnyOfPredicate}
 * and {@link XFTY_NegationPredicate} - use those directly if you prefer; this
 * facade only saves an import.
 */
@IsTest
public class XFTY_Predicates {

    /** Satisfied only when every member predicate is. An empty list is vacuously satisfied. */
    public static XFTY_SObjectPredicateIntf allOf(List<XFTY_SObjectPredicateIntf> predicates) {
        return XFTY_AllOfPredicate.of(predicates);
    }

    /** Satisfied when at least one member predicate is. An empty list is never satisfied. */
    public static XFTY_SObjectPredicateIntf anyOf(List<XFTY_SObjectPredicateIntf> predicates) {
        return XFTY_AnyOfPredicate.of(predicates);
    }

    /** Satisfied exactly when `predicate` is not. (`not` is an Apex reserved word.) */
    public static XFTY_SObjectPredicateIntf negate(XFTY_SObjectPredicateIntf predicate) {
        return XFTY_NegationPredicate.of(predicate);
    }
}

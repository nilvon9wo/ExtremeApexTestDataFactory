/**
 * Discoverable factory for the ready-made single-field
 * {@link XFTY_SObjectPredicateIntf} conditions. Each call returns a plain
 * predicate you can hand to `XFTY_FlavouredLookupKey.matching(...)`, combine with
 * {@link XFTY_Predicates}, or evaluate directly.
 *
 * ```apex
 * XFTY_FlavouredLookupKey.get(Account.SObjectType, 'enterprise')
 *     .matching(XFTY_FieldPredicate.greaterThan(Account.AnnualRevenue, 1000000))
 *     .matching(XFTY_Predicates.anyOf(new List<XFTY_SObjectPredicateIntf>{
 *         XFTY_FieldPredicate.inSet(Account.Industry, new Set<Object>{ 'Finance', 'Technology' }),
 *         XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 5000)
 *     }))
 * ```
 *
 * These cover the common cases only. Any condition is fair game - implement
 * {@link XFTY_SObjectPredicateIntf} yourself for anything these do not express
 * (see `docs/extend/provider-variants.md`).
 *
 * The comparison logic lives in {@link XFTY_FieldComparisonPredicate}; set
 * membership in {@link XFTY_FieldInSetPredicate}. Use those directly if you
 * prefer - this facade only saves an import.
 */
@IsTest
public class XFTY_FieldPredicate {

    public static XFTY_SObjectPredicateIntf equalTo(SObjectField field, Object value) {
        return XFTY_FieldComparisonPredicate.equalTo(field, value);
    }

    public static XFTY_SObjectPredicateIntf notEqualTo(SObjectField field, Object value) {
        return XFTY_FieldComparisonPredicate.notEqualTo(field, value);
    }

    public static XFTY_SObjectPredicateIntf greaterThan(SObjectField field, Object value) {
        return XFTY_FieldComparisonPredicate.greaterThan(field, value);
    }

    public static XFTY_SObjectPredicateIntf lessThan(SObjectField field, Object value) {
        return XFTY_FieldComparisonPredicate.lessThan(field, value);
    }

    public static XFTY_SObjectPredicateIntf isNull(SObjectField field) {
        return XFTY_FieldComparisonPredicate.isNull(field);
    }

    public static XFTY_SObjectPredicateIntf isNotNull(SObjectField field) {
        return XFTY_FieldComparisonPredicate.isNotNull(field);
    }

    public static XFTY_SObjectPredicateIntf inSet(SObjectField field, Set<Object> values) {
        return XFTY_FieldInSetPredicate.of(field, values);
    }
}

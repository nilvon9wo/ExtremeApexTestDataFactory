/**
 * Discoverable factory for the ready-made single-field
 * {@link XFTY_SObjectPredicateIntf} conditions. Each call returns a plain
 * predicate you can hand to `XFTY_FlavouredLookupKey.matching(...)`, combine with
 * {@link XFTY_Predicates}, or evaluate directly.
 *
 * ```apex
 * XFTY_FlavouredLookupKey.get(Account.SObjectType, 'enterprise')
 *     .matching(XFTY_FieldPredicate.greaterThan(Account.AnnualRevenue, 1000000))
 *     .matching(XFTY_FieldPredicate.inSet(Account.Industry, new Set<Object>{ 'Finance', 'Technology' }))
 * ```
 *
 * These cover the common cases only. Any condition is fair game - implement
 * {@link XFTY_SObjectPredicateIntf} yourself for anything these do not express
 * (see `docs/extend/provider-variants.md`).
 *
 * Each factory just wires up a purpose-built class - `equalTo` →
 * {@link XFTY_FieldEqualToPredicate}, `greaterThan` →
 * {@link XFTY_FieldGreaterThanPredicate}, `inSet` → {@link XFTY_FieldInSetPredicate}
 * - and `notEqualTo` / `isNotNull` are just a negated `equalTo`. Use those
 * classes directly if you prefer; this facade only saves an import.
 */
@IsTest
public class XFTY_FieldPredicate {

    public static XFTY_SObjectPredicateIntf equalTo(SObjectField field, Object value) {
        return XFTY_FieldEqualToPredicate.of(field, value);
    }

    public static XFTY_SObjectPredicateIntf notEqualTo(SObjectField field, Object value) {
        return XFTY_NegationPredicate.of(XFTY_FieldEqualToPredicate.of(field, value));
    }

    public static XFTY_SObjectPredicateIntf greaterThan(SObjectField field, Object value) {
        return XFTY_FieldGreaterThanPredicate.of(field, value);
    }

    public static XFTY_SObjectPredicateIntf lessThan(SObjectField field, Object value) {
        return XFTY_FieldLessThanPredicate.of(field, value);
    }

    public static XFTY_SObjectPredicateIntf isNull(SObjectField field) {
        return XFTY_FieldEqualToPredicate.of(field, null);
    }

    public static XFTY_SObjectPredicateIntf isNotNull(SObjectField field) {
        return XFTY_NegationPredicate.of(XFTY_FieldEqualToPredicate.of(field, null));
    }

    public static XFTY_SObjectPredicateIntf inSet(SObjectField field, Set<Object> values) {
        return XFTY_FieldInSetPredicate.of(field, values);
    }
}

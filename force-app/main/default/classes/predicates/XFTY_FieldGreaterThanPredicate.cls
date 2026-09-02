/**
 * An {@link XFTY_SObjectPredicateIntf} satisfied when a record's field is
 * greater than a fixed value - numbers numerically, `Date` / `Datetime`
 * chronologically, everything else lexicographically (see
 * {@link XFTY_ValueComparison}). A null record, null field value, or null
 * comparison value is never greater.
 *
 * Obtain one through `XFTY_FieldGreaterThanPredicate.of(...)` or the
 * {@link XFTY_FieldPredicate} facade.
 */
@IsTest
public class XFTY_FieldGreaterThanPredicate implements XFTY_SObjectPredicateIntf {

    private final SObjectField field;
    private final Object comparisonValue;

    private XFTY_FieldGreaterThanPredicate(SObjectField field, Object comparisonValue) {
        this.field = field;
        this.comparisonValue = comparisonValue;
    }

    public static XFTY_FieldGreaterThanPredicate of(SObjectField field, Object comparisonValue) {
        return new XFTY_FieldGreaterThanPredicate(field, comparisonValue);
    }

    public Boolean isSatisfiedBy(SObject record) {
        Integer comparison = XFTY_ValueComparison.fieldToValue(record, this.field, this.comparisonValue);
        return comparison != null && comparison > 0;
    }
}

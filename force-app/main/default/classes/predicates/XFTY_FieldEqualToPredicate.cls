/**
 * An {@link XFTY_SObjectPredicateIntf} satisfied when a record's field equals a
 * fixed value - `null` included, so `equalTo(field, null)` is an "is null"
 * check. Wrap it in {@link XFTY_NegationPredicate} for "not equal" / "is not
 * null".
 *
 * Obtain one through `XFTY_FieldEqualToPredicate.of(...)` or the
 * {@link XFTY_FieldPredicate} facade.
 */
@IsTest
public class XFTY_FieldEqualToPredicate implements XFTY_SObjectPredicateIntf {

    private final SObjectField field;
    private final Object comparisonValue;

    private XFTY_FieldEqualToPredicate(SObjectField field, Object comparisonValue) {
        this.field = field;
        this.comparisonValue = comparisonValue;
    }

    public static XFTY_FieldEqualToPredicate of(SObjectField field, Object comparisonValue) {
        return new XFTY_FieldEqualToPredicate(field, comparisonValue);
    }

    public Boolean isSatisfiedBy(SObject record) {
        Object actual = (record == null) ? null : record.get(this.field);
        return actual == this.comparisonValue;
    }
}

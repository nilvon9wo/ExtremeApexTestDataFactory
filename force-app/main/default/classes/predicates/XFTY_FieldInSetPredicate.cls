/**
 * An {@link XFTY_SObjectPredicateIntf} that is satisfied when a field's value is
 * one of a fixed set. A null set is treated as empty (nothing matches).
 *
 * Obtain one through `XFTY_FieldInSetPredicate.of(...)` or the
 * {@link XFTY_FieldPredicate} facade.
 */
@IsTest
public class XFTY_FieldInSetPredicate implements XFTY_SObjectPredicateIntf {

    private final SObjectField field;
    private final Set<Object> acceptedValues;

    private XFTY_FieldInSetPredicate(SObjectField field, Set<Object> acceptedValues) {
        this.field = field;
        this.acceptedValues = (acceptedValues == null) ? new Set<Object>() : acceptedValues;
    }

    public static XFTY_FieldInSetPredicate of(SObjectField field, Set<Object> acceptedValues) {
        return new XFTY_FieldInSetPredicate(field, acceptedValues);
    }

    public Boolean isSatisfiedBy(SObject record) {
        Object actual = (record == null) ? null : record.get(this.field);
        return this.acceptedValues.contains(actual);
    }
}

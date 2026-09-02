/**
 * An {@link XFTY_SObjectPredicateIntf} that compares one field of a record
 * against a fixed value: equal, not equal, greater than, less than.
 *
 * Obtain one through a named factory - `XFTY_FieldComparisonPredicate.greaterThan(...)`
 * - or through the {@link XFTY_FieldPredicate} facade. Numbers compare
 * numerically, `Date` / `Datetime` chronologically, everything else
 * lexicographically. A null record, a null field value, or a null comparison
 * value makes `greaterThan` / `lessThan` false (only `equalTo` / `notEqualTo`
 * reason about null).
 */
@IsTest
public class XFTY_FieldComparisonPredicate implements XFTY_SObjectPredicateIntf {

    private enum Operator { EQUAL_TO, NOT_EQUAL_TO, GREATER_THAN, LESS_THAN }

    private final SObjectField field;
    private final Operator operator;
    private final Object comparisonValue;

    private XFTY_FieldComparisonPredicate(SObjectField field, Operator operator, Object comparisonValue) {
        this.field = field;
        this.operator = operator;
        this.comparisonValue = comparisonValue;
    }

    public static XFTY_FieldComparisonPredicate equalTo(SObjectField field, Object value) {
        return new XFTY_FieldComparisonPredicate(field, Operator.EQUAL_TO, value);
    }

    public static XFTY_FieldComparisonPredicate notEqualTo(SObjectField field, Object value) {
        return new XFTY_FieldComparisonPredicate(field, Operator.NOT_EQUAL_TO, value);
    }

    public static XFTY_FieldComparisonPredicate greaterThan(SObjectField field, Object value) {
        return new XFTY_FieldComparisonPredicate(field, Operator.GREATER_THAN, value);
    }

    public static XFTY_FieldComparisonPredicate lessThan(SObjectField field, Object value) {
        return new XFTY_FieldComparisonPredicate(field, Operator.LESS_THAN, value);
    }

    public static XFTY_FieldComparisonPredicate isNull(SObjectField field) {
        return new XFTY_FieldComparisonPredicate(field, Operator.EQUAL_TO, null);
    }

    public static XFTY_FieldComparisonPredicate isNotNull(SObjectField field) {
        return new XFTY_FieldComparisonPredicate(field, Operator.NOT_EQUAL_TO, null);
    }

    public Boolean isSatisfiedBy(SObject record) {
        Object actual = (record == null) ? null : record.get(this.field);
        switch on this.operator {
            when EQUAL_TO {
                return actual == this.comparisonValue;
            }
            when NOT_EQUAL_TO {
                return actual != this.comparisonValue;
            }
            when GREATER_THAN {
                return this.bothPresent(actual) && this.compare(actual, this.comparisonValue) > 0;
            }
            when else { // LESS_THAN
                return this.bothPresent(actual) && this.compare(actual, this.comparisonValue) < 0;
            }
        }
    }

    private Boolean bothPresent(Object actual) {
        return actual != null && this.comparisonValue != null;
    }

    private Integer compare(Object left, Object right) {
        if (this.isNumeric(left)) {
            Decimal leftNumber = Decimal.valueOf(String.valueOf(left));
            Decimal rightNumber = Decimal.valueOf(String.valueOf(right));
            return this.sign(leftNumber == rightNumber, leftNumber > rightNumber);
        }
        // Date must be checked before Datetime: in Apex a Date value is also
        // `instanceof Datetime`, but not the reverse.
        if (left instanceof Date && right instanceof Date) {
            Date leftDate = (Date) left;
            Date rightDate = (Date) right;
            return this.sign(leftDate == rightDate, leftDate > rightDate);
        }
        if (left instanceof Datetime && right instanceof Datetime) {
            Datetime leftMoment = (Datetime) left;
            Datetime rightMoment = (Datetime) right;
            return this.sign(leftMoment == rightMoment, leftMoment > rightMoment);
        }
        return String.valueOf(left).compareTo(String.valueOf(right));
    }

    private Boolean isNumeric(Object value) {
        return value instanceof Decimal
                || value instanceof Integer
                || value instanceof Long
                || value instanceof Double;
    }

    private Integer sign(Boolean isEqual, Boolean isGreater) {
        if (isEqual) {
            return 0;
        }
        return isGreater ? 1 : -1;
    }
}

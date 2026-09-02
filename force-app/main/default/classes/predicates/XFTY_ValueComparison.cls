/**
 * Orders two values the way the ordering field predicates
 * ({@link XFTY_FieldGreaterThanPredicate}, {@link XFTY_FieldLessThanPredicate})
 * need: numbers numerically, `Date` / `Datetime` chronologically, everything
 * else lexicographically.
 */
@IsTest
public class XFTY_ValueComparison {

    /**
     * `-1` / `0` / `1` comparing `record`'s `field` against `value`, or `null`
     * when either side is absent (so the caller can decide what an
     * incomparable pair means).
     */
    public static Integer fieldToValue(SObject record, SObjectField field, Object value) {
        Object actual = (record == null) ? null : record.get(field);
        Boolean incomparable = actual == null || value == null;
        return incomparable ? null : compare(actual, value);
    }

    /** `-1` / `0` / `1`. Both arguments must be non-null and of comparable kinds. */
    public static Integer compare(Object left, Object right) {
        if (isNumeric(left)) {
            Decimal leftNumber = Decimal.valueOf(String.valueOf(left));
            Decimal rightNumber = Decimal.valueOf(String.valueOf(right));
            return sign(leftNumber == rightNumber, leftNumber > rightNumber);
        }
        // Date must be checked before Datetime: in Apex a Date value is also
        // `instanceof Datetime`, but not the reverse.
        if (left instanceof Date && right instanceof Date) {
            Date leftDate = (Date) left;
            Date rightDate = (Date) right;
            return sign(leftDate == rightDate, leftDate > rightDate);
        }
        if (left instanceof Datetime && right instanceof Datetime) {
            Datetime leftMoment = (Datetime) left;
            Datetime rightMoment = (Datetime) right;
            return sign(leftMoment == rightMoment, leftMoment > rightMoment);
        }
        Integer lexical = String.valueOf(left).compareTo(String.valueOf(right));
        return sign(lexical == 0, lexical > 0);
    }

    private static Boolean isNumeric(Object value) {
        return value instanceof Decimal
                || value instanceof Integer
                || value instanceof Long
                || value instanceof Double;
    }

    private static Integer sign(Boolean isEqual, Boolean isGreater) {
        if (isEqual) {
            return 0;
        }
        return isGreater ? 1 : -1;
    }
}

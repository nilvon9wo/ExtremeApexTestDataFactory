/**
 * Ready-made {@link XFTY_SObjectPredicateIntf} conditions on a single field.
 *
 * ```apex
 * XFTY_FlavouredLookupKey.get(Account.SObjectType, 'enterprise')
 *     .matching(XFTY_FieldPredicate.greaterThan(Account.AnnualRevenue, 1000000))
 *     .matching(XFTY_FieldPredicate.inSet(Account.Industry, new Set<Object>{ 'Finance', 'Technology' }))
 * ```
 */
@IsTest
public class XFTY_FieldPredicate {

    public static XFTY_SObjectPredicateIntf equalTo(SObjectField field, Object value) {
        return new Comparison(field, ComparisonOp.EQ, value);
    }

    public static XFTY_SObjectPredicateIntf notEqualTo(SObjectField field, Object value) {
        return new Comparison(field, ComparisonOp.NE, value);
    }

    public static XFTY_SObjectPredicateIntf greaterThan(SObjectField field, Object value) {
        return new Comparison(field, ComparisonOp.GT, value);
    }

    public static XFTY_SObjectPredicateIntf lessThan(SObjectField field, Object value) {
        return new Comparison(field, ComparisonOp.LT, value);
    }

    public static XFTY_SObjectPredicateIntf isNull(SObjectField field) {
        return new Comparison(field, ComparisonOp.EQ, null);
    }

    public static XFTY_SObjectPredicateIntf isNotNull(SObjectField field) {
        return new Comparison(field, ComparisonOp.NE, null);
    }

    public static XFTY_SObjectPredicateIntf inSet(SObjectField field, Set<Object> values) {
        return new InSet(field, values);
    }

    // --------------------------------------------------------------------------

    private enum ComparisonOp { EQ, NE, GT, LT }

    private class Comparison implements XFTY_SObjectPredicateIntf {
        private final SObjectField field;
        private final ComparisonOp op;
        private final Object value;

        private Comparison(SObjectField field, ComparisonOp op, Object value) {
            this.field = field;
            this.op = op;
            this.value = value;
        }

        public Boolean isSatisfiedBy(SObject sObj) {
            Object actual = (sObj == null) ? null : sObj.get(this.field);
            switch on this.op {
                when EQ {
                    return actual == this.value;
                }
                when NE {
                    return actual != this.value;
                }
                when GT {
                    return actual != null && this.value != null && compare(actual, this.value) > 0;
                }
                when else { // LT
                    return actual != null && this.value != null && compare(actual, this.value) < 0;
                }
            }
        }

        private Integer compare(Object a, Object b) {
            if (a instanceof Decimal || a instanceof Integer || a instanceof Long || a instanceof Double) {
                Decimal da = Decimal.valueOf(String.valueOf(a));
                Decimal db = Decimal.valueOf(String.valueOf(b));
                return (da == db) ? 0 : (da > db ? 1 : -1);
            }
            // Date must be checked before Datetime: in Apex a Date value is also
            // `instanceof Datetime`, but not the reverse.
            if (a instanceof Date && b instanceof Date) {
                Date da = (Date) a;
                Date db = (Date) b;
                return (da == db) ? 0 : (da > db ? 1 : -1);
            }
            if (a instanceof Datetime && b instanceof Datetime) {
                Datetime dta = (Datetime) a;
                Datetime dtb = (Datetime) b;
                return (dta == dtb) ? 0 : (dta > dtb ? 1 : -1);
            }
            String sa = String.valueOf(a);
            String sb = String.valueOf(b);
            return sa.compareTo(sb);
        }
    }

    private class InSet implements XFTY_SObjectPredicateIntf {
        private final SObjectField field;
        private final Set<Object> values;

        private InSet(SObjectField field, Set<Object> values) {
            this.field = field;
            this.values = (values == null) ? new Set<Object>() : values;
        }

        public Boolean isSatisfiedBy(SObject sObj) {
            return this.values.contains((sObj == null) ? null : sObj.get(this.field));
        }
    }
}

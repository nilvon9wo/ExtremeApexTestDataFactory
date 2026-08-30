/**
 * Ready-made {@link XFTY_SObjectPredicateIntf} conditions on a single field, for
 * {@link XFTY_FlavouredLookupKey} matching.
 *
 * ```apex
 * XFTY_FlavouredLookupKey.get(Account.SObjectType, 'enterprise')
 *     .matching(XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 1000))
 *     .matching(XFTY_FieldPredicate.inSet(Account.Industry, new Set<Object>{ 'Finance', 'Technology' }))
 * ```
 *
 * `greaterThan` / `lessThan` compare numerically; the field value must be
 * numeric (Integer / Long / Double / Decimal) or the predicate throws.
 */
@IsTest
public class XFTY_FieldPredicate {

    public static XFTY_SObjectPredicateIntf equalTo(SObjectField field, Object value) {
        return new EqualityPredicate(field, value, true);
    }

    public static XFTY_SObjectPredicateIntf notEqualTo(SObjectField field, Object value) {
        return new EqualityPredicate(field, value, false);
    }

    public static XFTY_SObjectPredicateIntf isNull(SObjectField field) {
        return new EqualityPredicate(field, null, true);
    }

    public static XFTY_SObjectPredicateIntf isNotNull(SObjectField field) {
        return new EqualityPredicate(field, null, false);
    }

    public static XFTY_SObjectPredicateIntf inSet(SObjectField field, Set<Object> values) {
        return new InSetPredicate(field, values);
    }

    public static XFTY_SObjectPredicateIntf greaterThan(SObjectField field, Decimal value) {
        return new NumericPredicate(field, value, true);
    }

    public static XFTY_SObjectPredicateIntf lessThan(SObjectField field, Decimal value) {
        return new NumericPredicate(field, value, false);
    }

    // --------------------------------------------------------------------------

    private static Object valueOn(SObject sObj, SObjectField field) {
        return (sObj == null) ? null : sObj.get(field);
    }

    private class EqualityPredicate implements XFTY_SObjectPredicateIntf {
        private final SObjectField field;
        private final Object value;
        private final Boolean wantEqual;

        private EqualityPredicate(SObjectField field, Object value, Boolean wantEqual) {
            this.field = field;
            this.value = value;
            this.wantEqual = wantEqual;
        }

        public Boolean isSatisfiedBy(SObject sObj) {
            Boolean isEqual = valueOn(sObj, this.field) == this.value;
            return this.wantEqual ? isEqual : !isEqual;
        }
    }

    private class InSetPredicate implements XFTY_SObjectPredicateIntf {
        private final SObjectField field;
        private final Set<Object> values;

        private InSetPredicate(SObjectField field, Set<Object> values) {
            this.field = field;
            this.values = (values == null) ? new Set<Object>() : values;
        }

        public Boolean isSatisfiedBy(SObject sObj) {
            return this.values.contains(valueOn(sObj, this.field));
        }
    }

    private class NumericPredicate implements XFTY_SObjectPredicateIntf {
        private final SObjectField field;
        private final Decimal value;
        private final Boolean wantGreater;

        private NumericPredicate(SObjectField field, Decimal value, Boolean wantGreater) {
            this.field = field;
            this.value = value;
            this.wantGreater = wantGreater;
        }

        public Boolean isSatisfiedBy(SObject sObj) {
            Object actual = valueOn(sObj, this.field);
            if (actual == null || this.value == null) {
                return false;
            }
            Decimal actualNumber;
            try {
                actualNumber = Decimal.valueOf(String.valueOf(actual));
            } catch (Exception ex) {
                throw new XFTY_DummySObjectFtyProviderException(
                        'greaterThan / lessThan need a numeric field value, got: ' + actual
                );
            }
            return this.wantGreater ? actualNumber > this.value : actualNumber < this.value;
        }
    }
}

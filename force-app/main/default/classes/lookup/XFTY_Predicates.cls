/**
 * Boolean combinators for {@link XFTY_SObjectPredicateIntf}. Multiple
 * `XFTY_FlavouredLookupKey.matching(...)` calls are already an implicit AND;
 * these add OR and NOT, and let a single `matching(...)` carry a whole boolean
 * tree.
 *
 * ```apex
 * XFTY_FlavouredLookupKey.get(Account.SObjectType, 'strategic')
 *     .matching(XFTY_Predicates.anyOf(new List<XFTY_SObjectPredicateIntf>{
 *         XFTY_FieldPredicate.greaterThan(Account.AnnualRevenue, 1000000),
 *         XFTY_FieldPredicate.greaterThan(Account.NumberOfEmployees, 5000)
 *     }))
 *     .matching(XFTY_Predicates.not(XFTY_FieldPredicate.equalTo(Account.Type, 'Prospect')))
 * ```
 *
 * The results are themselves `XFTY_SObjectPredicateIntf`, so they nest.
 */
@IsTest
public class XFTY_Predicates {

    /** Satisfied only when every member predicate is. An empty list is satisfied (vacuously true). */
    public static XFTY_SObjectPredicateIntf allOf(List<XFTY_SObjectPredicateIntf> predicates) {
        return new Composite(predicates, true);
    }

    /** Satisfied when at least one member predicate is. An empty list is never satisfied. */
    public static XFTY_SObjectPredicateIntf anyOf(List<XFTY_SObjectPredicateIntf> predicates) {
        return new Composite(predicates, false);
    }

    /** Satisfied exactly when `predicate` is not. */
    public static XFTY_SObjectPredicateIntf not(XFTY_SObjectPredicateIntf predicate) {
        return new Negation(predicate);
    }

    // ---------------------------------------------------------------------

    private class Composite implements XFTY_SObjectPredicateIntf {
        private final List<XFTY_SObjectPredicateIntf> members;
        private final Boolean requireAll;

        private Composite(List<XFTY_SObjectPredicateIntf> members, Boolean requireAll) {
            if (members == null) {
                throw new XFTY_DummySObjectFtyProviderException('A predicate list is required.');
            }
            this.members = members;
            this.requireAll = requireAll;
        }

        public Boolean isSatisfiedBy(SObject record) {
            for (XFTY_SObjectPredicateIntf member : this.members) {
                if (member.isSatisfiedBy(record) != this.requireAll) {
                    // AND met its first failure; OR met its first success.
                    return !this.requireAll;
                }
            }
            return this.requireAll;
        }
    }

    private class Negation implements XFTY_SObjectPredicateIntf {
        private final XFTY_SObjectPredicateIntf inner;

        private Negation(XFTY_SObjectPredicateIntf inner) {
            if (inner == null) {
                throw new XFTY_DummySObjectFtyProviderException('A predicate to negate is required.');
            }
            this.inner = inner;
        }

        public Boolean isSatisfiedBy(SObject record) {
            return !this.inner.isSatisfiedBy(record);
        }
    }
}

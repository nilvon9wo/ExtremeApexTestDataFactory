/**
 * An {@link XFTY_SObjectPredicateIntf} satisfied exactly when the predicate it
 * wraps is not (logical NOT).
 *
 * Obtain one through `XFTY_NegationPredicate.of(...)` or the
 * {@link XFTY_Predicates} facade.
 */
@IsTest
public class XFTY_NegationPredicate implements XFTY_SObjectPredicateIntf {

    private final XFTY_SObjectPredicateIntf inner;

    private XFTY_NegationPredicate(XFTY_SObjectPredicateIntf inner) {
        this.inner = inner;
    }

    public static XFTY_NegationPredicate of(XFTY_SObjectPredicateIntf inner) {
        if (inner == null) {
            throw new XFTY_DummySObjectFtyProviderException('A predicate to negate is required.');
        }
        return new XFTY_NegationPredicate(inner);
    }

    public Boolean isSatisfiedBy(SObject record) {
        return !this.inner.isSatisfiedBy(record);
    }
}

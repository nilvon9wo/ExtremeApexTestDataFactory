/**
 * An {@link XFTY_SObjectPredicateIntf} satisfied exactly when the predicate it
 * wraps is not (logical NOT).
 *
 * Obtain one through `XFTY_NegationPredicate.of(...)` or the
 * {@link XFTY_Predicates} facade.
 */
@IsTest
public class XFTY_NegationPredicate implements XFTY_SObjectPredicateIntf {

    private final XFTY_SObjectPredicateIntf negated;

    private XFTY_NegationPredicate(XFTY_SObjectPredicateIntf negated) {
        this.negated = negated;
    }

    public static XFTY_NegationPredicate of(XFTY_SObjectPredicateIntf predicate) {
        if (predicate == null) {
            throw new XFTY_DummySObjectFtyProviderException('A predicate to negate is required.');
        }
        return new XFTY_NegationPredicate(predicate);
    }

    public Boolean isSatisfiedBy(SObject record) {
        return !this.negated.isSatisfiedBy(record);
    }
}

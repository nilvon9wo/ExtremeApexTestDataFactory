/**
 * An {@link XFTY_SObjectPredicateIntf} satisfied when at least one member
 * predicate is (logical OR). An empty member list is never satisfied.
 *
 * Obtain one through `XFTY_AnyOfPredicate.of(...)` or the {@link XFTY_Predicates}
 * facade.
 */
@IsTest
public class XFTY_AnyOfPredicate implements XFTY_SObjectPredicateIntf {

    private final List<XFTY_SObjectPredicateIntf> members;

    private XFTY_AnyOfPredicate(List<XFTY_SObjectPredicateIntf> members) {
        this.members = members;
    }

    public static XFTY_AnyOfPredicate of(List<XFTY_SObjectPredicateIntf> members) {
        if (members == null) {
            throw new XFTY_DummySObjectFtyProviderException('A predicate list is required.');
        }
        return new XFTY_AnyOfPredicate(members);
    }

    public Boolean isSatisfiedBy(SObject record) {
        for (XFTY_SObjectPredicateIntf member : this.members) {
            if (member.isSatisfiedBy(record)) {
                return true;
            }
        }
        return false;
    }
}

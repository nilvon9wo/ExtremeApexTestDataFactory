/**
 * An {@link XFTY_SObjectPredicateIntf} satisfied only when every member
 * predicate is (logical AND). An empty member list is vacuously satisfied.
 *
 * Obtain one through `XFTY_AllOfPredicate.of(...)` or the {@link XFTY_Predicates}
 * facade. Repeated `XFTY_FlavouredLookupKey.matching(...)` calls already AND
 * together, so this is for nesting an AND inside an OR / NOT.
 */
@IsTest
public class XFTY_AllOfPredicate implements XFTY_SObjectPredicateIntf {

    private final List<XFTY_SObjectPredicateIntf> members;

    private XFTY_AllOfPredicate(List<XFTY_SObjectPredicateIntf> members) {
        this.members = members;
    }

    public static XFTY_AllOfPredicate of(List<XFTY_SObjectPredicateIntf> members) {
        if (members == null) {
            throw new XFTY_DummySObjectFtyProviderException('A predicate list is required.');
        }
        return new XFTY_AllOfPredicate(members);
    }

    public Boolean isSatisfiedBy(SObject record) {
        for (XFTY_SObjectPredicateIntf member : this.members) {
            if (!member.isSatisfiedBy(record)) {
                return false;
            }
        }
        return true;
    }
}

/**
 * An arbitrary condition on an SObject, used by {@link XFTY_FlavouredLookupKey}
 * to decide whether a record belongs to a flavour. Conditions need not be
 * equality - "annual revenue over 1M", "industry in a set", "nickname is null"
 * are all fine.
 *
 * See {@link XFTY_FieldPredicate} for ready-made field conditions.
 */
public interface XFTY_SObjectPredicateIntf {
    Boolean isSatisfiedBy(SObject sObj);
}

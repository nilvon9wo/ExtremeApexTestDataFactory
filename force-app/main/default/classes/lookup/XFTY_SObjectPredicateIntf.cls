/**
 * An arbitrary condition on an SObject, used by {@link XFTY_FlavouredLookupKey}
 * to decide whether a record belongs to a flavour. Conditions need not be
 * equality - "annual revenue over 1M", "industry in a set", "nickname is null"
 * are all fine.
 *
 * Implement this yourself for anything the ready-made predicates do not express -
 * a one-method interface, no base class, no registration:
 *
 * ```apex
 * public class WeekdayCreatedPredicate implements XFTY_SObjectPredicateIntf {
 *     public Boolean isSatisfiedBy(SObject record) {
 *         Datetime created = (Datetime) record?.get('CreatedDate');
 *         return created != null
 *             && created.format('u') != '6' && created.format('u') != '7';
 *     }
 * }
 * ```
 *
 * See {@link XFTY_FieldPredicate} for ready-made single-field conditions and
 * {@link XFTY_Predicates} for AND / OR / NOT combinators.
 */
public interface XFTY_SObjectPredicateIntf {
    Boolean isSatisfiedBy(SObject sObj);
}

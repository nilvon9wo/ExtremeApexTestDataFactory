/**
 * A context-aware value that copies a field from a generated ancestor.
 *
 * Single hop:
 *
 * ```apex
 * .putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account()))
 * .put(Contact.Department, new XFTY_CopyFromAncestor(Contact.AccountId, Account.Site))
 * ```
 *
 * Multiple hops - a path of relationship fields ending in the field to read:
 *
 * ```apex
 * .put(OpportunityLineItem.Description,
 *      new XFTY_CopyFromAncestor(new List<SObjectField>{
 *          OpportunityLineItem.OpportunityId, Opportunity.AccountId, Account.Name
 *      }))
 * ```
 *
 * Returns `null` if any hop of the relationship was not generated (e.g. an
 * optional one skipped by the current inclusivity).
 */
@IsTest
public class XFTY_CopyFromAncestor implements XFTY_ContextAwareValueIntf {
    // path = [ hop1, hop2, ..., hopK, sourceField ] - K >= 1 relationship hops then the field to read.
    private final List<SObjectField> path;

    public XFTY_CopyFromAncestor(SObjectField relationshipField, SObjectField sourceField) {
        this(new List<SObjectField>{ relationshipField, sourceField });
    }

    public XFTY_CopyFromAncestor(List<SObjectField> pathEndingInSourceField) {
        if (pathEndingInSourceField == null || pathEndingInSourceField.size() < 2) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'XFTY_CopyFromAncestor needs a path of at least one relationship field then the field to read.'
            );
        }
        for (SObjectField step : pathEndingInSourceField) {
            if (step == null) {
                throw new XFTY_DummySObjectFtyProviderException('XFTY_CopyFromAncestor path steps cannot be null.');
            }
        }
        this.path = pathEndingInSourceField;
    }

    public Object get(XFTY_GenerationContext context) {
        Integer lastHop = this.path.size() - 2;   // index of the final relationship hop
        SObjectField sourceField = this.path[this.path.size() - 1];

        XFTY_DummySObjectBundle bundle = context.bundleSoFar;
        for (Integer i = 0; i < lastHop; i++) {
            bundle = (bundle == null) ? null : bundle.getBundle(this.path[i]);
        }
        if (bundle == null || context.rowIndex < 0) {
            return null;
        }

        List<SObject> records = bundle.getList(this.path[lastHop]);
        if (records == null || context.rowIndex >= records.size()) {
            return null;
        }
        SObject record = records[context.rowIndex];
        return (record == null) ? null : record.get(sourceField);
    }

    public Object get() {
        throw new XFTY_DummySObjectFtyProviderException(
                'XFTY_CopyFromAncestor is context-aware - it can only be used where the generation engine supplies a context.'
        );
    }
}

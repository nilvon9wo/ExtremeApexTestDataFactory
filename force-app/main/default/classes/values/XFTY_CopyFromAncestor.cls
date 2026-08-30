/**
 * A context-aware value that copies a field from a generated ancestor - the
 * record on the other end of one of this record's relationships.
 *
 * ```apex
 * .putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account()))
 * .put(Contact.Department, new XFTY_CopyFromAncestor(Contact.AccountId, Account.Site))
 * ```
 *
 * Single hop only for now: `relationshipField` is a lookup on *this* record,
 * `sourceField` a field on the record it points at. A deeper path
 * (`Opportunity -> Account -> Owner`) is a later concern.
 *
 * Returns `null` if the relationship was not generated (e.g. an optional one
 * skipped by the current inclusivity).
 */
@IsTest
public class XFTY_CopyFromAncestor implements XFTY_ContextAwareValueIntf {
    private final SObjectField relationshipField;
    private final SObjectField sourceField;

    public XFTY_CopyFromAncestor(SObjectField relationshipField, SObjectField sourceField) {
        if (relationshipField == null || sourceField == null) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'XFTY_CopyFromAncestor needs both a relationship field and a source field.'
            );
        }
        this.relationshipField = relationshipField;
        this.sourceField = sourceField;
    }

    public Object get(XFTY_GenerationContext context) {
        List<SObject> ancestors = (context.ancestorBundle == null)
                ? null
                : context.ancestorBundle.getList(this.relationshipField);
        if (ancestors == null || context.rowIndex < 0 || context.rowIndex >= ancestors.size()) {
            return null;
        }
        SObject ancestor = ancestors[context.rowIndex];
        return (ancestor == null) ? null : ancestor.get(this.sourceField);
    }

    public Object get() {
        throw new XFTY_DummySObjectFtyProviderException(
                'XFTY_CopyFromAncestor is context-aware - it can only be used where the generation engine supplies a context.'
        );
    }
}

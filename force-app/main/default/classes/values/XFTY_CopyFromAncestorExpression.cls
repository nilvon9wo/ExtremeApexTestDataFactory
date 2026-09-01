/**
 * A context-aware value that copies a field from a generated ancestor.
 *
 * Single hop:
 *
 * ```apex
 * .putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account()))
 * .put(Contact.Department, new XFTY_CopyFromAncestorExpression(Contact.AccountId, Account.Site))
 * ```
 *
 * Multiple hops - a path of relationship fields ending in the field to read:
 *
 * ```apex
 * .put(OpportunityLineItem.Description,
 *      new XFTY_CopyFromAncestorExpression(new List<SObjectField>{
 *          OpportunityLineItem.OpportunityId, Opportunity.AccountId, Account.Name
 *      }))
 * ```
 *
 * Returns `null` if any hop of the relationship was not generated (e.g. an
 * optional one skipped by the current inclusivity).
 */
@IsTest
public class XFTY_CopyFromAncestorExpression implements XFTY_ContextAwareExpressionIntf {
    // path = [ hop1, hop2, ..., hopK, sourceField ] - K >= 1 relationship hops then the field to read.
    private final List<SObjectField> path;

    public XFTY_CopyFromAncestorExpression(SObjectField relationshipField, SObjectField sourceField) {
        this(new List<SObjectField>{ relationshipField, sourceField });
    }

    public XFTY_CopyFromAncestorExpression(List<SObjectField> pathEndingInSourceField) {
        if (pathEndingInSourceField == null || pathEndingInSourceField.size() < 2) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'XFTY_CopyFromAncestorExpression needs a path of at least one relationship field then the field to read.'
            );
        }
        for (SObjectField step : pathEndingInSourceField) {
            if (step == null) {
                throw new XFTY_DummySObjectFtyProviderException('XFTY_CopyFromAncestorExpression path steps cannot be null.');
            }
        }
        this.path = pathEndingInSourceField;
    }

    public Object get(XFTY_GenerationContext context) {
        if (context.bundleSoFar == null) {
            return null;
        }
        return context.bundleSoFar.getValue(this.path, context.rowIndex);
    }
}

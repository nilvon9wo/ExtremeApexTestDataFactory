/**
 * An up-flowing value: a field on a record copied from a generated **child** -
 * the record that references it through `childLookupField`.
 *
 * ```apex
 * // an Account Provider, so a validation rule comparing the two passes
 * .put(Account.Site, new XFTY_CopyFromDescendantExpression(Contact.AccountId, Contact.Department))
 * ```
 *
 * Needs the `DEFERRED` insert mode (or `.depthBatched()`) - the child must exist
 * before it can be read - and resolves when `XFTY_DeferredInserter.flush()` runs.
 * With more than one matching child the **first** generated child is read;
 * with none, the value is `null`.
 *
 * See docs/roadmap/descendant-value-reads.md.
 */
@IsTest
public class XFTY_CopyFromDescendantExpression implements XFTY_DeferredExpressionIntf {

    private final SObjectField childLookupField;
    private final SObjectField sourceField;

    public XFTY_CopyFromDescendantExpression(SObjectField childLookupField, SObjectField sourceField) {
        if (childLookupField == null || sourceField == null) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'XFTY_CopyFromDescendantExpression needs the child lookup field and the field to read from the child.'
            );
        }
        this.childLookupField = childLookupField;
        this.sourceField = sourceField;
    }

    public Object get(XFTY_DeferredGraph graph, Integer recordIndex) {
        List<SObject> children = graph.childrenOf(recordIndex, this.childLookupField);
        return children.isEmpty()
                ? null
                : children[0].get(this.sourceField);
    }
}

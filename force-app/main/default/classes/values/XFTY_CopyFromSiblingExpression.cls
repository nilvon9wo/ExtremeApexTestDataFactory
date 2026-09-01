/**
 * A context-aware value that copies another field from the *same* record.
 *
 * ```apex
 * .put(Account.ShippingCity, new XFTY_LiteralExpression('Berlin'))
 * .put(Account.BillingCity, new XFTY_CopyFromSiblingExpression(Account.ShippingCity))
 * ```
 *
 * The sibling must be resolvable when this runs: a plain value / override-template
 * value (always), a wired lookup field (always - the context-aware pass runs
 * after wiring), or another context-aware value that was `put(...)` *before* this
 * one. Reading a context-aware sibling that was `put(...)` *after* this one (or a
 * circular pair) throws loudly from {@link XFTY_GenerationContext#siblingValue} -
 * it is never a silent `null`.
 */
@IsTest
public class XFTY_CopyFromSiblingExpression implements XFTY_ContextAwareExpressionIntf {
    private final SObjectField sourceField;

    public XFTY_CopyFromSiblingExpression(SObjectField sourceField) {
        if (sourceField == null) {
            throw new XFTY_DummySObjectFtyProviderException('XFTY_CopyFromSiblingExpression needs a source field.');
        }
        this.sourceField = sourceField;
    }

    public Object get(XFTY_GenerationContext context) {
        return context.siblingValue(this.sourceField);
    }
}

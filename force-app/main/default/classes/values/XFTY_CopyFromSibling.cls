/**
 * A context-aware value that copies another field from the *same* record.
 *
 * ```apex
 * .put(Account.ShippingCity, new XFTY_DummyDefaultValueExact('Berlin'))
 * .put(Account.BillingCity, new XFTY_CopyFromSibling(Account.ShippingCity))
 * ```
 *
 * The sibling must be resolvable when this runs: a plain value / override-template
 * value (always), a wired lookup field (always - the context-aware pass runs
 * after wiring), or another context-aware value that was `put(...)` *before* this
 * one.
 */
@IsTest
public class XFTY_CopyFromSibling implements XFTY_ContextAwareValueIntf {
    private final SObjectField sourceField;

    public XFTY_CopyFromSibling(SObjectField sourceField) {
        if (sourceField == null) {
            throw new XFTY_DummySObjectFtyProviderException('XFTY_CopyFromSibling needs a source field.');
        }
        this.sourceField = sourceField;
    }

    public Object get(XFTY_GenerationContext context) {
        return context.recordBeingBuilt.get(this.sourceField);
    }
}

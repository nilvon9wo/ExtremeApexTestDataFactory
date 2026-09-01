/**
 * One up-flowing value still to resolve: `records[recordIndex].field` will be
 * filled by `strategy` during the `DEFERRED` flush, once the whole forest exists.
 */
@IsTest
public class XFTY_PendingDeferredValue {

    public final Integer recordIndex;
    public final SObjectField field;
    public final XFTY_DeferredExpressionIntf strategy;

    public XFTY_PendingDeferredValue(Integer recordIndex, SObjectField field, XFTY_DeferredExpressionIntf strategy) {
        this.recordIndex = recordIndex;
        this.field = field;
        this.strategy = strategy;
    }
}

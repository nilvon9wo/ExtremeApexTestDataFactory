/**
 * The up-flow value pass: runs over the whole `DEFERRED` forest, just before the
 * depth-batched insert, and fills every field an {@link XFTY_DeferredExpressionIntf}
 * left unresolved by reading it from that record's generated descendants.
 */
@IsTest
public class XFTY_DescendantValuePass {

    private final List<SObject> records;
    private final XFTY_DeferredGraph graph;
    private final List<XFTY_PendingDeferredValue> pending;

    public XFTY_DescendantValuePass(
            List<SObject> records,
            List<XFTY_DepthBatchedInserter.ParentLink> links,
            List<XFTY_PendingDeferredValue> pending
    ) {
        this.records = records;
        this.graph = new XFTY_DeferredGraph(records, links);
        this.pending = pending;
    }

    public void complete() {
        for (XFTY_PendingDeferredValue each : this.pending) {
            this.fill(each);
        }
    }

    private void fill(XFTY_PendingDeferredValue value) {
        SObject target = this.records[value.recordIndex];
        if (target.get(value.field) != null) {
            return;
        }
        target.put(value.field, value.strategy.get(this.graph, value.recordIndex));
    }
}

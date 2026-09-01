/**
 * The whole in-memory forest a `DEFERRED` flush has collected - every generated
 * record and every parent link - presented for an {@link XFTY_DeferredExpressionIntf}
 * to read a value up from a descendant.
 */
@IsTest
public class XFTY_DeferredGraph {

    private final List<SObject> records;
    private final List<XFTY_DepthBatchedInserter.ParentLink> links;

    public XFTY_DeferredGraph(List<SObject> records, List<XFTY_DepthBatchedInserter.ParentLink> links) {
        this.records = records;
        this.links = links;
    }

    /** The generated records that reference `records[parentIndex]` through `childLookupField`. */
    public List<SObject> childrenOf(Integer parentIndex, SObjectField childLookupField) {
        List<SObject> children = new List<SObject>();
        for (XFTY_DepthBatchedInserter.ParentLink link : this.links) {
            if (link.parentIndex == parentIndex && link.field == childLookupField) {
                children.add(this.records[link.childIndex]);
            }
        }
        return children;
    }
}

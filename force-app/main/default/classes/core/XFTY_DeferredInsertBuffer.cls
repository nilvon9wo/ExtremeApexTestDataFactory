/**
 * Adapts a fully-built (but un-inserted) `XFTY_DummySObjectBundle` into the flat
 * record list + edge list that `XFTY_DepthBatchedInserter` needs, then inserts
 * the whole graph in one `insert` per dependency depth.
 *
 * Used only on the opt-in `.depthBatched()` path: the Provider runs generation in
 * `NEVER` mode (so every record is structural, no DML, related-field lookups
 * already wired from plain values), then hands the top bundle here.
 *
 * The bundle is a tree - the engine generates a distinct parent per child row
 * (see `XFTY_DummySObjectFactoryTest.quantityGeneratesADistinctParentPerRecord`),
 * so the walk visits every record exactly once and never needs to reconcile two
 * references to the same instance. Shared ancestors would break that assumption
 * and are refused earlier, in `XFTY_DummySObjectFactory.wireSharedAncestor`.
 */
@IsTest
public class XFTY_DeferredInsertBuffer {

    private final List<SObject> records = new List<SObject>();
    private final List<XFTY_DepthBatchedInserter.Edge> edges = new List<XFTY_DepthBatchedInserter.Edge>();

    /** Walk `rootBundle`, then insert every record it contains, depth-batched. */
    public static void insertGraph(XFTY_DummySObjectBundle rootBundle) {
        XFTY_DeferredInsertBuffer buffer = new XFTY_DeferredInsertBuffer();
        buffer.collect(rootBundle);
        XFTY_DepthBatchedInserter.insertAll(buffer.records, buffer.edges);
    }

    /** Register `bundle`'s primary records and every ancestor, return the primary indices (row-aligned). */
    private List<Integer> collect(XFTY_DummySObjectBundle bundle) {
        List<SObject> primaries = (bundle == null || bundle.primaryTargetField == null)
                ? null
                : bundle.getList(bundle.primaryTargetField);
        if (primaries == null) {
            return new List<Integer>();
        }

        List<Integer> primaryIndices = new List<Integer>();
        for (SObject primary : primaries) {
            this.records.add(primary);
            primaryIndices.add(this.records.size() - 1);
        }

        for (SObjectField relationshipField : bundle.relationshipFields()) {
            XFTY_DummySObjectBundle parentBundle = bundle.getBundle(relationshipField);
            List<SObject> parents = bundle.getList(relationshipField);
            if (parentBundle == null || parents == null) {
                continue;
            }
            List<Integer> parentIndices = this.collect(parentBundle);
            Integer rows = Math.min(primaries.size(), Math.min(parents.size(), parentIndices.size()));
            for (Integer i = 0; i < rows; i++) {
                if (primaries[i].get(relationshipField) == null && parents[i] != null) {
                    this.edges.add(new XFTY_DepthBatchedInserter.Edge(
                            primaryIndices[i], parentIndices[i], relationshipField
                    ));
                }
            }
        }
        return primaryIndices;
    }
}

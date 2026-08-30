/**
 * Accumulates fully-built (but un-inserted) `XFTY_DummySObjectBundle`s into the
 * flat record list + edge list that `XFTY_DepthBatchedInserter` needs, and
 * inserts them in one `insert` per dependency depth.
 *
 * Two callers:
 * - `.depthBatched()` - one bundle, inserted immediately: `insertGraph(bundle)`.
 * - the `DEFERRED` insert mode - many bundles across many `supplyBundle()` calls,
 *   inserted later: `XFTY_DeferredInsert` holds one instance, calls {@link #add}
 *   per bundle and {@link #insertAll} on `flush()`.
 *
 * Each bundle is a tree - the engine generates a distinct parent per child row
 * (see `XFTY_DummySObjectFactoryTest.quantityGeneratesADistinctParentPerRecord`)
 * and clones every template, so the walk visits every record exactly once and no
 * two bundles ever share an instance. Shared ancestors would break that and are
 * refused earlier, in `XFTY_DummySObjectFactory.wireSharedAncestor`.
 */
@IsTest
public class XFTY_DeferredInsertBuffer {

    private final List<SObject> records = new List<SObject>();
    private final List<XFTY_DepthBatchedInserter.Edge> edges = new List<XFTY_DepthBatchedInserter.Edge>();

    /** Walk `rootBundle` and insert every record it contains, depth-batched. */
    public static void insertGraph(XFTY_DummySObjectBundle rootBundle) {
        XFTY_DeferredInsertBuffer buffer = new XFTY_DeferredInsertBuffer();
        buffer.add(rootBundle);
        buffer.insertAll();
    }

    /** Add one bundle's whole graph to the pending set. */
    public void add(XFTY_DummySObjectBundle bundle) {
        this.collect(bundle);
    }

    /** How many records are pending insert. */
    public Integer pendingCount() {
        return this.records.size();
    }

    /** Insert everything added so far, one `insert` per dependency depth. */
    public void insertAll() {
        XFTY_DepthBatchedInserter.insertAll(this.records, this.edges);
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

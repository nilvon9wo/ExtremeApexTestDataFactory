/**
 * Collects the records of one or more generated-but-unsaved bundles into the flat
 * list + parent links that {@link XFTY_DepthBatchedInserter} needs, and saves
 * them.
 *
 * `.depthBatched()` collects one bundle and saves it at the end of the same call;
 * the `DEFERRED` insert mode keeps a running buffer across many `supplyBundle()`
 * calls and saves on `XFTY_DeferredInsert.flush()`.
 *
 * Each bundle is a tree - the engine clones every template and generates a
 * distinct parent per child row - so a record never appears twice and the walk
 * needs no identity tracking. Shared ancestors would break that and are refused
 * during generation.
 */
@IsTest
public class XFTY_DeferredInsertBuffer {

    private final List<SObject> pendingRecords = new List<SObject>();
    private final List<XFTY_DepthBatchedInserter.ParentLink> pendingLinks =
            new List<XFTY_DepthBatchedInserter.ParentLink>();

    public static void insertGraph(XFTY_DummySObjectBundle bundle) {
        XFTY_DeferredInsertBuffer buffer = new XFTY_DeferredInsertBuffer();
        buffer.add(bundle);
        buffer.insertAll();
    }

    public void add(XFTY_DummySObjectBundle bundle) {
        this.collect(bundle);
    }

    public Integer pendingCount() {
        return this.pendingRecords.size();
    }

    public void insertAll() {
        XFTY_DepthBatchedInserter.insertAll(this.pendingRecords, this.pendingLinks);
    }

    private List<Integer> collect(XFTY_DummySObjectBundle bundle) {
        Boolean nothingToCollect = (bundle == null) || (bundle.primaryRecords() == null);
        if (nothingToCollect) {
            return new List<Integer>();
        }
        List<SObject> primaries = bundle.primaryRecords();
        List<Integer> childIndices = this.append(primaries);
        this.linkToParents(bundle, childIndices);
        return childIndices;
    }

    private void linkToParents(XFTY_DummySObjectBundle bundle, List<Integer> childIndices) {
        for (SObjectField parentField : bundle.relationshipFields()) {
            this.linkToParentsOn(bundle, childIndices, parentField);
        }
    }

    private void linkToParentsOn(
            XFTY_DummySObjectBundle bundle,
            List<Integer> childIndices,
            SObjectField parentField
    ) {
        XFTY_DummySObjectBundle parentBundle = bundle.getBundle(parentField);
        if (parentBundle == null) {
            return;
        }
        List<SObject> children = bundle.primaryRecords();
        List<Integer> parentIndices = this.collect(parentBundle);
        this.linkUnsetLookups(children, childIndices, parentIndices, parentField);
    }

    private void linkUnsetLookups(
            List<SObject> children,
            List<Integer> childIndices,
            List<Integer> parentIndices,
            SObjectField field
    ) {
        Integer rows = rowCount(childIndices, parentIndices);
        for (Integer row = 0; row < rows; row++) {
            this.linkRow(children, childIndices, parentIndices, field, row);
        }
    }

    private void linkRow(
            List<SObject> children,
            List<Integer> childIndices,
            List<Integer> parentIndices,
            SObjectField field,
            Integer row
    ) {
        SObject child = children[row];
        Boolean alreadySet = child.get(field) != null;
        if (alreadySet) {
            return;
        }
        Integer childIndex = childIndices[row];
        Integer parentIndex = parentIndices[row];
        this.recordLink(childIndex, parentIndex, field);
    }

    private List<Integer> append(List<SObject> records) {
        List<Integer> indices = new List<Integer>();
        for (SObject record : records) {
            this.pendingRecords.add(record);
            Integer index = this.pendingRecords.size() - 1;
            indices.add(index);
        }
        return indices;
    }

    private void recordLink(Integer childIndex, Integer parentIndex, SObjectField field) {
        XFTY_DepthBatchedInserter.ParentLink link =
                new XFTY_DepthBatchedInserter.ParentLink(childIndex, parentIndex, field);
        this.pendingLinks.add(link);
    }

    private static Integer rowCount(List<Integer> childIndices, List<Integer> parentIndices) {
        return Math.min(childIndices.size(), parentIndices.size());
    }
}

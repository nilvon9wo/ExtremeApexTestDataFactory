/**
 * Collects the records of one or more generated-but-unsaved bundles into the flat
 * list + parent links that {@link XFTY_DepthBatchedInserter} needs, and saves
 * them.
 *
 * `.depthBatched()` collects one bundle and saves it at the end of the same call;
 * the `DEFERRED` insert mode keeps a running buffer across many `supplyBundle()`
 * calls and saves on `XFTY_DeferredInserter.flush()`.
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

    private List<XFTY_PendingRecord> collect(XFTY_DummySObjectBundle bundle) {
        List<SObject> primaries = primaryRecordsOf(bundle);
        if (primaries == null) {
            return new List<XFTY_PendingRecord>();
        }
        List<XFTY_PendingRecord> children = this.append(primaries);
        this.linkToParents(bundle, children);
        return children;
    }

    private void linkToParents(XFTY_DummySObjectBundle bundle, List<XFTY_PendingRecord> children) {
        for (SObjectField parentField : bundle.relationshipFields()) {
            this.linkToParentsOn(bundle, children, parentField);
        }
    }

    private void linkToParentsOn(
            XFTY_DummySObjectBundle bundle,
            List<XFTY_PendingRecord> children,
            SObjectField parentField
    ) {
        XFTY_DummySObjectBundle parentBundle = bundle.getBundle(parentField);
        if (parentBundle == null) {
            return;
        }
        List<XFTY_PendingRecord> parents = this.collect(parentBundle);
        this.linkRows(children, parents, parentField);
    }

    private void linkRows(
            List<XFTY_PendingRecord> children,
            List<XFTY_PendingRecord> parents,
            SObjectField field
    ) {
        Integer rows = Math.min(children.size(), parents.size());
        for (Integer row = 0; row < rows; row++) {
            XFTY_PendingRecord child = children[row];
            XFTY_PendingRecord parent = parents[row];
            this.linkChildToParent(child, parent, field);
        }
    }

    private void linkChildToParent(XFTY_PendingRecord child, XFTY_PendingRecord parent, SObjectField field) {
        Boolean alreadySet = child.record.get(field) != null;
        if (alreadySet) {
            return;
        }
        XFTY_DepthBatchedInserter.ParentLink link =
                new XFTY_DepthBatchedInserter.ParentLink(child.index, parent.index, field);
        this.pendingLinks.add(link);
    }

    private List<XFTY_PendingRecord> append(List<SObject> records) {
        List<XFTY_PendingRecord> pending = new List<XFTY_PendingRecord>();
        for (SObject record : records) {
            this.pendingRecords.add(record);
            Integer index = this.pendingRecords.size() - 1;
            XFTY_PendingRecord entry = new XFTY_PendingRecord(record, index);
            pending.add(entry);
        }
        return pending;
    }

    private static List<SObject> primaryRecordsOf(XFTY_DummySObjectBundle bundle) {
        return (bundle == null)
                ? null
                : bundle.primaryRecords();
    }
}

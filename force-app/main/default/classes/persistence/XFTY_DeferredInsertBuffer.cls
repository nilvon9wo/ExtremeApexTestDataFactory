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

    private final List<XFTY_DepthBatchedInserter.ParentLink> pendingLinks =
            new List<XFTY_DepthBatchedInserter.ParentLink>();
    private final List<SObject> pendingRecords = new List<SObject>();

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

    /** Depth-batched resolution of every buffered bundle honouring `mode` (NOW / MOCK / NEVER). */
    public void resolveAll(XFTY_InsertModeEnum mode) {
        XFTY_DepthBatchedInserter.resolveAll(this.pendingRecords, this.pendingLinks, mode);
    }

    private List<XFTY_IndexedRecord> collect(XFTY_DummySObjectBundle bundle) {
        List<SObject> primaries = primaryRecordsOf(bundle);
        if (primaries == null) {
            return new List<XFTY_IndexedRecord>();
        }
        List<XFTY_IndexedRecord> theseRecords = this.append(primaries);
        this.linkToParents(bundle, theseRecords);
        this.linkToChildCollections(bundle, theseRecords);
        return theseRecords;
    }

    /** Downward children (`with(...)` / `withChildren(...)`): each child row points at its primary row. */
    private void linkToChildCollections(XFTY_DummySObjectBundle bundle, List<XFTY_IndexedRecord> primaries) {
        for (SObjectField childField : bundle.childRelationshipFields()) {
            for (XFTY_DummySObjectBundle.ChildEntry entry : bundle.childEntries(childField)) {
                List<XFTY_IndexedRecord> childRecords = this.collect(entry.bundle);
                for (Integer childRow = 0; childRow < childRecords.size(); childRow++) {
                    Integer parentRow = entry.parentRowByChildRow[childRow];
                    this.linkChild(childRecords[childRow], primaries[parentRow], childField);
                }
            }
        }
    }

    private void linkToParents(XFTY_DummySObjectBundle bundle, List<XFTY_IndexedRecord> children) {
        Set<SObjectField> parentFields = bundle.relationshipFields();
        for (SObjectField parentField : parentFields) {
            this.linkToParentsOn(bundle, children, parentField);
        }
    }

    private void linkToParentsOn(
            XFTY_DummySObjectBundle bundle,
            List<XFTY_IndexedRecord> children,
            SObjectField parentField
    ) {
        XFTY_DummySObjectBundle parentBundle = bundle.getBundle(parentField);
        if (parentBundle == null) {
            return;
        }
        List<XFTY_IndexedRecord> parents = this.collect(parentBundle);
        this.linkRows(children, parents, parentField);
    }

    private void linkRows(
            List<XFTY_IndexedRecord> children,
            List<XFTY_IndexedRecord> parents,
            SObjectField field
    ) {
        Integer childCount = children.size();
        Integer parentCount = parents.size();
        Integer rows = Math.min(childCount, parentCount);
        for (Integer row = 0; row < rows; row++) {
            XFTY_IndexedRecord child = children[row];
            XFTY_IndexedRecord parent = parents[row];
            this.linkChild(child, parent, field);
        }
    }

    private void linkChild(XFTY_IndexedRecord child, XFTY_IndexedRecord parent, SObjectField field) {
        if (child.record.get(field) != null) {
            return;
        }
        XFTY_DepthBatchedInserter.ParentLink link =
                new XFTY_DepthBatchedInserter.ParentLink(child.index, parent.index, field);
        this.pendingLinks.add(link);
    }

    private List<XFTY_IndexedRecord> append(List<SObject> records) {
        List<XFTY_IndexedRecord> indexed = new List<XFTY_IndexedRecord>();
        for (SObject record : records) {
            Integer index = this.pendingRecords.size();
            this.pendingRecords.add(record);
            XFTY_IndexedRecord entry = new XFTY_IndexedRecord(index, record);
            indexed.add(entry);
        }
        return indexed;
    }

    private static List<SObject> primaryRecordsOf(XFTY_DummySObjectBundle bundle) {
        return bundle != null
                ? bundle.primaryRecords()
                : null;
    }
}

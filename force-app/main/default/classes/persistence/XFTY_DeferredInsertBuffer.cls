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
 * needs no identity tracking. A shared ancestor already carries a real / mock Id
 * by this point (resolved in its own pre-phase), so the inserter treats it as an
 * anchor and does not re-insert it.
 *
 * Just before the insert, the up-flow value pass ({@link XFTY_DescendantValuePass})
 * fills any {@link XFTY_CopyFromDescendantExpression} field from its now-generated children.
 */
@IsTest
public class XFTY_DeferredInsertBuffer {

    private final List<XFTY_DepthBatchedInserter.ParentLink> pendingLinks =
            new List<XFTY_DepthBatchedInserter.ParentLink>();
    private final List<SObject> pendingRecords = new List<SObject>();
    private final List<XFTY_PendingDeferredValue> pendingDeferredValues = new List<XFTY_PendingDeferredValue>();

    public static void insertGraph(XFTY_DummySObjectBundle bundle) {
        XFTY_DeferredInsertBuffer buffer = new XFTY_DeferredInsertBuffer();
        buffer.add(bundle);
        buffer.insertAll();
    }

    /**
     * The whole graph flattened to its records and parent links, with the up-flow
     * value pass already run - for a caller that wants to persist it itself
     * (`XFTY_Seeder`) rather than through the all-or-none `insertAll`.
     */
    public static XFTY_DeferredInsertBuffer flatten(XFTY_DummySObjectBundle bundle) {
        XFTY_DeferredInsertBuffer buffer = new XFTY_DeferredInsertBuffer();
        buffer.add(bundle);
        buffer.resolveUpFlowValues();
        return buffer;
    }

    public void add(XFTY_DummySObjectBundle bundle) {
        this.collect(bundle);
    }

    public Integer pendingCount() {
        return this.pendingRecords.size();
    }

    /** Every record the graph holds, in collection order (not insert order). */
    public List<SObject> records() {
        return this.pendingRecords;
    }

    /** Each record's lookup to another record in `records()`, by index. */
    public List<XFTY_DepthBatchedInserter.ParentLink> parentLinks() {
        return this.pendingLinks;
    }

    public void insertAll() {
        this.resolveUpFlowValues();
        XFTY_DepthBatchedInserter.insertAll(this.pendingRecords, this.pendingLinks);
    }

    /** Depth-batched resolution of every buffered bundle honouring `mode` (NOW / MOCK / NEVER). */
    public void resolveAll(XFTY_InsertModeEnum mode) {
        this.resolveUpFlowValues();
        XFTY_DepthBatchedInserter.resolveAll(this.pendingRecords, this.pendingLinks, mode);
    }

    /** Fill every {@link XFTY_CopyFromDescendantExpression} value from its now-generated descendants. */
    private void resolveUpFlowValues() {
        new XFTY_DescendantValuePass(this.pendingRecords, this.pendingLinks, this.pendingDeferredValues)
                .complete();
    }

    private List<XFTY_IndexedRecord> collect(XFTY_DummySObjectBundle bundle) {
        List<SObject> primaries = primaryRecordsOf(bundle);
        if (primaries == null) {
            return new List<XFTY_IndexedRecord>();
        }
        List<XFTY_IndexedRecord> theseRecords = this.append(primaries);
        this.captureDeferredValues(bundle, theseRecords);
        this.linkToParents(bundle, theseRecords);
        this.linkToChildCollections(bundle, theseRecords);
        return theseRecords;
    }

    /** An up-flow strategy on this bundle becomes a pending value keyed by the record's flat index. */
    private void captureDeferredValues(XFTY_DummySObjectBundle bundle, List<XFTY_IndexedRecord> primaries) {
        for (XFTY_DeferredValueQueue.Entry deferred : bundle.deferredValues()) {
            Integer recordIndex = primaries[deferred.primaryRow].index;
            this.pendingDeferredValues.add(
                    new XFTY_PendingDeferredValue(recordIndex, deferred.field, deferred.strategy)
            );
        }
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
        if (parents.isEmpty()) {
            return;
        }
        // One parent for many children is a shared ancestor collapsed to a single
        // row - every child points at it. Otherwise it is the 1:1 alignment.
        if (parents.size() == 1 && children.size() > 1) {
            for (XFTY_IndexedRecord child : children) {
                this.linkChild(child, parents[0], field);
            }
            return;
        }
        Integer rows = Math.min(children.size(), parents.size());
        for (Integer row = 0; row < rows; row++) {
            this.linkChild(children[row], parents[row], field);
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

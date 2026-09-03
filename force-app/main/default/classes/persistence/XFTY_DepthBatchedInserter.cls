/**
 * Inserts a set of not-yet-persisted records - any mix of SObject types - in one
 * `insert` per dependency layer, pointing each child's lookup at its parent's new
 * Id as the layer above it lands.
 *
 * `insertAll` / `resolveAll` are all-or-none (a fixture that half-lands is worse
 * than one that throws). `seedAll` is the best-effort variant for org seeding -
 * `Database.insert(layer, false)`, every record's outcome returned.
 *
 * Records are addressed by their index in the list: Apex compares SObjects by
 * field value, not identity, so an index is the only stable handle on one.
 */
@IsTest
public class XFTY_DepthBatchedInserter {

    /** `records[childIndex].field` should end up pointing at `records[parentIndex]`. */
    public class ParentLink {
        public final Integer childIndex;
        public final Integer parentIndex;
        public final SObjectField field;

        public ParentLink(Integer childIndex, Integer parentIndex, SObjectField field) {
            this.childIndex = childIndex;
            this.parentIndex = parentIndex;
            this.field = field;
        }
    }

    /** The lookups leave no order in which every parent lands before its child. */
    public class CyclicGraphException extends Exception {
    }

    private final List<List<ParentLink>> linksByChild;
    private final List<SObject> records;
    private final XFTY_InsertModeEnum mode;

    // Set only by seedAll: Database.insert(_, false) per layer, no throw on a row
    // failure, every SObjectType's outcome kept by record index.
    private Boolean bestEffort = false;
    private final Map<Integer, Database.SaveResult> saveResultsByIndex = new Map<Integer, Database.SaveResult>();

    private XFTY_DepthBatchedInserter(List<SObject> records, List<ParentLink> links, XFTY_InsertModeEnum mode) {
        this.records = records;
        this.mode = mode;
        Integer recordCount = records.size();
        this.linksByChild = groupLinksByChild(recordCount, links);
    }

    /** Depth-batched real DML. */
    public static void insertAll(List<SObject> records, List<ParentLink> links) {
        resolveAll(records, links, XFTY_InsertModeEnum.NOW);
    }

    /**
     * Best-effort depth-batched real DML for org seeding: each layer goes in with
     * `Database.insert(layer, false)`, so a validation rule or missing permission
     * on one record does not stop the rest. Returns each attempted record's
     * `Database.SaveResult` keyed by its index in `records`.
     */
    public static Map<Integer, Database.SaveResult> seedAll(List<SObject> records, List<ParentLink> links) {
        if (records == null || records.isEmpty()) {
            return new Map<Integer, Database.SaveResult>();
        }
        XFTY_DepthBatchedInserter inserter = new XFTY_DepthBatchedInserter(records, links, XFTY_InsertModeEnum.NOW);
        inserter.bestEffort = true;
        inserter.insertLayerByLayer();
        return inserter.saveResultsByIndex;
    }

    /**
     * Depth-batched resolution honouring the mode:
     * `NOW` inserts each depth layer, `MOCK` gives it mock Ids - either way the
     * child lookups are pointed at the layer above as it lands. `NEVER` does nothing.
     */
    public static void resolveAll(List<SObject> records, List<ParentLink> links, XFTY_InsertModeEnum mode) {
        Boolean nothingToDo = records == null
                || records.isEmpty()
                || mode == XFTY_InsertModeEnum.NEVER;
        if (nothingToDo) {
            return;
        }
        new XFTY_DepthBatchedInserter(records, links, mode)
                .insertLayerByLayer();
    }

    private void insertLayerByLayer() {
        Integer count = this.records.size();
        Set<Integer> unpersisted = allIndexes(count);
        while (!unpersisted.isEmpty()) {
            List<Integer> layer = this.takeNextLayer(unpersisted);
            this.insertLayer(layer);
            unpersisted.removeAll(layer);
        }
    }

    private List<Integer> takeNextLayer(Set<Integer> unpersisted) {
        List<Integer> layer = new List<Integer>();
        for (Integer index : unpersisted) {
            if (this.parentsPersisted(index, unpersisted)) {
                layer.add(index);
            }
        }
        return failIfEmpty(layer);
    }

    private Boolean parentsPersisted(Integer child, Set<Integer> unpersisted) {
        List<ParentLink> links = this.linksByChild[child];
        for (ParentLink link : links) {
            if (unpersisted.contains(link.parentIndex)) {
                return false;
            }
        }
        return true;
    }

    private void insertLayer(List<Integer> indexes) {
        List<SObject> layer = new List<SObject>();
        List<Integer> layerIndexes = new List<Integer>();
        for (Integer index : indexes) {
            this.pointAtParents(index);
            SObject record = this.records[index];
            // A record already carrying an Id is a pre-existing anchor (e.g. an
            // already-resolved shared ancestor) - point children at it, don't re-insert.
            if (record.Id == null) {
                layer.add(record);
                layerIndexes.add(index);
            }
        }
        if (layer.isEmpty()) {
            return;
        }
        if (this.mode == XFTY_InsertModeEnum.MOCK) {
            XFTY_IdMocker.addIds(layer);
        } else if (this.bestEffort) {
            this.saveBestEffort(layer, layerIndexes);
        } else {
            insert layer;
        }
    }

    private void saveBestEffort(List<SObject> layer, List<Integer> layerIndexes) {
        List<Database.SaveResult> results = Database.insert(layer, false);
        for (Integer i = 0; i < results.size(); i++) {
            this.saveResultsByIndex.put(layerIndexes[i], results[i]);
        }
    }

    private void pointAtParents(Integer child) {
        SObject childRecord = this.records[child];
        List<ParentLink> links = this.linksByChild[child];
        for (ParentLink link : links) {
            SObject parentRecord = this.records[link.parentIndex];
            childRecord.put(link.field, parentRecord.Id);
        }
    }

    private static List<Integer> failIfEmpty(List<Integer> layer) {
        if (!layer.isEmpty()) {
            return layer;
        }
        throw new CyclicGraphException('record lookups form a cycle - no insert order works');
    }

    private static List<List<ParentLink>> groupLinksByChild(Integer recordCount, List<ParentLink> links) {
        List<List<ParentLink>> byChild = new List<List<ParentLink>>();
        for (Integer i = 0; i < recordCount; i++) {
            List<ParentLink> empty = new List<ParentLink>();
            byChild.add(empty);
        }
        List<ParentLink> safeLinks = orEmpty(links);
        for (ParentLink link : safeLinks) {
            List<ParentLink> childLinks = byChild[link.childIndex];
            childLinks.add(link);
        }
        return byChild;
    }

    private static List<ParentLink> orEmpty(List<ParentLink> links) {
        return links != null
                ? links
                : new List<ParentLink>();
    }

    private static Set<Integer> allIndexes(Integer count) {
        Set<Integer> indexes = new Set<Integer>();
        for (Integer i = 0; i < count; i++) {
            indexes.add(i);
        }
        return indexes;
    }
}

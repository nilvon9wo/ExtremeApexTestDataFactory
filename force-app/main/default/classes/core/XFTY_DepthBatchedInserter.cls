/**
 * Inserts a set of not-yet-persisted records - any mix of SObject types - in one
 * `insert` per dependency layer, pointing each child's lookup at its parent's new
 * Id as the layer above it lands.
 *
 * Records are addressed by their index in the list: Apex compares SObjects by
 * field value, not identity, so an index is the only stable handle on one.
 */
@IsTest
public class XFTY_DepthBatchedInserter {

    public static void insertAll(List<SObject> records, List<ParentLink> links) {
        Boolean nothingToInsert = (records == null) || records.isEmpty();
        if (nothingToInsert) {
            return;
        }
        new XFTY_DepthBatchedInserter(records, links)
                .insertLayerByLayer();
    }

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

    private final List<SObject> records;
    private final List<List<ParentLink>> linksByChild;

    private XFTY_DepthBatchedInserter(List<SObject> records, List<ParentLink> links) {
        this.records = records;
        this.linksByChild = groupLinksByChild(records.size(), links);
    }

    private void insertLayerByLayer() {
        Set<Integer> unpersisted = allIndexes(this.records.size());
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
        for (Integer index : indexes) {
            this.pointAtParents(index);
            SObject record = this.records[index];
            layer.add(record);
        }
        insert layer;
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
            byChild.add(new List<ParentLink>());
        }
        List<ParentLink> safeLinks = orEmpty(links);
        for (ParentLink link : safeLinks) {
            List<ParentLink> childLinks = byChild[link.childIndex];
            childLinks.add(link);
        }
        return byChild;
    }

    private static List<ParentLink> orEmpty(List<ParentLink> links) {
        return (links == null)
                ? new List<ParentLink>()
                : links;
    }

    private static Set<Integer> allIndexes(Integer count) {
        Set<Integer> indexes = new Set<Integer>();
        for (Integer i = 0; i < count; i++) {
            indexes.add(i);
        }
        return indexes;
    }
}

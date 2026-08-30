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

    public static void insertAll(List<SObject> records, List<ParentLink> links) {
        if (records != null && !records.isEmpty()) {
            new Insertion(records, links).run();
        }
    }

    private class Insertion {
        private final List<SObject> records;
        private final List<List<ParentLink>> parentLinksByChild;

        private Insertion(List<SObject> records, List<ParentLink> links) {
            this.records = records;
            this.parentLinksByChild = linksByChild(records.size(), links);
        }

        private void run() {
            Set<Integer> unpersisted = indicesOf(this.records);
            while (!unpersisted.isEmpty()) {
                List<Integer> layer = this.nextLayer(unpersisted);
                this.insertLayer(layer);
                unpersisted.removeAll(layer);
            }
        }

        private List<Integer> nextLayer(Set<Integer> unpersisted) {
            List<Integer> layer = new List<Integer>();
            for (Integer index : unpersisted) {
                if (this.parentsPersisted(index, unpersisted)) {
                    layer.add(index);
                }
            }
            return failIfEmpty(layer);
        }

        private Boolean parentsPersisted(Integer child, Set<Integer> unpersisted) {
            for (ParentLink link : this.parentLinksByChild[child]) {
                if (unpersisted.contains(link.parentIndex)) {
                    return false;
                }
            }
            return true;
        }

        private void insertLayer(List<Integer> indices) {
            List<SObject> layer = new List<SObject>();
            for (Integer index : indices) {
                this.pointAtParents(index);
                layer.add(this.records[index]);
            }
            insert layer;
        }

        private void pointAtParents(Integer child) {
            for (ParentLink link : this.parentLinksByChild[child]) {
                this.records[child].put(link.field, this.records[link.parentIndex].Id);
            }
        }
    }

    private static List<Integer> failIfEmpty(List<Integer> layer) {
        if (layer.isEmpty()) {
            throw new CyclicGraphException('record lookups form a cycle - no insert order works');
        }
        return layer;
    }

    private static List<List<ParentLink>> linksByChild(Integer recordCount, List<ParentLink> links) {
        List<List<ParentLink>> byChild = new List<List<ParentLink>>();
        for (Integer i = 0; i < recordCount; i++) {
            byChild.add(new List<ParentLink>());
        }
        for (ParentLink link : links == null ? new List<ParentLink>() : links) {
            byChild[link.childIndex].add(link);
        }
        return byChild;
    }

    private static Set<Integer> indicesOf(List<SObject> records) {
        Set<Integer> indices = new Set<Integer>();
        for (Integer i = 0; i < records.size(); i++) {
            indices.add(i);
        }
        return indices;
    }
}

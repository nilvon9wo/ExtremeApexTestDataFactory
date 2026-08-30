/**
 * Inserts a mixed-type set of records in the fewest DML statements: one `insert`
 * per dependency depth, shallowest-first, re-pointing each lookup to its parent's
 * fresh Id between depths.
 *
 * The engine can build a whole object graph structurally with no DML (this is
 * what `NEVER` produces today), record the pending parent -> child links as
 * {@link Edge}s, then hand the flat record list plus the edges here. A `Task`
 * with an `Account` parent and a `Contact` parent then costs 2 inserts, not 3;
 * a record with five parents of five types costs 2, not 6.
 *
 * Records are identified by their index in `records`: Apex `SObject` map and list
 * membership is value-based (two records with equal fields compare equal), so an
 * index is the only safe handle on a specific instance.
 */
@IsTest
public class XFTY_DepthBatchedInserter {

    /**
     * One pending lookup: `records[childIndex].get(lookupField)` should end up
     * pointing at `records[parentIndex]` - by its Id, or by `parentSourceField`
     * when the relationship is wired from another field (see
     * `XFTY_DummyDefaultRelationship`'s related-field form).
     */
    public class Edge {
        public final Integer childIndex;
        public final Integer parentIndex;
        public final SObjectField lookupField;
        public final SObjectField parentSourceField;

        public Edge(Integer childIndex, Integer parentIndex, SObjectField lookupField) {
            this(childIndex, parentIndex, lookupField, null);
        }

        public Edge(
                Integer childIndex,
                Integer parentIndex,
                SObjectField lookupField,
                SObjectField parentSourceField
        ) {
            this.childIndex = childIndex;
            this.parentIndex = parentIndex;
            this.lookupField = lookupField;
            this.parentSourceField = parentSourceField;
        }
    }

    /** Thrown when the lookups form a cycle - no single `insert` order works. */
    public class CyclicGraphException extends Exception {
    }

    /**
     * Insert every record in `records`, batched by dependency depth. `edges` may
     * be null or empty (then it is one `insert`). A null or empty `records` is a
     * no-op - zero DML statements.
     */
    public static void insertAll(List<SObject> records, List<Edge> edges) {
        if (records == null || records.isEmpty()) {
            return;
        }
        List<List<Edge>> edgesByChild = groupByChild(records.size(), edges);
        List<Integer> depthByIndex = computeDepths(records.size(), edgesByChild);
        Map<Integer, List<Integer>> indicesByDepth = groupByDepth(depthByIndex);

        List<Integer> depths = new List<Integer>(indicesByDepth.keySet());
        depths.sort();
        for (Integer depth : depths) {
            List<SObject> batch = new List<SObject>();
            for (Integer index : indicesByDepth.get(depth)) {
                repointParents(records, index, edgesByChild[index]);
                batch.add(records[index]);
            }
            insert batch;
        }
    }

    private static void repointParents(List<SObject> records, Integer childIndex, List<Edge> childEdges) {
        for (Edge edge : childEdges) {
            SObject parent = records[edge.parentIndex];
            Object parentValue = (edge.parentSourceField == null)
                    ? parent.Id
                    : parent.get(edge.parentSourceField);
            records[childIndex].put(edge.lookupField, parentValue);
        }
    }

    private static List<List<Edge>> groupByChild(Integer size, List<Edge> edges) {
        List<List<Edge>> byChild = new List<List<Edge>>();
        for (Integer i = 0; i < size; i++) {
            byChild.add(new List<Edge>());
        }
        if (edges != null) {
            for (Edge edge : edges) {
                byChild[edge.childIndex].add(edge);
            }
        }
        return byChild;
    }

    private static List<Integer> computeDepths(Integer size, List<List<Edge>> edgesByChild) {
        List<Integer> depth = new List<Integer>();
        List<Integer> state = new List<Integer>(); // 0 unvisited, 1 visiting, 2 done
        for (Integer i = 0; i < size; i++) {
            depth.add(null);
            state.add(0);
        }
        for (Integer i = 0; i < size; i++) {
            resolveDepth(i, edgesByChild, depth, state);
        }
        return depth;
    }

    private static Integer resolveDepth(
            Integer index,
            List<List<Edge>> edgesByChild,
            List<Integer> depth,
            List<Integer> state
    ) {
        if (state[index] == 2) {
            return depth[index];
        }
        if (state[index] == 1) {
            throw new CyclicGraphException(
                    'Cannot depth-batch records whose lookups form a cycle - insert one side first, or use NOW mode. '
                            + 'Reached record index ' + index + ' while it was still being resolved.'
            );
        }
        state[index] = 1;
        Integer deepestParent = -1;
        for (Edge edge : edgesByChild[index]) {
            Integer parentDepth = resolveDepth(edge.parentIndex, edgesByChild, depth, state);
            if (parentDepth > deepestParent) {
                deepestParent = parentDepth;
            }
        }
        depth[index] = deepestParent + 1;
        state[index] = 2;
        return depth[index];
    }

    private static Map<Integer, List<Integer>> groupByDepth(List<Integer> depthByIndex) {
        Map<Integer, List<Integer>> byDepth = new Map<Integer, List<Integer>>();
        for (Integer i = 0; i < depthByIndex.size(); i++) {
            Integer d = depthByIndex[i];
            if (!byDepth.containsKey(d)) {
                byDepth.put(d, new List<Integer>());
            }
            byDepth.get(d).add(i);
        }
        return byDepth;
    }
}

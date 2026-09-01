/**
 * A value that reads **up** the graph - a field on a record derived from one of
 * its generated descendants. It cannot be evaluated when the record is built,
 * because the descendant does not exist yet, so it is resolved in a pass over
 * the whole in-memory forest just before the depth-batched insert.
 *
 * That forest only exists under the `DEFERRED` insert mode (and `.depthBatched()`);
 * a Provider that carries one of these in any other mode throws. The resolved
 * value appears when `XFTY_DeferredInserter.flush()` runs.
 *
 * See docs/roadmap/descendant-value-reads.md.
 */
public interface XFTY_DeferredExpressionIntf {

    /** The value for `records[recordIndex]`'s field, read from its descendants via `graph`. */
    Object get(XFTY_DeferredGraph graph, Integer recordIndex);
}

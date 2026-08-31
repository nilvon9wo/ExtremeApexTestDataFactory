/**
 * Resolves the shared ancestors configured in the current test method, before
 * the main graph build, in one depth-batched pass per ancestor sub-graph:
 *
 * - **S0 collect.** Depth-first from the given ancestors, following each one's
 *   {@link XFTY_SharedAncestorProvider#masterTemplate} into any nested shared
 *   ancestors. Cycles throw; excessive depth warns. Produces a dependency order
 *   (deepest first) so every ancestor's shared parents are resolved before it.
 * - **S1 generate.** Each ancestor's {@link XFTY_SharedAncestorProvider#buildInMemory}
 *   generates its whole graph with no persistence - a flat ancestor is a single
 *   record, a deep one comes with its own parents.
 * - **S2 depth-batched persist.** The in-memory graph is inserted (or mock-Id'd,
 *   or left alone) one dependency layer at a time - the fewest `insert`
 *   statements. Already-resolved shared ancestors in the graph are anchors, not
 *   re-inserted.
 *
 * The resolver never branches on how an ancestor was configured - a
 * {@link XFTY_SharedAncestorProvider} answers for both. See
 * docs/use/shared-ancestors.md.
 */
@IsTest
public class XFTY_SharedAncestorResolver {

    private static final Integer DEPTH_WARN_THRESHOLD = 10;

    private final XFTY_DummySObjectProviderLookupIntf lookup;
    private final XFTY_InsertModeEnum mode;

    public XFTY_SharedAncestorResolver(
            XFTY_DummySObjectProviderLookupIntf lookup,
            XFTY_InsertModeEnum mode
    ) {
        this.lookup = lookup;
        this.mode = mode;
    }

    public void resolve(List<XFTY_SharedAncestor> ancestors) {
        Boolean owns = XFTY_SharedAncestor.enterPrePhase();
        try {
            for (XFTY_SharedAncestor ancestor : this.collectInDependencyOrder(ancestors)) {
                if (!ancestor.isResolved()) {
                    this.resolveOne(ancestor);
                }
            }
        } finally {
            if (owns) {
                XFTY_SharedAncestor.exitPrePhase();
            }
        }
    }

    // S0 -----------------------------------------------------------------------

    private List<XFTY_SharedAncestor> collectInDependencyOrder(List<XFTY_SharedAncestor> roots) {
        List<XFTY_SharedAncestor> ordered = new List<XFTY_SharedAncestor>();
        Set<String> done = new Set<String>();
        Set<String> onThePath = new Set<String>();
        for (XFTY_SharedAncestor root : roots) {
            this.visit(root, ordered, done, onThePath, 1);
        }
        return ordered;
    }

    private void visit(
            XFTY_SharedAncestor ancestor,
            List<XFTY_SharedAncestor> ordered,
            Set<String> done,
            Set<String> onThePath,
            Integer depth
    ) {
        String name = ancestor.getSharedName();
        if (done.contains(name)) {
            return;
        }
        if (ancestor.isResolved()) {
            // Pre-registered with put(name, record) - it is already a record, so its
            // own dependencies do not matter and it cannot be part of a live cycle.
            done.add(name);
            return;
        }
        if (onThePath.contains(name) || XFTY_SharedAncestor.isResolving(name)) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'Shared ancestors form a cycle involving "' + name + '". Break it by pre-registering '
                            + 'one side with XFTY_SharedAncestor.put("' + name + '", record).'
            );
        }
        if (depth > DEPTH_WARN_THRESHOLD) {
            System.debug(LoggingLevel.WARN,
                    'XFTY_SharedAncestor: shared-ancestor chain past ' + DEPTH_WARN_THRESHOLD + ' deep at "' + name + '".');
        }
        onThePath.add(name);
        for (XFTY_SharedAncestor nested : this.nestedSharedAncestorsOf(ancestor)) {
            this.visit(nested, ordered, done, onThePath, depth + 1);
        }
        onThePath.remove(name);
        done.add(name);
        ordered.add(ancestor);
    }

    private List<XFTY_SharedAncestor> nestedSharedAncestorsOf(XFTY_SharedAncestor ancestor) {
        XFTY_DummySObjectMasterTemplate masterTemplate = ancestor.source().masterTemplate(this.lookup);
        List<XFTY_DummyDefaultRelationshipIntf> relationships = new List<XFTY_DummyDefaultRelationshipIntf>();
        relationships.addAll(masterTemplate.requiredRelationshipBySObjectFieldMap.values());
        relationships.addAll(masterTemplate.optionalRelationshipBySObjectFieldMap.values());

        List<XFTY_SharedAncestor> nested = new List<XFTY_SharedAncestor>();
        for (XFTY_DummyDefaultRelationshipIntf relationship : relationships) {
            if (relationship instanceof XFTY_SharedAncestor) {
                nested.add((XFTY_SharedAncestor) relationship);
            }
        }
        return nested;
    }

    // S1 + S2 ----------------------------------------------------------------

    private void resolveOne(XFTY_SharedAncestor ancestor) {
        if (!ancestor.beginResolving()) {
            // Reached re-entrantly while its own generation is in flight - the
            // outer resolveOne will finish it.
            return;
        }
        try {
            this.buildAndPersist(ancestor);
        } finally {
            ancestor.endResolving();
        }
    }

    private void buildAndPersist(XFTY_SharedAncestor ancestor) {
        XFTY_SharedAncestorProvider source = ancestor.source();
        XFTY_DummySObjectBundle bundle = source.buildInMemory(this.lookup);

        XFTY_DeferredInsertBuffer buffer = new XFTY_DeferredInsertBuffer();
        buffer.add(bundle);
        buffer.resolveAll(this.mode);

        SObject record = bundle.getList(source.primaryField(this.lookup))[0];
        ancestor.acceptResolved(record, bundle, this.mode == XFTY_InsertModeEnum.NOW);
    }
}

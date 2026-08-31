/**
 * Resolves the **deep** shared ancestors a generation run will reach - those
 * whose Provider pulls in relationships of its own - before the main graph
 * build, in one depth-batched pass per ancestor sub-graph:
 *
 * - **S0 collect.** Depth-first from the given ancestors, following each one's
 *   Provider's Master Template into any nested shared ancestors. Cycles throw;
 *   excessive depth warns. Produces a dependency order (deepest first) so every
 *   ancestor's shared parents are resolved before it.
 * - **S1 generate.** Each ancestor's Provider `createBundle` in `NEVER` mode,
 *   `REQUIRED` inclusivity - its own non-shared parents come with it, in memory.
 * - **S2 depth-batched persist.** The ancestor's in-memory graph is inserted
 *   (or mock-Id'd, or left alone) one dependency layer at a time - the fewest
 *   `insert` statements. Already-resolved shared ancestors in the graph are
 *   anchors, not re-inserted.
 *
 * Flat shared ancestors (no relationships of their own) are not handled here -
 * they resolve inline with their siblings. See docs/use/shared-ancestors.md.
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
        XFTY_DummySObjectMasterTemplate masterTemplate = this.masterTemplateOf(ancestor);
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
        XFTY_DummySObjectBundle bundle = this.buildInMemory(ancestor);

        XFTY_DeferredInsertBuffer buffer = new XFTY_DeferredInsertBuffer();
        buffer.add(bundle);
        buffer.resolveAll(this.mode);

        SObject record = bundle.getList(this.primaryFieldOf(ancestor))[0];
        ancestor.acceptResolved(record, bundle, this.mode == XFTY_InsertModeEnum.NOW);
    }

    /** S1: the ancestor's whole graph, generated with no persistence. */
    private XFTY_DummySObjectBundle buildInMemory(XFTY_SharedAncestor ancestor) {
        XFTY_DummySObjectProvider configured = ancestor.getConfiguredProvider();
        if (configured != null) {
            // The developer handed over a fully-configured Provider - values,
            // relationship control, path values and all. Run it structurally.
            return configured.buildStructurally();
        }
        XFTY_GenerationContext structuralContext = new XFTY_GenerationContext(
                this.lookup, XFTY_InsertModeEnum.NEVER, XFTY_InsertInclusivityEnum.REQUIRED
        );
        return this.providerFor(ancestor).createBundle(
                structuralContext,
                new List<SObject>{ this.templateFor(ancestor).clone(true, true, true, true) }
        );
    }

    private XFTY_DummySObjectMasterTemplate masterTemplateOf(XFTY_SharedAncestor ancestor) {
        XFTY_DummySObjectProvider configured = ancestor.getConfiguredProvider();
        return (configured != null)
                ? configured.effectiveMasterTemplate()
                : this.providerFor(ancestor).getMasterTemplate();
    }

    private SObjectField primaryFieldOf(XFTY_SharedAncestor ancestor) {
        XFTY_DummySObjectProvider configured = ancestor.getConfiguredProvider();
        return (configured != null)
                ? configured.primaryTargetField()
                : this.providerFor(ancestor).getPrimaryTargetField();
    }

    private XFTY_DummySobjectProviderIntf providerFor(XFTY_SharedAncestor ancestor) {
        return this.lookup.get(ancestor.resolveLookupKey(this.lookup));
    }

    private SObject templateFor(XFTY_SharedAncestor ancestor) {
        SObject template = ancestor.getOverrideTemplate();
        return (template != null)
                ? template
                : ancestor.resolveLookupKey(this.lookup).getSObjectType().newSObject();
    }
}

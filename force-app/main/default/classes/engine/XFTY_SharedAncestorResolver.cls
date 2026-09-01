/**
 * Resolves the shared ancestors configured in the current test method, before
 * the main graph build: nested shared ancestors first (S0), each built in memory
 * (S1), then persisted one dependency layer at a time (S2 - the fewest `insert`
 * statements). Cycles throw; chains past ten deep warn.
 *
 * Works from {@link XFTY_SharedAncestorProvider} - the single recipe type - so it
 * never branches on how an ancestor was configured.
 */
@IsTest
public class XFTY_SharedAncestorResolver {

    private static final Integer DEEP_CHAIN_WARN_AT = 10;

    private static Boolean running = false;
    private static final Set<String> inProgress = new Set<String>();

    private final XFTY_DummySObjectProviderLookupIntf lookup;
    private final XFTY_InsertModeEnum mode;

    /** `mode` is the triggering call's insert mode; `DEFERRED` / `RELATED_ONLY` resolve eagerly, as `NOW`. */
    public XFTY_SharedAncestorResolver(XFTY_DummySObjectProviderLookupIntf lookup, XFTY_InsertModeEnum mode) {
        this.lookup = lookup;
        this.mode = eager(mode);
    }

    /**
     * Every shared ancestor configured this test method, resolved against the
     * triggering call's mode. A no-op while resolution is already running (a
     * nested `supplyBundle()` from a put-Provider).
     */
    public static void resolveAllConfigured(XFTY_DummySObjectProviderLookupIntf lookup, XFTY_InsertModeEnum callMode) {
        if (running) {
            return;
        }
        applyLookupDefaults(lookup);
        if (XFTY_SharedAncestor.isManualResolutionOnly()) {
            return;   // lightweight ancestors resolve on-demand; heavy ones the test resolves up front
        }
        List<XFTY_SharedAncestor> configured = XFTY_SharedAncestor.configuredUnresolved();
        if (!configured.isEmpty()) {
            new XFTY_SharedAncestorResolver(lookup, callMode).resolve(configured);
        }
    }

    /**
     * Let a lookup that implements {@link XFTY_SharedAncestorDefaultsIntf}
     * register its shared-ancestor defaults - so a Provider that references one
     * works without the test registering it. `putIfAbsent` in the callback means
     * a test's own registration still wins.
     */
    public static void applyLookupDefaults(XFTY_DummySObjectProviderLookupIntf lookup) {
        if (lookup instanceof XFTY_SharedAncestorDefaultsIntf) {
            ((XFTY_SharedAncestorDefaultsIntf) lookup).registerSharedAncestorDefaults();
        }
    }

    public void resolve(List<XFTY_SharedAncestor> ancestors) {
        Boolean owns = !running;
        running = true;
        try {
            for (XFTY_SharedAncestor ancestor : this.inDependencyOrder(ancestors)) {
                if (!ancestor.isResolved()) {
                    this.resolveOne(ancestor);
                }
            }
        } finally {
            if (owns) {
                running = false;
            }
        }
    }

    // S0 - collect deepest-first ------------------------------------------

    private List<XFTY_SharedAncestor> inDependencyOrder(List<XFTY_SharedAncestor> roots) {
        List<XFTY_SharedAncestor> ordered = new List<XFTY_SharedAncestor>();
        Set<String> done = new Set<String>();
        Set<String> onThePath = new Set<String>();
        for (XFTY_SharedAncestor root : roots) {
            this.visit(root, ordered, done, onThePath, 1);
        }
        return ordered;
    }

    private void visit(
            XFTY_SharedAncestor ancestor, List<XFTY_SharedAncestor> ordered,
            Set<String> done, Set<String> onThePath, Integer depth
    ) {
        String name = ancestor.getSharedName();
        if (done.contains(name)) {
            return;
        }
        if (ancestor.isResolved()) {
            done.add(name);   // pre-registered with put(name, record) - cannot be part of a live cycle
            return;
        }
        if (onThePath.contains(name) || inProgress.contains(name)) {
            throw cycle(name);
        }
        if (depth > DEEP_CHAIN_WARN_AT) {
            System.debug(LoggingLevel.WARN,
                    'XFTY_SharedAncestor: chain past ' + DEEP_CHAIN_WARN_AT + ' deep at "' + name + '".');
        }
        onThePath.add(name);
        for (XFTY_SharedAncestor nested : this.nestedOf(ancestor)) {
            this.visit(nested, ordered, done, onThePath, depth + 1);
        }
        onThePath.remove(name);
        done.add(name);
        ordered.add(ancestor);
    }

    private List<XFTY_SharedAncestor> nestedOf(XFTY_SharedAncestor ancestor) {
        XFTY_DummySObjectMasterTemplate template = ancestor.source().masterTemplate(this.lookup);
        List<XFTY_DummyDefaultRelationshipIntf> relationships = new List<XFTY_DummyDefaultRelationshipIntf>();
        relationships.addAll(template.requiredRelationshipBySObjectFieldMap.values());
        relationships.addAll(template.optionalRelationshipBySObjectFieldMap.values());

        List<XFTY_SharedAncestor> nested = new List<XFTY_SharedAncestor>();
        for (XFTY_DummyDefaultRelationshipIntf relationship : relationships) {
            if (relationship instanceof XFTY_SharedAncestor) {
                nested.add((XFTY_SharedAncestor) relationship);
            }
        }
        return nested;
    }

    // S1 generate + S2 depth-batched persist -----------------------------

    private void resolveOne(XFTY_SharedAncestor ancestor) {
        String name = ancestor.getSharedName();
        if (!inProgress.add(name)) {
            return;   // reached re-entrantly; the outer resolveOne finishes it
        }
        try {
            this.buildAndPersist(ancestor);
        } finally {
            inProgress.remove(name);
        }
    }

    private void buildAndPersist(XFTY_SharedAncestor ancestor) {
        XFTY_SharedAncestorProvider source = ancestor.source();
        XFTY_DummySObjectBundle graph = source.buildInMemory(this.lookup);

        XFTY_DeferredInsertBuffer buffer = new XFTY_DeferredInsertBuffer();
        buffer.add(graph);
        buffer.resolveAll(this.mode);

        SObject record = graph.getList(source.primaryField(this.lookup))[0];
        ancestor.acceptResolved(record, graph, this.mode == XFTY_InsertModeEnum.NOW);
    }

    private static XFTY_InsertModeEnum eager(XFTY_InsertModeEnum callMode) {
        Boolean resolveEagerly = callMode == null
                || callMode == XFTY_InsertModeEnum.DEFERRED
                || callMode == XFTY_InsertModeEnum.RELATED_ONLY;
        return resolveEagerly ? XFTY_InsertModeEnum.NOW : callMode;
    }

    private static XFTY_DummySObjectFtyProviderException cycle(String name) {
        return new XFTY_DummySObjectFtyProviderException(
                'Shared ancestors form a cycle involving "' + name + '". Break it by pre-registering '
                        + 'one side with XFTY_SharedAncestor.put("' + name + '", record).'
        );
    }
}

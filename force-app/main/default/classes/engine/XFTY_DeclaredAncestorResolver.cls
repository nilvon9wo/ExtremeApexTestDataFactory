/**
 * Resolves the **declared** shared ancestors a test `require(...)`d, before the
 * main graph build, in one depth-batched pass per ancestor:
 *
 * - **S0 collect.** Depth-first from the required names, following each declared
 *   ancestor's Provider's Master Template into any nested *declared* shared
 *   ancestors. Cycles throw; excessive depth warns. Produces a dependency order
 *   (deepest first) so every ancestor's declared parents are resolved before it.
 * - **S1 generate.** Each ancestor's Provider `createBundle` in `NEVER` mode,
 *   `REQUIRED` inclusivity - its own non-shared parents come with it, in memory.
 * - **S2 depth-batched persist.** The ancestor's in-memory graph is inserted
 *   (or mock-Id'd, or left alone) one dependency layer at a time - the fewest
 *   `insert` statements. Already-resolved shared ancestors in the graph are
 *   anchors, not re-inserted.
 *
 * On-demand shared ancestors are not handled here - they resolve inline with
 * their siblings. See docs/roadmap/shared-ancestors.md.
 */
@IsTest
public class XFTY_DeclaredAncestorResolver {

    private static final Integer DEPTH_WARN_THRESHOLD = 10;

    private final XFTY_DummySObjectProviderLookupIntf lookup;
    private final XFTY_InsertModeEnum mode;

    public XFTY_DeclaredAncestorResolver(
            XFTY_DummySObjectProviderLookupIntf lookup,
            XFTY_InsertModeEnum mode
    ) {
        this.lookup = lookup;
        this.mode = mode;
    }

    public void resolve(List<XFTY_SharedAncestor> requiredAncestors) {
        for (XFTY_SharedAncestor ancestor : this.collectInDependencyOrder(requiredAncestors)) {
            if (!ancestor.isResolved()) {
                this.resolveOne(ancestor);
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
        if (onThePath.contains(name)) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'Declared shared ancestors form a cycle involving "' + name + '". Break it by pre-registering '
                            + 'one side with XFTY_SharedAncestor.put("' + name + '", record).'
            );
        }
        if (depth > DEPTH_WARN_THRESHOLD) {
            System.debug(LoggingLevel.WARN,
                    'XFTY_SharedAncestor: declared chain past ' + DEPTH_WARN_THRESHOLD + ' deep at "' + name + '".');
        }
        onThePath.add(name);
        for (XFTY_SharedAncestor nested : this.nestedDeclaredAncestorsOf(ancestor)) {
            this.visit(nested, ordered, done, onThePath, depth + 1);
        }
        onThePath.remove(name);
        done.add(name);
        // Reaching it through a required ancestor's own graph makes it required too.
        XFTY_SharedAncestor.require(name);
        ordered.add(ancestor);
    }

    private List<XFTY_SharedAncestor> nestedDeclaredAncestorsOf(XFTY_SharedAncestor ancestor) {
        XFTY_DummySObjectMasterTemplate masterTemplate = this.providerFor(ancestor).getMasterTemplate();
        List<XFTY_DummyDefaultRelationshipIntf> relationships = new List<XFTY_DummyDefaultRelationshipIntf>();
        relationships.addAll(masterTemplate.requiredRelationshipBySObjectFieldMap.values());
        relationships.addAll(masterTemplate.optionalRelationshipBySObjectFieldMap.values());

        List<XFTY_SharedAncestor> nested = new List<XFTY_SharedAncestor>();
        for (XFTY_DummyDefaultRelationshipIntf relationship : relationships) {
            if (relationship instanceof XFTY_SharedAncestor) {
                XFTY_SharedAncestor sharedRelationship = (XFTY_SharedAncestor) relationship;
                if (sharedRelationship.getKind() == XFTY_SharedAncestor.Kind.DECLARED) {
                    nested.add(sharedRelationship);
                }
            }
        }
        return nested;
    }

    // S1 + S2 ----------------------------------------------------------------

    private void resolveOne(XFTY_SharedAncestor ancestor) {
        XFTY_DummySobjectProviderIntf provider = this.providerFor(ancestor);
        XFTY_GenerationContext structuralContext = new XFTY_GenerationContext(
                this.lookup, XFTY_InsertModeEnum.NEVER, XFTY_InsertInclusivityEnum.REQUIRED
        );
        XFTY_DummySObjectBundle bundle = provider.createBundle(
                structuralContext,
                new List<SObject>{ this.templateFor(ancestor).clone(true, true, true, true) }
        );

        XFTY_DeferredInsertBuffer buffer = new XFTY_DeferredInsertBuffer();
        buffer.add(bundle);
        buffer.resolveAll(this.mode);

        SObject record = bundle.getList(provider.getPrimaryTargetField())[0];
        ancestor.acceptResolved(record, bundle, this.mode == XFTY_InsertModeEnum.NOW);
    }

    private XFTY_DummySobjectProviderIntf providerFor(XFTY_SharedAncestor ancestor) {
        return this.lookup.get(ancestor.resolveLookupKey(this.lookup));
    }

    private SObject templateFor(XFTY_SharedAncestor ancestor) {
        SObject template = ancestor.getOverrideTemplate();
        if (template == null) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'Declared shared ancestor "' + ancestor.getSharedName() + '" was never configured. Call '
                            + 'XFTY_SharedAncestor.declared("' + ancestor.getSharedName() + '").of(new SomeSObject()).'
            );
        }
        return template;
    }
}

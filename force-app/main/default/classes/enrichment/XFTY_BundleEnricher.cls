/**
 * Re-expresses a generated graph in the shape `record.put(...)` rejects, so code
 * under test reads relationships and read-only fields straight off the SObject.
 *
 * `enrichPosition` walks the graph deepest-first via the call stack: at each
 * bundle position it collects the enriched parents and child subqueries below it,
 * then does one `XFTY_SObjectInjector` round-trip. Ancestors carry their
 * one-level inverse child; downward children carry their own ancestors and, to
 * `childDepth`, their own nested children.
 *
 * Returns the enriched target records (`getList(field)`) as new instances - the
 * originals are untouched. Entry: `bundle.inject(field, config)` / `injectAll`.
 *
 * `graftAncestors` / `graftChildren` are **mutually recursive** through
 * `enrichPosition`, so they stay in one class - splitting them would only give
 * each a back-reference to re-enter the recursion. The parts that do *not*
 * recurse are their own classes: `XFTY_EnrichmentTarget`,
 * `XFTY_EnrichmentSelection`, `XFTY_InverseAlignment`, `XFTY_ForcedValues`,
 * `XFTY_QueryableShapeValidator`.
 */
@IsTest
public class XFTY_BundleEnricher {

    private final XFTY_DummySObjectBundle entryBundle;
    private final SObjectField entryField;
    private final XFTY_InjectConfig config;
    private final XFTY_EnrichmentSelection selection;
    private final XFTY_ForcedValues forcedValues;

    private XFTY_BundleEnricher(XFTY_DummySObjectBundle bundle, SObjectField field, XFTY_InjectConfig config) {
        XFTY_QueryableShapeValidator.validate(config);
        this.entryBundle = bundle;
        this.entryField = field;
        this.config = config;
        this.selection = new XFTY_EnrichmentSelection(config);
        this.forcedValues = new XFTY_ForcedValues(config);
    }

    public static List<SObject> enrich(
            XFTY_DummySObjectBundle bundle,
            SObjectField field,
            XFTY_InjectConfig config
    ) {
        return new XFTY_BundleEnricher(bundle, field, config).run();
    }

    /** `enrich` with `XFTY_InjectConfig.everything()`; throws when the graph has nothing to inject. */
    public static List<SObject> enrichEverything(XFTY_DummySObjectBundle bundle, SObjectField field) {
        if (!XFTY_EnrichmentTarget.locate(bundle, field).hasAnythingToInject()) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'injectAll(' + field + '): the graph has no generated ancestor or child collection to inject. '
                            + 'Generate related records, or use inject(field, config) with explicit values.'
            );
        }
        return enrich(bundle, field, XFTY_InjectConfig.everything());
    }

    private List<SObject> run() {
        XFTY_GovernorBudget budget = new XFTY_GovernorBudget();
        XFTY_EnrichmentTarget target = XFTY_EnrichmentTarget.locate(this.entryBundle, this.entryField);
        List<SObject> result = this.enrichPosition(this.rootPosition(target));
        this.forcedValues.assertEveryPathWasReached();
        budget.warnIfExpensive();
        return result;
    }

    private List<SObject> enrichPosition(Position pos) {
        if (pos.records == null || pos.records.isEmpty()) {
            return pos.records;
        }
        XFTY_SObjectInjector injector = XFTY_SObjectInjector.inject(pos.records);
        this.graftAncestors(injector, pos);
        this.graftInverse(injector, pos);
        this.graftChildren(injector, pos);
        this.applyForcedValues(injector, pos);
        return injector.result();
    }

    private void applyForcedValues(XFTY_SObjectInjector injector, Position pos) {
        Integer rowCount = pos.records.size();
        if (pos.isRoot) {
            this.forcedValues.applyRecordValues(injector, rowCount);
        }
        if (pos.pathFromEntry != null && !pos.pathFromEntry.isEmpty()) {
            this.forcedValues.applyAncestorValues(injector, pos.pathFromEntry, rowCount);
        }
        if (pos.childPathFromEntry != null && !pos.childPathFromEntry.isEmpty()) {
            this.forcedValues.applyChildValues(injector, pos.childPathFromEntry, rowCount);
        }
    }

    private void graftAncestors(XFTY_SObjectInjector injector, Position pos) {
        if (pos.subBundle == null || pos.parentDepthLeft <= 0) {
            return;
        }
        for (SObjectField relationshipField : materialised(pos.subBundle.relationshipFields())) {
            this.graftAncestor(injector, pos, relationshipField);
        }
    }

    private void graftAncestor(XFTY_SObjectInjector injector, Position pos, SObjectField relationshipField) {
        if (!this.selection.wantsAncestor(ancestorPath(pos, relationshipField))) {
            return;
        }
        List<SObject> parents = pos.subBundle.getList(relationshipField);
        if (parents == null) {
            return;
        }
        injector.relationship(
                XFTY_InjectionPathResolver.parentRelationshipName(relationshipField),
                this.enrichPosition(this.ancestorPosition(pos, relationshipField, parents))
        );
    }

    private void graftInverse(XFTY_SObjectInjector injector, Position pos) {
        if (pos.inverseChildField == null) {
            return;
        }
        injector.childRelationship(
                XFTY_InjectionPathResolver.childRelationshipName(pos.positionType(), pos.inverseChildField),
                pos.inverseChildrenPerRow
        );
    }

    private void graftChildren(XFTY_SObjectInjector injector, Position pos) {
        if (pos.subBundle == null || pos.childDepthLeft <= 0) {
            return;
        }
        for (SObjectField childField : this.selection.childFieldsOn(pos.subBundle, childPathOf(pos))) {
            injector.childRelationship(
                    XFTY_InjectionPathResolver.childRelationshipName(pos.positionType(), childField),
                    this.childrenPerRow(pos, childField)
            );
        }
    }

    private List<List<SObject>> childrenPerRow(Position pos, SObjectField childField) {
        List<List<SObject>> perRow = emptyListsFor(pos.records.size());
        for (XFTY_DummySObjectBundle.ChildEntry entry : pos.subBundle.childEntries(childField)) {
            this.enrichEntryInto(perRow, this.childrenPosition(pos, entry, childField), entry);
        }
        return perRow;
    }

    private void enrichEntryInto(
            List<List<SObject>> perRow,
            Position childPos,
            XFTY_DummySObjectBundle.ChildEntry entry
    ) {
        if (childPos.records == null || childPos.records.isEmpty()) {
            return;
        }
        List<SObject> enriched = this.enrichPosition(childPos);
        for (Integer childRow = 0; childRow < enriched.size(); childRow++) {
            perRow[entry.parentRowByChildRow[childRow]].add(enriched[childRow]);
        }
    }

    private Position rootPosition(XFTY_EnrichmentTarget target) {
        Position root = new Position(target.subBundle, target.records);
        root.pathFromEntry = new List<SObjectField>();
        root.childPathFromEntry = new List<SObjectField>();
        root.parentDepthLeft = this.config.parentDepthLimit;
        root.childDepthLeft = this.config.childDepthLimit;
        root.isRoot = true;
        if (target.isGeneratedAncestor) {
            root.carryInverse(this.entryField, XFTY_InverseAlignment.childrenPerParent(
                    target.records, this.entryBundle.primaryRecords(), this.entryField));
        }
        return root;
    }

    private Position ancestorPosition(Position pos, SObjectField relationshipField, List<SObject> parents) {
        Position up = new Position(pos.subBundle.getBundle(relationshipField), parents);
        up.pathFromEntry = ancestorPath(pos, relationshipField);
        up.parentDepthLeft = pos.parentDepthLeft - 1;
        if (this.selection.wantsInverse(relationshipField)) {
            up.carryInverse(relationshipField, XFTY_InverseAlignment.childrenPerParent(
                    parents, pos.records, relationshipField));
        }
        return up;
    }

    private Position childrenPosition(Position pos, XFTY_DummySObjectBundle.ChildEntry entry, SObjectField childField) {
        Position down = new Position(entry.bundle, entry.bundle.primaryRecords());
        down.parentDepthLeft = this.config.parentDepthLimit;
        down.childDepthLeft = pos.childDepthLeft - 1;
        down.childPathFromEntry = append(childPathOf(pos), childField);
        return down;
    }

    private static List<SObjectField> childPathOf(Position pos) {
        return (pos.childPathFromEntry == null)
                ? new List<SObjectField>()
                : pos.childPathFromEntry;
    }

    private static List<SObjectField> ancestorPath(Position pos, SObjectField relationshipField) {
        return (pos.pathFromEntry == null)
                ? null
                : append(pos.pathFromEntry, relationshipField);
    }

    private static List<SObjectField> append(List<SObjectField> path, SObjectField extra) {
        List<SObjectField> longer = new List<SObjectField>(path);
        longer.add(extra);
        return longer;
    }

    private static List<List<SObject>> emptyListsFor(Integer size) {
        List<List<SObject>> lists = new List<List<SObject>>();
        for (Integer i = 0; i < size; i++) {
            lists.add(new List<SObject>());
        }
        return lists;
    }

    private static Set<SObjectField> materialised(Set<SObjectField> keySet) {
        Set<SObjectField> real = new Set<SObjectField>();
        real.addAll(keySet);
        return real;
    }

    /**
     * One frame of the recursive walk. Mutable, but populated only by
     * `XFTY_BundleEnricher`'s three `*Position` methods; every other method reads.
     */
    private class Position {
        private final XFTY_DummySObjectBundle subBundle;
        private final List<SObject> records;
        private List<SObjectField> pathFromEntry;         // null once the walk turns downward
        private List<SObjectField> childPathFromEntry;    // the child hops walked so far; null on an ancestor
        private Integer parentDepthLeft = 0;
        private Integer childDepthLeft = 0;
        private Boolean isRoot = false;
        private SObjectField inverseChildField;
        private List<List<SObject>> inverseChildrenPerRow;

        private Position(XFTY_DummySObjectBundle subBundle, List<SObject> records) {
            this.subBundle = subBundle;
            this.records = records;
        }

        private void carryInverse(SObjectField childField, List<List<SObject>> perRow) {
            this.inverseChildField = childField;
            this.inverseChildrenPerRow = perRow;
        }

        private SObjectType positionType() {
            return (this.records == null || this.records.isEmpty())
                    ? null
                    : this.records[0].getSObjectType();
        }
    }
}

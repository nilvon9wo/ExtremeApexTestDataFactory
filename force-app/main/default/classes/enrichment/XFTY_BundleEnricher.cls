/**
 * Re-expresses a generated graph in the shape `record.put(...)` rejects, so code
 * under test reads relationships and read-only fields straight off the SObject.
 *
 * A single recursive unit (`enrichPosition`) walks the graph deepest-first via
 * the call stack: at each bundle position it collects the enriched parents and
 * child subqueries below it, then does **one** `XFTY_SObjectInjector` round-trip.
 * Ancestors carry their one-level inverse child; downward children carry their
 * own ancestors and, to `childDepth`, their own nested children.
 *
 * Returns the enriched **target records** (`getList(field)`) as new instances -
 * the originals are untouched. Entry: `bundle.inject(field, config)` /
 * `injectAll(field)`.
 */
@IsTest
public class XFTY_BundleEnricher {

    private final XFTY_DummySObjectBundle entryBundle;
    private final SObjectField entryField;
    private final XFTY_InjectConfig config;
    private final XFTY_EnrichmentSelection selection;

    private XFTY_BundleEnricher(XFTY_DummySObjectBundle bundle, SObjectField field, XFTY_InjectConfig config) {
        XFTY_QueryableShapeValidator.validate(config);
        this.entryBundle = bundle;
        this.entryField = field;
        this.config = config;
        this.selection = new XFTY_EnrichmentSelection(config);
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
        if (!hasAnythingToInject(bundle, field)) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'injectAll(' + field + '): the graph has no generated ancestor or child collection to inject. '
                            + 'Generate related records, or use inject(field, config) with explicit values.'
            );
        }
        return enrich(bundle, field, XFTY_InjectConfig.everything());
    }

    /** True when the graph has any generated ancestor or child collection reachable from `field`. */
    public static Boolean hasAnythingToInject(XFTY_DummySObjectBundle bundle, SObjectField field) {
        Target target = locate(bundle, field);
        Boolean hasParents = target.subBundle != null && !target.subBundle.relationshipFields().isEmpty();
        Boolean hasChildren = (target.subBundle != null && !target.subBundle.childRelationshipFields().isEmpty())
                || target.isGeneratedAncestor;
        return hasParents || hasChildren;
    }

    private List<SObject> run() {
        XFTY_GovernorBudget budget = new XFTY_GovernorBudget();
        Target target = locate(this.entryBundle, this.entryField);
        Position root = new Position(target.subBundle, target.records);
        root.pathFromEntry = new List<SObjectField>();
        root.parentDepthLeft = this.config.parentDepthLimit;
        root.childDepthLeft = this.config.childDepthLimit;
        root.isRoot = true;
        if (target.isGeneratedAncestor) {
            root.inverseChildField = this.entryField;
            root.inverseChildrenPerRow =
                    inverseAlign(target.records, this.entryBundle.primaryRecords(), this.entryField);
        }
        List<SObject> result = this.enrichPosition(root);
        budget.warnIfExpensive();
        return result;
    }

    // Entry location ------------------------------------------------------

    private class Target {
        private final List<SObject> records;
        private final XFTY_DummySObjectBundle subBundle;
        private final Boolean isGeneratedAncestor;

        private Target(List<SObject> records, XFTY_DummySObjectBundle subBundle, Boolean isGeneratedAncestor) {
            this.records = records;
            this.subBundle = subBundle;
            this.isGeneratedAncestor = isGeneratedAncestor;
        }
    }

    private static Target locate(XFTY_DummySObjectBundle bundle, SObjectField field) {
        if (field == bundle.primaryTargetField) {
            return new Target(bundle.primaryRecords(), bundle, false);
        }
        if (materialised(bundle.relationshipFields()).contains(field)) {
            return new Target(bundle.getList(field), bundle.getBundle(field), true);
        }
        if (materialised(bundle.childRelationshipFields()).contains(field)) {
            return new Target(bundle.getChildList(field), bundle.getChildBundle(field), false);
        }
        throw new XFTY_DummySObjectFtyProviderException(
                'inject: ' + field + ' is not this bundle\'s primary field, a generated ancestor field '
                        + bundle.relationshipFields() + ', or a child field ' + bundle.childRelationshipFields() + '.'
        );
    }

    // The recursive unit -----------------------------------------------

    private class Position {
        private final XFTY_DummySObjectBundle subBundle;
        private final List<SObject> records;
        private List<SObjectField> pathFromEntry;    // null once the walk turns downward
        private Integer parentDepthLeft = 0;
        private Integer childDepthLeft = 0;
        private Boolean isRoot = false;
        private SObjectField inverseChildField;
        private List<List<SObject>> inverseChildrenPerRow;

        private Position(XFTY_DummySObjectBundle subBundle, List<SObject> records) {
            this.subBundle = subBundle;
            this.records = records;
        }

        private SObjectType positionType() {
            return (this.records == null || this.records.isEmpty())
                    ? null
                    : this.records[0].getSObjectType();
        }
    }

    private List<SObject> enrichPosition(Position pos) {
        if (pos.records == null || pos.records.isEmpty()) {
            return pos.records;
        }
        XFTY_SObjectInjector injector = XFTY_SObjectInjector.inject(pos.records);
        this.graftAncestors(injector, pos);
        this.graftInverse(injector, pos);
        this.graftChildren(injector, pos);
        this.graftValues(injector, pos);
        return injector.result();
    }

    private void graftAncestors(XFTY_SObjectInjector injector, Position pos) {
        if (pos.subBundle == null || pos.parentDepthLeft <= 0) {
            return;
        }
        for (SObjectField relField : materialised(pos.subBundle.relationshipFields())) {
            List<SObjectField> childPath = (pos.pathFromEntry == null)
                    ? null
                    : append(pos.pathFromEntry, relField);
            if (!this.selection.wantsAncestor(childPath)) {
                continue;
            }
            List<SObject> parents = pos.subBundle.getList(relField);
            if (parents == null) {
                continue;
            }
            Position up = new Position(pos.subBundle.getBundle(relField), parents);
            up.pathFromEntry = childPath;
            up.parentDepthLeft = pos.parentDepthLeft - 1;
            if (this.selection.wantsInverse(relField)) {
                up.inverseChildField = relField;
                up.inverseChildrenPerRow = inverseAlign(parents, pos.records, relField);
            }
            injector.relationship(
                    XFTY_InjectionPathResolver.parentRelationshipName(relField),
                    this.enrichPosition(up)
            );
        }
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
        for (SObjectField childField : this.selection.childFieldsOn(pos.subBundle, pos.isRoot)) {
            injector.childRelationship(
                    XFTY_InjectionPathResolver.childRelationshipName(pos.positionType(), childField),
                    this.childCollectionPerRow(pos, childField)
            );
        }
    }

    private List<List<SObject>> childCollectionPerRow(Position pos, SObjectField childField) {
        List<List<SObject>> perRow = new List<List<SObject>>();
        for (Integer row = 0; row < pos.records.size(); row++) {
            perRow.add(new List<SObject>());
        }
        for (XFTY_DummySObjectBundle.ChildEntry entry : pos.subBundle.childEntries(childField)) {
            List<SObject> entryChildren = entry.bundle.primaryRecords();
            if (entryChildren == null || entryChildren.isEmpty()) {
                continue;
            }
            Position down = new Position(entry.bundle, entryChildren);
            down.parentDepthLeft = this.config.parentDepthLimit;
            down.childDepthLeft = pos.childDepthLeft - 1;
            List<SObject> enrichedChildren = this.enrichPosition(down);
            for (Integer childRow = 0; childRow < enrichedChildren.size(); childRow++) {
                perRow[entry.parentRowByChildRow[childRow]].add(enrichedChildren[childRow]);
            }
        }
        return perRow;
    }

    private void graftValues(XFTY_SObjectInjector injector, Position pos) {
        if (pos.isRoot) {
            for (SObjectField valued : this.config.onRecordValues.keySet()) {
                injector.value(valued, resolved(this.config.onRecordValues.get(valued)));
            }
        }
        if (pos.pathFromEntry == null) {
            return;
        }
        String hereKey = XFTY_EnrichmentSelection.keyOf(pos.pathFromEntry);
        for (XFTY_InjectConfig.AncestorValue ancestorValue : this.config.ancestorValues) {
            if (XFTY_EnrichmentSelection.keyOf(ancestorValue.relationshipPrefix()) == hereKey) {
                injector.value(ancestorValue.targetField(), resolved(ancestorValue.value));
            }
        }
    }

    // Helpers --------------------------------------------------------

    /** For each parent, the records among `children` whose FK points at it - by Id, else the 1:1 position. */
    private static List<List<SObject>> inverseAlign(
            List<SObject> parents,
            List<SObject> children,
            SObjectField relationshipField
    ) {
        List<List<SObject>> perParent = new List<List<SObject>>();
        for (Integer p = 0; p < parents.size(); p++) {
            Object parentId = (parents[p] == null) ? null : parents[p].get('Id');
            List<SObject> matches = (parentId == null)
                    ? positionalFallback(children, p)
                    : childrenPointingAt(children, relationshipField, parentId);
            perParent.add(matches);
        }
        return perParent;
    }

    private static List<SObject> childrenPointingAt(List<SObject> children, SObjectField relationshipField, Object parentId) {
        List<SObject> matches = new List<SObject>();
        for (SObject child : children) {
            if (child != null && child.get(relationshipField) == parentId) {
                matches.add(child);
            }
        }
        return matches;
    }

    private static List<SObject> positionalFallback(List<SObject> children, Integer parentRow) {
        return (parentRow < children.size())
                ? new List<SObject>{ children[parentRow] }
                : new List<SObject>();
    }

    private static Object resolved(Object value) {
        return (value instanceof XFTY_ValueExpressionIntf)
                ? ((XFTY_ValueExpressionIntf) value).get()
                : value;
    }

    private static List<SObjectField> append(List<SObjectField> path, SObjectField extra) {
        List<SObjectField> longer = new List<SObjectField>(path);
        longer.add(extra);
        return longer;
    }

    private static Set<SObjectField> materialised(Set<SObjectField> keySet) {
        Set<SObjectField> real = new Set<SObjectField>();
        real.addAll(keySet);
        return real;
    }
}

/**
 * Re-expresses a generated graph in the shape `record.put(...)` rejects. Reads
 * the parents, children and alignment already on the bundle, drives
 * `XFTY_SObjectInjector` once per graph level (deepest first), and returns a new
 * carrier bundle whose `getList(field)` is the enriched instances. The original
 * bundle and its records are untouched.
 *
 * The entry points are `bundle.inject(field, config)` / `injectAll(field)`.
 */
@IsTest
public class XFTY_BundleEnricher {

    private final XFTY_DummySObjectBundle bundle;
    private final SObjectField field;
    private final XFTY_InjectConfig config;
    private final WorkingList working;

    private XFTY_BundleEnricher(XFTY_DummySObjectBundle bundle, SObjectField field, XFTY_InjectConfig config) {
        XFTY_QueryableShapeValidator.validate(config);
        this.bundle = bundle;
        this.field = field;
        this.config = config;
        this.working = locate(bundle, field);
    }

    public static XFTY_DummySObjectBundle enrich(
            XFTY_DummySObjectBundle bundle,
            SObjectField field,
            XFTY_InjectConfig config
    ) {
        return new XFTY_BundleEnricher(bundle, field, config).run();
    }

    /** `enrich` with `XFTY_InjectConfig.everything()`; throws when the graph has nothing to inject. */
    public static XFTY_DummySObjectBundle enrichEverything(XFTY_DummySObjectBundle bundle, SObjectField field) {
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
        WorkingList working = locate(bundle, field);
        Boolean hasParents = working.subBundle != null && !working.subBundle.relationshipFields().isEmpty();
        Boolean hasChildren = (working.subBundle != null && !working.subBundle.childRelationshipFields().isEmpty())
                || working.isGeneratedAncestor;
        return hasParents || hasChildren;
    }

    private XFTY_DummySObjectBundle run() {
        List<List<SObjectField>> parentPaths = XFTY_EnrichmentPaths.parentPaths(this.working.subBundle, this.config);
        XFTY_SObjectInjector injector = XFTY_SObjectInjector.inject(this.working.records);
        this.graftParents(injector, parentPaths);
        this.graftChildren(injector);
        for (SObjectField valued : this.config.onRecordValues.keySet()) {
            injector.value(valued, resolved(this.config.onRecordValues.get(valued)));
        }
        return this.carrier(injector.result());
    }

    // Working list -----------------------------------------------------------

    private class WorkingList {
        private final List<SObject> records;
        private final XFTY_DummySObjectBundle subBundle;
        private final SObjectType type;
        private final Boolean isGeneratedAncestor;

        private WorkingList(List<SObject> records, XFTY_DummySObjectBundle subBundle, Boolean isGeneratedAncestor) {
            this.records = records;
            this.subBundle = subBundle;
            this.type = (records == null || records.isEmpty()) ? null : records[0].getSObjectType();
            this.isGeneratedAncestor = isGeneratedAncestor;
        }
    }

    private static WorkingList locate(XFTY_DummySObjectBundle bundle, SObjectField field) {
        if (field == bundle.primaryTargetField) {
            return new WorkingList(bundle.primaryRecords(), bundle, false);
        }
        if (materialised(bundle.relationshipFields()).contains(field)) {
            return new WorkingList(bundle.getList(field), bundle.getBundle(field), true);
        }
        if (materialised(bundle.childRelationshipFields()).contains(field)) {
            return new WorkingList(bundle.getChildList(field), bundle.getChildBundle(field), false);
        }
        throw new XFTY_DummySObjectFtyProviderException(
                'inject: ' + field + ' is not this bundle\'s primary field, a generated ancestor field '
                        + bundle.relationshipFields() + ', or a child field ' + bundle.childRelationshipFields() + '.'
        );
    }

    // Parents - deepest first, one round-trip per level --------------------

    private void graftParents(XFTY_SObjectInjector injector, List<List<SObjectField>> parentPaths) {
        if (this.working.subBundle == null) {
            return;
        }
        Map<String, List<SObject>> enrichedByPath = new Map<String, List<SObject>>();
        for (List<SObjectField> path : XFTY_EnrichmentPaths.longestFirst(parentPaths)) {
            enrichedByPath.put(XFTY_EnrichmentPaths.keyOf(path), this.enrichedLevel(path, enrichedByPath));
        }
        for (List<SObjectField> path : parentPaths) {
            List<SObject> parents = enrichedByPath.get(XFTY_EnrichmentPaths.keyOf(path));
            if (path.size() == 1 && parents != null) {
                injector.relationship(relationshipName(path[0]), parents);
            }
        }
    }

    private List<SObject> enrichedLevel(List<SObjectField> path, Map<String, List<SObject>> enrichedByPath) {
        List<SObject> records = listAt(this.working.subBundle, path);
        if (records == null) {
            return null;
        }
        XFTY_SObjectInjector injector = XFTY_SObjectInjector.inject(records);
        XFTY_DummySObjectBundle here = bundleAt(this.working.subBundle, path);
        if (here != null) {
            for (SObjectField relationshipField : here.relationshipFields()) {
                List<SObject> deeper = enrichedByPath.get(XFTY_EnrichmentPaths.keyOf(append(path, relationshipField)));
                if (deeper != null) {
                    injector.relationship(relationshipName(relationshipField), deeper);
                }
            }
        }
        this.applyAncestorValues(injector, path);
        return injector.result();
    }

    private void applyAncestorValues(XFTY_SObjectInjector injector, List<SObjectField> path) {
        for (XFTY_InjectConfig.AncestorValue ancestorValue : this.config.ancestorValues) {
            if (XFTY_EnrichmentPaths.keyOf(ancestorValue.relationshipPrefix()) == XFTY_EnrichmentPaths.keyOf(path)) {
                injector.value(ancestorValue.targetField(), resolved(ancestorValue.value));
            }
        }
    }

    // Children - downward collections + the generated-ancestor inverse -----

    private void graftChildren(XFTY_SObjectInjector injector) {
        if (this.working.subBundle == null) {
            return;
        }
        for (SObjectField childField : XFTY_EnrichmentPaths.childFields(this.working.subBundle, this.config)) {
            injector.childRelationship(
                    XFTY_InjectionPathResolver.childRelationshipName(this.working.type, childField),
                    this.downwardChildrenPerRow(childField)
            );
        }
        if (this.working.isGeneratedAncestor && this.config.fromAllChildren) {
            injector.childRelationship(
                    XFTY_InjectionPathResolver.childRelationshipName(this.working.type, this.field),
                    this.inverseChildrenPerRow()
            );
        }
    }

    private List<List<SObject>> downwardChildrenPerRow(SObjectField childField) {
        List<List<SObject>> perRow = new List<List<SObject>>();
        for (Integer row = 0; row < this.working.records.size(); row++) {
            perRow.add(this.working.subBundle.childRecordsOf(row, childField));
        }
        return perRow;
    }

    private List<List<SObject>> inverseChildrenPerRow() {
        List<SObject> primaries = this.bundle.primaryRecords();
        List<SObject> ancestors = this.bundle.getList(this.field);
        List<List<SObject>> perRow = new List<List<SObject>>();
        for (Integer row = 0; row < ancestors.size(); row++) {
            List<SObject> children = new List<SObject>();
            for (Integer primaryRow : this.bundle.primaryRowsResolvingTo(this.field, row)) {
                children.add(primaries[primaryRow]);
            }
            perRow.add(children);
        }
        return perRow;
    }

    // Result carrier -----------------------------------------------------

    private XFTY_DummySObjectBundle carrier(List<SObject> enrichedRecords) {
        XFTY_DummySObjectBundle carrier = new XFTY_DummySObjectBundle();
        if (this.field == this.bundle.primaryTargetField) {
            carrier.putPrimaries(this.field, enrichedRecords);
        } else {
            carrier.put(this.field, enrichedRecords);
        }
        return carrier;
    }

    // Helpers ----------------------------------------------------------

    private static Object resolved(Object value) {
        return (value instanceof XFTY_ValueExpressionIntf)
                ? ((XFTY_ValueExpressionIntf) value).get()
                : value;
    }

    private static List<SObject> listAt(XFTY_DummySObjectBundle from, List<SObjectField> path) {
        XFTY_DummySObjectBundle bundle = from;
        for (Integer hop = 0; hop < path.size() - 1; hop++) {
            bundle = (bundle == null)
                    ? null
                    : bundle.getBundle(path[hop]);
        }
        return (bundle == null)
                ? null
                : bundle.getList(path[path.size() - 1]);
    }

    private static XFTY_DummySObjectBundle bundleAt(XFTY_DummySObjectBundle from, List<SObjectField> path) {
        XFTY_DummySObjectBundle bundle = from;
        for (SObjectField hop : path) {
            bundle = (bundle == null)
                    ? null
                    : bundle.getBundle(hop);
        }
        return bundle;
    }

    private static List<SObjectField> append(List<SObjectField> path, SObjectField extra) {
        List<SObjectField> longer = new List<SObjectField>(path);
        longer.add(extra);
        return longer;
    }

    private static String relationshipName(SObjectField relationshipField) {
        return XFTY_InjectionPathResolver.parentRelationshipName(relationshipField);
    }

    private static Set<SObjectField> materialised(Set<SObjectField> keySet) {
        Set<SObjectField> real = new Set<SObjectField>();
        real.addAll(keySet);
        return real;
    }
}

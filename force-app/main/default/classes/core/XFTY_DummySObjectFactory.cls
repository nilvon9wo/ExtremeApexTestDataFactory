/**
 * Turns one master template + the test's own partial templates into a wired
 * `XFTY_DummySObjectBundle`: ancestors first, then the primary records, then the
 * lookups between them, then the context-aware values, then persistence.
 *
 * One `Generation` runs the whole thing for a single Provider; ancestors recurse
 * back through `createBundle` with their own `Generation`.
 */
@IsTest
public class XFTY_DummySObjectFactory {

    public static XFTY_DummySObjectBundle createBundle(
            XFTY_GenerationContext context,
            XFTY_DummySObjectMasterTemplate masterTemplate,
            List<SObject> testTemplates
    ) {
        return new Generation(context, masterTemplate).build(testTemplates);
    }

    /** Clone `testTemplate` and fill every field whose master-template value is a plain default. */
    public static SObject cloneAndCompletePlainValues(
            XFTY_DummySObjectMasterTemplate template,
            SObject testTemplate
    ) {
        SObject record = clone(testTemplate);
        for (SObjectField field : template.orderedValueFields()) {
            fillPlainValue(template, record, field);
        }
        return record;
    }

    private static void fillPlainValue(
            XFTY_DummySObjectMasterTemplate template,
            SObject record,
            SObjectField field
    ) {
        XFTY_DummyDefaultValueIntf value = template.defaultBySObjectFieldMap.get(field);
        if (value != null && record.get(field) == null) {
            record.put(field, value.get());
        }
    }

    private class Generation {
        private final XFTY_GenerationContext context;
        private XFTY_DummySObjectMasterTemplate template;
        private Map<SObjectField, XFTY_DummyDefaultRelationshipIntf> relationships;

        private Generation(XFTY_GenerationContext context, XFTY_DummySObjectMasterTemplate template) {
            this.context = context;
            this.template = template;
        }

        private XFTY_DummySObjectBundle build(List<SObject> testTemplates) {
            this.template = new ForcedRelationships(this.context.forcedRelationshipPaths).appliedTo(this.template);
            this.relationships = mergedRelationships(this.template);
            XFTY_DummySObjectBundle bundle = this.buildAncestors(testTemplates.size());
            List<SObject> records = this.fillPlainValues(testTemplates);
            this.placePrimaries(bundle, records);
            this.wireLookups(bundle, records);
            this.fillContextAwareValues(bundle, records);
            this.persist(records);
            return bundle;
        }

        // Ancestors -----------------------------------------------------------

        private XFTY_DummySObjectBundle buildAncestors(Integer quantity) {
            XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
            if (this.inclusivityIs(XFTY_InsertInclusivityEnum.NONE)) {
                return bundle;
            }
            this.buildAncestors(bundle, this.template.requiredRelationshipBySObjectFieldMap, quantity);
            if (this.inclusivityIs(XFTY_InsertInclusivityEnum.ALL)) {
                this.buildAncestors(bundle, this.template.optionalRelationshipBySObjectFieldMap, quantity);
            }
            return bundle;
        }

        private void buildAncestors(
                XFTY_DummySObjectBundle bundle,
                Map<SObjectField, XFTY_DummyDefaultRelationshipIntf> relationships,
                Integer quantity
        ) {
            for (SObjectField field : relationships.keySet()) {
                this.buildAncestor(bundle, field, relationships.get(field), quantity);
            }
        }

        private void buildAncestor(
                XFTY_DummySObjectBundle bundle,
                SObjectField field,
                XFTY_DummyDefaultRelationshipIntf relationship,
                Integer quantity
        ) {
            if (relationship instanceof XFTY_SharedRelationshipIntf) {
                new SharedAncestor(this.context, (XFTY_SharedRelationshipIntf) relationship)
                        .wireInto(bundle, field, quantity);
                return;
            }
            XFTY_DummySobjectProviderIntf provider = this.providerFor(relationship);
            XFTY_DummySObjectBundle ancestors = provider.createBundle(
                    this.context.forRelated(field),
                    clones(relationship.getOverrideTemplate(), quantity)
            );
            bundle.put(field, ancestors);
            bundle.put(field, ancestors.getList(provider.getPrimaryTargetField()));
        }

        private XFTY_DummySobjectProviderIntf providerFor(XFTY_DummyDefaultRelationshipIntf relationship) {
            return this.context.providerLookup.get(relationship.resolveLookupKey(this.context.providerLookup));
        }

        // Primary records ---------------------------------------------------

        private List<SObject> fillPlainValues(List<SObject> testTemplates) {
            List<SObject> records = new List<SObject>();
            for (SObject testTemplate : testTemplates) {
                records.add(cloneAndCompletePlainValues(this.template, testTemplate));
            }
            return records;
        }

        private void placePrimaries(XFTY_DummySObjectBundle bundle, List<SObject> records) {
            bundle.primaryTargetField = this.template.primaryTargetField;
            bundle.put(this.template.primaryTargetField, records);
        }

        // Lookups between primary and ancestor -----------------------------

        private void wireLookups(XFTY_DummySObjectBundle bundle, List<SObject> records) {
            if (this.inclusivityIs(XFTY_InsertInclusivityEnum.NONE)) {
                return;
            }
            for (Integer row = 0; row < records.size(); row++) {
                this.wireLookups(bundle, records[row], row);
            }
        }

        private void wireLookups(XFTY_DummySObjectBundle bundle, SObject record, Integer row) {
            for (SObjectField field : this.relationships.keySet()) {
                this.wireLookup(bundle, record, row, field);
            }
        }

        private void wireLookup(XFTY_DummySObjectBundle bundle, SObject record, Integer row, SObjectField field) {
            SObject parent = parentAt(bundle, field, row);
            if (record.get(field) == null && parent != null) {
                record.put(field, valueFrom(parent, this.relationships.get(field).getRelatedField()));
            }
        }

        // Context-aware values --------------------------------------------

        private void fillContextAwareValues(XFTY_DummySObjectBundle bundle, List<SObject> records) {
            if (this.template.contextAwareBySObjectFieldMap.isEmpty()) {
                return;
            }
            for (Integer row = 0; row < records.size(); row++) {
                this.fillContextAwareValues(bundle, records[row], row);
            }
        }

        private void fillContextAwareValues(XFTY_DummySObjectBundle bundle, SObject record, Integer row) {
            XFTY_GenerationContext scoped = this.context.forRecord(record, bundle, row);
            for (SObjectField field : this.template.orderedValueFields()) {
                this.fillContextAwareValue(record, field, scoped);
            }
        }

        private void fillContextAwareValue(SObject record, SObjectField field, XFTY_GenerationContext scoped) {
            XFTY_ContextAwareValueIntf value = this.template.contextAwareBySObjectFieldMap.get(field);
            if (value != null && record.get(field) == null) {
                record.put(field, value.get(scoped));
            }
        }

        // Persistence -----------------------------------------------------

        private void persist(List<SObject> records) {
            switch on this.context.insertMode {
                when NOW {
                    insert records;
                }
                when MOCK {
                    XFTY_IdMocker.addIds(records);
                }
            }
        }

        private Boolean inclusivityIs(XFTY_InsertInclusivityEnum value) {
            return value.equals(this.context.inclusivity);
        }
    }

    /**
     * Promotes the head relationship of each `includeOptional(...)` path from
     * optional to required, on a copy of the master template.
     */
    private class ForcedRelationships {
        private final List<List<SObjectField>> paths;

        private ForcedRelationships(List<List<SObjectField>> paths) {
            this.paths = paths;
        }

        private XFTY_DummySObjectMasterTemplate appliedTo(XFTY_DummySObjectMasterTemplate template) {
            if (this.paths.isEmpty()) {
                return template;
            }
            XFTY_DummySObjectMasterTemplate forced = template.copy();
            for (List<SObjectField> path : this.paths) {
                this.force(forced, template, path[0]);
            }
            return forced;
        }

        private void force(
                XFTY_DummySObjectMasterTemplate forced,
                XFTY_DummySObjectMasterTemplate original,
                SObjectField head
        ) {
            XFTY_DummyDefaultRelationshipIntf optional = original.optionalRelationshipBySObjectFieldMap.get(head);
            if (optional != null) {
                forced.remove(head);
                forced.putRequired(head, optional);
                return;
            }
            this.failIfNotARelationship(original, head);
        }

        private void failIfNotARelationship(XFTY_DummySObjectMasterTemplate template, SObjectField head) {
            if (!template.requiredRelationshipBySObjectFieldMap.containsKey(head)) {
                throw new XFTY_DummySObjectFtyProviderException(
                        'includeOptional: ' + head + ' is not a relationship on the Provider for '
                                + template.primaryTargetField + '.'
                );
            }
        }
    }

    /**
     * One shared ancestor stands in for every child at its field - resolved once
     * per test, then repeated `quantity` times.
     */
    private class SharedAncestor {
        private final XFTY_GenerationContext context;
        private final XFTY_SharedRelationshipIntf shared;

        private SharedAncestor(XFTY_GenerationContext context, XFTY_SharedRelationshipIntf shared) {
            this.context = context;
            this.shared = shared;
        }

        private void wireInto(XFTY_DummySObjectBundle bundle, SObjectField field, Integer quantity) {
            this.failIfBatchedInsert();
            SObject record = this.shared.resolveSharedRecord(this.context);
            this.failIfSavedInconsistently();
            bundle.put(field, repeat(record, quantity));
            if (this.shared.getResolvedBundle() != null) {
                bundle.put(field, this.shared.getResolvedBundle());
            }
        }

        private void failIfBatchedInsert() {
            if (this.context.batchedInsertPending) {
                throw new XFTY_DummySObjectFtyProviderException(
                        'Shared ancestor "' + this.name() + '" is not supported together with .depthBatched() or the '
                                + 'DEFERRED insert mode - reference it from a Provider call using NOW / MOCK / NEVER.'
                );
            }
        }

        private void failIfSavedInconsistently() {
            if (XFTY_InsertModeEnum.NOW.equals(this.context.insertMode) && !this.shared.isResolvedRecordPersisted()) {
                throw new XFTY_DummySObjectFtyProviderException(
                        'Shared ancestor "' + this.name() + '" was resolved without being inserted, but this NOW run '
                                + 'would carry its Id onto inserted records. Use a consistent insert mode across the '
                                + 'test, or register a saved record with XFTY_SharedAncestor.put("' + this.name() + '", record).'
                );
            }
        }

        private String name() {
            return this.shared.getSharedName();
        }
    }

    // Shared helpers --------------------------------------------------------

    private static Map<SObjectField, XFTY_DummyDefaultRelationshipIntf> mergedRelationships(
            XFTY_DummySObjectMasterTemplate template
    ) {
        Map<SObjectField, XFTY_DummyDefaultRelationshipIntf> all =
                new Map<SObjectField, XFTY_DummyDefaultRelationshipIntf>(template.requiredRelationshipBySObjectFieldMap);
        all.putAll(template.optionalRelationshipBySObjectFieldMap);
        return all;
    }

    private static SObject parentAt(XFTY_DummySObjectBundle bundle, SObjectField field, Integer row) {
        List<SObject> parents = bundle.getList(field);
        return (parents != null && row < parents.size()) ? parents[row] : null;
    }

    private static Object valueFrom(SObject parent, SObjectField relatedField) {
        return (relatedField != null) ? parent.get(relatedField) : parent.Id;
    }

    private static SObject clone(SObject record) {
        return record.clone(true, true, true, true);
    }

    private static List<SObject> clones(SObject template, Integer quantity) {
        List<SObject> cloned = new List<SObject>();
        for (Integer i = 0; i < quantity; i++) {
            cloned.add(clone(template));
        }
        return cloned;
    }

    private static List<SObject> repeat(SObject record, Integer times) {
        List<SObject> records = new List<SObject>();
        for (Integer i = 0; i < times; i++) {
            records.add(record);
        }
        return records;
    }
}

@IsTest
public class XFTY_DummySObjectFactory {
    public static XFTY_DummySObjectBundle createBundle(
            XFTY_GenerationContext context,
            XFTY_DummySObjectMasterTemplate masterTemplateArg,
            List<SObject> testSpecificTemplateList
    ) {
        XFTY_DummySObjectMasterTemplate masterTemplate = applyForcedRelationshipPaths(context, masterTemplateArg);

        XFTY_DummySObjectBundle bundle
                = createRelatedRecords(context, masterTemplate, testSpecificTemplateList.size());

        List<SObject> sobjectList = new List<SObject>();
        for (SObject testSpecificTemplate : testSpecificTemplateList) {
            sobjectList.add(cloneAndCompletePlainValues(masterTemplate, testSpecificTemplate));
        }

        bundle.primaryTargetField = masterTemplate.primaryTargetField;
        bundle.put(masterTemplate.primaryTargetField, sobjectList);
        createRelationships(context, bundle, masterTemplate);
        // Second value pass: context-aware strategies, now that the plain values
        // are set, the ancestor records exist, and the lookups are wired.
        completeContextAwareValues(context, masterTemplate, bundle, sobjectList);

        List<SObject> insertSObjectList = new List<SObject>();
        switch on context.insertMode {
            when NOW {
                insertSObjectList.addAll(sobjectList);
            }
            when MOCK {
                XFTY_IdMocker.addIds(sobjectList);
            }
        }
        // Empty for the non-persisting modes (MOCK / NEVER / LATER); an empty
        // insert is a true no-op - 0 DML statements, 0 rows - so it needs no guard.
        insert insertSObjectList;
        return bundle;
    }

    /**
     * If the context carries `includeOptional(...)` paths, return a copy
     * of the master template with each path's head relationship forced (an
     * optional one promoted to required). Throws if a path head is not a
     * relationship on this template. Returns the original template untouched when
     * there is nothing to force.
     */
    private static XFTY_DummySObjectMasterTemplate applyForcedRelationshipPaths(
            XFTY_GenerationContext context,
            XFTY_DummySObjectMasterTemplate masterTemplate
    ) {
        if (context.forcedRelationshipPaths.isEmpty()) {
            return masterTemplate;
        }
        XFTY_DummySObjectMasterTemplate forced = null;
        for (List<SObjectField> path : context.forcedRelationshipPaths) {
            SObjectField head = path[0];
            XFTY_DummyDefaultRelationshipIntf optionalRelationship =
                    masterTemplate.optionalRelationshipBySObjectFieldMap.get(head);
            if (optionalRelationship != null) {
                if (forced == null) {
                    forced = masterTemplate.copy();
                }
                forced.remove(head);
                forced.putRequired(head, optionalRelationship);
            } else if (!masterTemplate.requiredRelationshipBySObjectFieldMap.containsKey(head)) {
                throw new XFTY_DummySObjectFtyProviderException(
                        'includeOptional: ' + head + ' is not a relationship on the Provider for '
                                + masterTemplate.primaryTargetField + '.'
                );
            }
        }
        return (forced == null) ? masterTemplate : forced;
    }

    // Create related records --------------------------------------------------------------------------------

    private static XFTY_DummySObjectBundle createRelatedRecords(
            XFTY_GenerationContext context,
            XFTY_DummySObjectMasterTemplate masterTemplate,
            Integer quantity
    ) {
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        if (XFTY_InsertInclusivityEnum.NONE.equals(context.inclusivity)) {
            return bundle;
        }

        createRelatedRecords(bundle, context, quantity, masterTemplate.requiredRelationshipBySObjectFieldMap);
        if (!XFTY_InsertInclusivityEnum.ALL.equals(context.inclusivity)) {
            return bundle;
        }

        return createRelatedRecords(bundle, context, quantity, masterTemplate.optionalRelationshipBySObjectFieldMap);
    }

    private static XFTY_DummySObjectBundle createRelatedRecords(
            XFTY_DummySObjectBundle bundle,
            XFTY_GenerationContext context,
            Integer quantity,
            Map<SObjectField, XFTY_DummyDefaultRelationshipIntf> relationshipsBySObjectField
    ) {
        for (SObjectField sObjectField : relationshipsBySObjectField.keySet()) {
            XFTY_DummyDefaultRelationshipIntf relationshipTemplate = relationshipsBySObjectField.get(sObjectField);
            createRelatedRecords(bundle, context, quantity, sObjectField, relationshipTemplate);
        }
        return bundle;
    }

    private static XFTY_DummySObjectBundle createRelatedRecords(
            XFTY_DummySObjectBundle bundle,
            XFTY_GenerationContext context,
            Integer quantity,
            SObjectField sObjectField,
            XFTY_DummyDefaultRelationshipIntf relationshipTemplate
    ) {
        if (relationshipTemplate instanceof XFTY_SharedRelationshipIntf) {
            return wireSharedAncestor(
                    bundle, context, quantity, sObjectField, (XFTY_SharedRelationshipIntf) relationshipTemplate
            );
        }

        SObject sObjectTemplate = relationshipTemplate.getOverrideTemplate();
        XFTY_DummySobjectProviderIntf factoryOutlet
                = context.providerLookup.get(relationshipTemplate.resolveLookupKey(context.providerLookup));

        XFTY_DummySObjectBundle innerBundle = factoryOutlet.createBundle(
                context.forRelated(sObjectField),
                createClonedTemplateList(quantity, sObjectTemplate)
        );

        return bundle.put(sObjectField, innerBundle)
                .put(sObjectField, innerBundle.getList(factoryOutlet.getPrimaryTargetField()));
    }

    /**
     * A shared ancestor resolves to one record - generated at most once per test
     * method. Every child at this field points at that same record, so the
     * bundle's list for the field is that record repeated `quantity` times.
     */
    private static XFTY_DummySObjectBundle wireSharedAncestor(
            XFTY_DummySObjectBundle bundle,
            XFTY_GenerationContext context,
            Integer quantity,
            SObjectField sObjectField,
            XFTY_SharedRelationshipIntf shared
    ) {
        if (context.batchedInsertPending) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'Shared ancestor "' + shared.getSharedName() + '" cannot be generated with batched-insert persistence '
                            + 'yet - shared ancestors are not supported together with .depthBatched() or the DEFERRED '
                            + 'insert mode. Drop it for this call, or reference the shared ancestor from a separate '
                            + 'Provider call that uses NOW / MOCK / NEVER.'
            );
        }
        SObject sharedRecord = shared.resolveSharedRecord(context);

        if (XFTY_InsertModeEnum.NOW.equals(context.insertMode) && !shared.isResolvedRecordPersisted()) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'Shared ancestor "' + shared.getSharedName() + '" was resolved without being inserted, but this '
                            + 'generation runs in NOW mode and would carry its Id onto inserted records. Reference the '
                            + 'shared ancestor with a consistent insert mode across the test, or register an inserted '
                            + 'record with XFTY_SharedAncestor.put("' + shared.getSharedName() + '", insertedRecord).'
            );
        }

        List<SObject> repeated = new List<SObject>();
        for (Integer i = 0; i < quantity; i++) {
            repeated.add(sharedRecord);
        }
        bundle.put(sObjectField, repeated);
        if (shared.getResolvedBundle() != null) {
            bundle.put(sObjectField, shared.getResolvedBundle());
        }
        return bundle;
    }


    private static List<SObject> createClonedTemplateList(Integer quantity, SObject sObjectTemplate) {
        List<SObject> clonedList = new List<SObject>();
        for (Integer i = 1; i <= quantity; i++) {
            clonedList.add(perfectClone(sObjectTemplate));
        }
        return clonedList;
    }

    // Setting Values --------------------------------------------------------------------------------

    /**
     * Pass 1: clone the test's template and fill every field whose strategy is a
     * plain {@link XFTY_DummyDefaultValueIntf}. Context-aware strategies are
     * skipped here - they run in {@link #completeContextAwareValues} once there is
     * something to be aware of.
     */
    public static SObject cloneAndCompletePlainValues(
            XFTY_DummySObjectMasterTemplate masterTemplate,
            SObject testSpecificTemplate
    ) {
        SObject filledTemplate = perfectClone(testSpecificTemplate);
        for (SObjectField sObjectField : masterTemplate.orderedValueFields()) {
            XFTY_DummyDefaultValueIntf strategy = masterTemplate.defaultBySObjectFieldMap.get(sObjectField);
            if (strategy != null && filledTemplate.get(sObjectField) == null) {
                filledTemplate.put(sObjectField, strategy.get());
            }
        }
        return filledTemplate;
    }

    /**
     * Pass 2: evaluate the context-aware strategies. Each is handed a context
     * scoped to its record - `recordBeingBuilt` with the plain values set and the
     * lookups wired, plus the `bundleSoFar` for reading generated parents.
     * Template-insertion order; a context-aware value that reads another only sees
     * it if that one was `put(...)` first.
     */
    private static void completeContextAwareValues(
            XFTY_GenerationContext context,
            XFTY_DummySObjectMasterTemplate masterTemplate,
            XFTY_DummySObjectBundle bundle,
            List<SObject> sobjectList
    ) {
        if (masterTemplate.contextAwareBySObjectFieldMap.isEmpty()) {
            return;
        }
        for (Integer i = 0; i < sobjectList.size(); i++) {
            SObject record = sobjectList[i];
            XFTY_GenerationContext recordContext = context.forRecord(record, bundle, i);
            for (SObjectField sObjectField : masterTemplate.orderedValueFields()) {
                XFTY_ContextAwareValueIntf strategy = masterTemplate.contextAwareBySObjectFieldMap.get(sObjectField);
                if (strategy != null && record.get(sObjectField) == null) {
                    record.put(sObjectField, strategy.get(recordContext));
                }
            }
        }
    }

    private static XFTY_DummySObjectBundle createRelationships(
            XFTY_GenerationContext context,
            XFTY_DummySObjectBundle bundle,
            XFTY_DummySObjectMasterTemplate masterTemplate
    ) {
        if (XFTY_InsertInclusivityEnum.NONE.equals(context.inclusivity)) {
            return bundle;
        }

        List<SObject> sObjectList = bundle.getList(masterTemplate.primaryTargetField);
        for (Integer i = 0; i < sObjectList.size(); i++) {
            createRelationships(bundle, masterTemplate, sObjectList[i], i);
        }
        return bundle;
    }

    private static SObject createRelationships(
            XFTY_DummySObjectBundle bundle,
            XFTY_DummySObjectMasterTemplate masterTemplate,
            SObject sObj,
            Integer i
    ) {
        createRelationships(bundle, masterTemplate.requiredRelationshipBySObjectFieldMap, sObj, i);
        createRelationships(bundle, masterTemplate.optionalRelationshipBySObjectFieldMap, sObj, i);
        return sObj;
    }

    private static SObject createRelationships(
            XFTY_DummySObjectBundle bundle,
            Map<SObjectField, XFTY_DummyDefaultRelationshipIntf> relationshipBySObjectFieldMap,
            SObject sObj,
            Integer i
    ) {
        for (SObjectField sObjectField : relationshipBySObjectFieldMap.keySet()) {
            if (
                    sObj.get(sObjectField) == null
                            && bundle.getList(sObjectField) != null
                            && bundle.getList(sObjectField)[i] != null
            ) {
                SObjectField fromField = relationshipBySObjectFieldMap.get(sObjectField).getRelatedField();
                sObj.put(sObjectField, (fromField != null)
                        ? bundle.getList(sObjectField)[i].get(fromField)
                        : bundle.getList(sObjectField)[i].Id
                );
            }
        }
        return sObj;
    }

    // Helpers --------------------------------------------------------------------------------

    private static SObject perfectClone(SObject sObj) {
        return sObj.clone(true, true, true, true);
    }
}

@IsTest
public class XFTY_DummySObjectFactory {
    public static XFTY_DummySObjectBundle createBundle(
            XFTY_DummySObjectMasterTemplate masterTemplate,
            List<SObject> testSpecificTemplateList,
            XFTY_InsertModeEnum insertMode,
            XFTY_InsertInclusivityEnum inclusivity
    ) {
        Integer quantity = testSpecificTemplateList.size();
        XFTY_DummySObjectBundle bundle
                = createRelatedRecords(masterTemplate, testSpecificTemplateList.size(), insertMode, inclusivity);

        List<SObject> sobjectList = new List<SObject>();
        for (SObject testSpecificTemplate : testSpecificTemplateList) {
            sobjectList.add(cloneAndCompleteNonRelationshipValues(masterTemplate, testSpecificTemplate));
        }

        bundle.put(masterTemplate.primaryTargetField, sobjectList);
        createRelationships(bundle, masterTemplate, inclusivity);

        switch on insertMode {
            when NOW {
                insert sobjectList;
            }
            when RELATED_ONLY {
                insert sobjectList;
            }
            when MOCK {
                XFTY_InsertMocker.addIds(sobjectList);
            }
        }

        return bundle;
    }

    // Create related records --------------------------------------------------------------------------------

    private static XFTY_DummySObjectBundle createRelatedRecords(
            XFTY_DummySObjectMasterTemplate masterTemplate,
            Integer quantity,
            XFTY_InsertModeEnum insertMode,
            XFTY_InsertInclusivityEnum inclusivity
    ) {
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        if (XFTY_InsertInclusivityEnum.NONE.equals(inclusivity)) {
            return bundle;
        }

        createRelatedRecords(bundle, quantity, masterTemplate.requiredRelationshipBySObjectFieldMap, insertMode, inclusivity);
        if (!XFTY_InsertInclusivityEnum.ALL.equals(inclusivity)) {
            return bundle;
        }

        return createRelatedRecords(bundle, quantity, masterTemplate.optionalRelationshipBySObjectFieldMap, insertMode, inclusivity);
    }

    private static XFTY_DummySObjectBundle createRelatedRecords(
            XFTY_DummySObjectBundle bundle,
            Integer quantity,
            Map<SObjectField, XFTY_DummyDefaultRelationshipIntf> relationshipsBySObjectField,
            XFTY_InsertModeEnum insertMode,
            XFTY_InsertInclusivityEnum inclusivity
    ) {
        for (SObjectField sObjectField : relationshipsBySObjectField.keySet()) {
            XFTY_DummyDefaultRelationshipIntf relationshipTemplate = relationshipsBySObjectField.get(sObjectField);
            SObject sObjectTemplate = relationshipTemplate.get();
            createRelatedRecords(bundle, quantity, sObjectField, sObjectTemplate, insertMode, inclusivity);
        }
        return bundle;
    }

    private static XFTY_DummySObjectBundle createRelatedRecords(
            XFTY_DummySObjectBundle bundle,
            Integer quantity,
            SObjectField sObjectField,
            SObject sObjectTemplate,
            XFTY_InsertModeEnum insertMode,
            XFTY_InsertInclusivityEnum inclusivity
    ) {
        XFTY_DummySObjectFactoryOutletIntf factoryOutlet = XFTY_DummySObjectFactoryOutletLookup.get(sObjectTemplate.getSObjectType());

        XFTY_DummySObjectBundle innerBundle = factoryOutlet.createBundle(
                createClonedTemplateList(quantity, sObjectTemplate),
                (XFTY_InsertModeEnum.RELATED_ONLY.equals(insertMode)) ? XFTY_InsertModeEnum.NOW : insertMode,
                (XFTY_InsertInclusivityEnum.PREVENT_CASCADE.equals(inclusivity)) ? XFTY_InsertInclusivityEnum.NONE : inclusivity
        );

        return bundle.put(sObjectField, innerBundle)
                .put(sObjectField, innerBundle.getList(factoryOutlet.getPrimaryTargetField()));
    }


    private static List<SObject> createClonedTemplateList(Integer quantity, SObject sObjectTemplate) {
        List<SObject> clonedList = new List<SObject>();
        for (Integer i = 1; i <= quantity; i++) {
            clonedList.add(perfectClone(sObjectTemplate));
        }
        return clonedList;
    }

    // Setting Values --------------------------------------------------------------------------------

    public static SObject cloneAndCompleteNonRelationshipValues(XFTY_DummySObjectMasterTemplate masterTemplate, SObject testSpecificTemplate) {
        SObject filledTemplate = perfectClone(testSpecificTemplate);
        for (SObjectField sObjectField : masterTemplate.defaultBySObjectFieldMap.keySet()) {
            if (filledTemplate.get(sObjectField) == null) {
                filledTemplate.put(sObjectField, masterTemplate.defaultBySObjectFieldMap.get(sObjectField).get());
            }
        }
        return filledTemplate;
    }

    private static XFTY_DummySObjectBundle createRelationships(
            XFTY_DummySObjectBundle bundle,
            XFTY_DummySObjectMasterTemplate masterTemplate,
            XFTY_InsertInclusivityEnum inclusivity
    ) {
        if (XFTY_InsertInclusivityEnum.NONE.equals(inclusivity)) {
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
        createRelationships(bundle, masterTemplate.requiredRelationshipBySObjectFieldMap.keySet(), sObj, i);
        createRelationships(bundle, masterTemplate.optionalRelationshipBySObjectFieldMap.keySet(), sObj, i);
        return sObj;
    }

    private static SObject createRelationships(
            XFTY_DummySObjectBundle bundle,
            Set<SObjectField> sObjectFieldSet,
            SObject sObj,
            Integer i
    ) {
        for (SObjectField sObjectField : sObjectFieldSet) {
            if (
                    sObj.get(sObjectField) == null
                            && bundle.getList(sObjectField) != null
                            && bundle.getList(sObjectField)[i] != null
                    ) {
                sObj.put(sObjectField, bundle.getList(sObjectField)[i].Id);
            }
        }
        return sObj;
    }

    // Helpers --------------------------------------------------------------------------------

    private static SObject perfectClone(SObject sObj) {
        return sObj.clone(true, true, true, true);
    }

}